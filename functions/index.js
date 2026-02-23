const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {initializeApp} = require('firebase-admin/app');
const {getAuth} = require('firebase-admin/auth');
const {getFirestore, FieldValue} = require('firebase-admin/firestore');
const {getStorage} = require('firebase-admin/storage');

initializeApp();
const db = getFirestore();

function assertAuth(request) {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Authentication required');
  return uid;
}

function cleanString(value) {
  return String(value || '').trim();
}

function normalizeInviteCode(code) {
  return cleanString(code).toUpperCase();
}

function childKey(child) {
  const name = cleanString(child?.name).toLowerCase();
  const age = Number(child?.age || 0);
  const classId = cleanString(child?.classId).toUpperCase();
  return `${name}|${age}|${classId}`;
}

function mergeChildren(existingChildren, nextChild) {
  const safeExisting = Array.isArray(existingChildren) ? existingChildren : [];
  const merged = [];
  const seen = new Set();

  for (const raw of [...safeExisting, nextChild]) {
    const name = cleanString(raw?.name);
    const age = Number(raw?.age || 0);
    const classId = cleanString(raw?.classId);
    if (!name || !Number.isFinite(age) || age <= 0) continue;

    const normalized = {
      name,
      age,
      classId,
    };

    const key = childKey(normalized);
    if (seen.has(key)) continue;
    seen.add(key);
    merged.push(normalized);
  }

  return merged;
}

function mergeClassIds(existingClassIds, extraClassId) {
  const values = Array.isArray(existingClassIds) ? existingClassIds.map((v) => cleanString(v)).filter(Boolean) : [];
  const candidate = cleanString(extraClassId);
  if (candidate) values.push(candidate);
  return [...new Set(values)];
}

function pickDisplayName(request) {
  return cleanString(request.auth?.token?.name) || cleanString(request.auth?.token?.email) || 'Familia';
}

exports.redeemInviteCode = onCall(async (request) => {
  const uid = assertAuth(request);
  const code = normalizeInviteCode(request.data?.code);
  const childName = cleanString(request.data?.childName);
  const childAge = Number(request.data?.childAge || 0);
  const requestedClassId = cleanString(request.data?.classId);

  if (!code || !childName || !Number.isFinite(childAge) || childAge <= 0) {
    throw new HttpsError('invalid-argument', 'code, childName and childAge are required');
  }

  const inviteQuery = await db.collectionGroup('inviteCodes').where('__name__', '==', code).limit(1).get();
  if (inviteQuery.empty) throw new HttpsError('not-found', 'Invite code not found');

  const inviteRef = inviteQuery.docs[0].ref;
  const schoolRef = inviteRef.parent.parent;
  if (!schoolRef) throw new HttpsError('internal', 'Invalid invite path');

  const schoolId = schoolRef.id;
  let alreadyMember = false;
  let assignedClassId = '';

  await db.runTransaction(async (tx) => {
    const inviteSnap = await tx.get(inviteRef);
    const invite = inviteSnap.data();
    if (!invite) throw new HttpsError('not-found', 'Invite code not found');

    const userMembershipsSnap = await tx.get(
      db.collectionGroup('users').where('__name__', '==', uid).limit(10),
    );

    const memberships = userMembershipsSnap.docs.map((doc) => doc.ref.parent.parent?.id).filter(Boolean);
    const otherSchoolMembership = memberships.find((memberSchoolId) => memberSchoolId !== schoolId);
    if (otherSchoolMembership) {
      throw new HttpsError(
        'failed-precondition',
        'This account is already linked to another school. Use a different account or contact support.',
      );
    }

    const userRef = schoolRef.collection('users').doc(uid);
    const userSnap = await tx.get(userRef);
    const userData = userSnap.data() || {};
    alreadyMember = userSnap.exists;

    const classId = requestedClassId || cleanString(invite.classId);
    assignedClassId = classId;

    if (!alreadyMember) {
      const uses = Number(invite.uses || 0);
      const maxUses = Number(invite.maxUses || 0);
      const expiresAt = invite.expiresAt?.toDate?.();

      if (maxUses > 0 && uses >= maxUses) {
        throw new HttpsError('failed-precondition', 'Invite exhausted');
      }
      if (expiresAt && expiresAt.getTime() < Date.now()) {
        throw new HttpsError('failed-precondition', 'Invite expired');
      }

      tx.update(inviteRef, {uses: FieldValue.increment(1)});
    }

    const children = mergeChildren(userData.children, {
      name: childName,
      age: childAge,
      classId,
    });
    const classIds = mergeClassIds(userData.classIds, classId);

    const payload = {
      displayName: pickDisplayName(request),
      role: cleanString(userData.role) || 'parent',
      children,
      classIds,
      lastActiveAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    };

    if (!userSnap.exists) {
      payload.createdAt = FieldValue.serverTimestamp();
    }

    tx.set(userRef, payload, {merge: true});
  });

  return {
    ok: true,
    schoolId,
    classId: assignedClassId,
    alreadyMember,
  };
});

exports.getOrCreateChat = onCall(async (request) => {
  const uid = assertAuth(request);
  const schoolId = cleanString(request.data?.schoolId);
  const peerUid = cleanString(request.data?.peerUid);

  if (!schoolId || !peerUid) {
    throw new HttpsError('invalid-argument', 'schoolId and peerUid are required');
  }
  if (peerUid === uid) {
    throw new HttpsError('invalid-argument', 'You cannot chat with yourself');
  }

  const [a, b] = [uid, peerUid].sort();
  const chatId = `${a}_${b}`;
  const schoolRef = db.collection('schools').doc(schoolId);
  const meRef = schoolRef.collection('users').doc(uid);
  const peerRef = schoolRef.collection('users').doc(peerUid);
  const chatRef = schoolRef.collection('chats').doc(chatId);

  await db.runTransaction(async (tx) => {
    const [meSnap, peerSnap, chatSnap] = await Promise.all([
      tx.get(meRef),
      tx.get(peerRef),
      tx.get(chatRef),
    ]);

    if (!meSnap.exists) {
      throw new HttpsError('permission-denied', 'You are not a member of this school');
    }
    if (!peerSnap.exists) {
      throw new HttpsError('not-found', 'Peer user not found in this school');
    }

    if (!chatSnap.exists) {
      tx.set(chatRef, {
        participants: [a, b],
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        lastMessage: '',
        lastMessageAt: null,
      });
    }
  });

  return {ok: true, chatId};
});

exports.deleteMyAccount = onCall(async (request) => {
  const uid = assertAuth(request);
  const schoolId = String(request.data?.schoolId || '').trim();
  if (!schoolId) throw new HttpsError('invalid-argument', 'schoolId is required');

  const posts = await db.collection(`schools/${schoolId}/posts`).where('authorUid', '==', uid).get();
  const events = await db.collection(`schools/${schoolId}/events`).where('organizerUid', '==', uid).get();
  const attendees = await db.collectionGroup('attendees').where('__name__', '==', uid).get();

  const batch = db.batch();
  posts.docs.forEach((doc) => batch.update(doc.ref, {status: 'deleted'}));
  events.docs.forEach((doc) => batch.update(doc.ref, {status: 'deleted'}));
  attendees.docs
    .filter((doc) => doc.ref.path.startsWith(`schools/${schoolId}/events/`))
    .forEach((doc) => batch.delete(doc.ref));
  batch.delete(db.doc(`schools/${schoolId}/users/${uid}`));
  await batch.commit();

  await getStorage().bucket().file(`schools/${schoolId}/users/${uid}/profile.jpg`).delete({ignoreNotFound: true});
  await getAuth().deleteUser(uid);

  return {ok: true};
});

exports.moderationHideTarget = onCall(async (request) => {
  const uid = assertAuth(request);
  const targetPath = String(request.data?.targetPath || '').trim();
  if (!targetPath.startsWith('schools/')) throw new HttpsError('invalid-argument', 'Invalid targetPath');

  const segments = targetPath.split('/');
  const schoolId = segments[1];
  const userSnap = await db.doc(`schools/${schoolId}/users/${uid}`).get();
  const role = userSnap.data()?.role;
  if (!(role === 'moderator' || role === 'admin')) throw new HttpsError('permission-denied', 'Insufficient role');

  await db.doc(targetPath).set({status: 'hidden', updatedAt: FieldValue.serverTimestamp()}, {merge: true});
  return {ok: true};
});
