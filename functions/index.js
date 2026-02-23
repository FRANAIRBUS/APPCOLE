const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {initializeApp} = require('firebase-admin/app');
const {getAuth} = require('firebase-admin/auth');
const {FieldPath, FieldValue, getFirestore} = require('firebase-admin/firestore');
const {getStorage} = require('firebase-admin/storage');

initializeApp();
const db = getFirestore();

function assertAuth(request) {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Authentication required');
  return uid;
}

function normalizeChildren(rawChildren) {
  if (!Array.isArray(rawChildren)) return [];
  return rawChildren
    .map((item) => ({
      name: String(item?.name || '').trim(),
      age: Number(item?.age || 0),
      classId: String(item?.classId || '').trim(),
    }))
    .filter((c) => c.name && Number.isFinite(c.age) && c.age > 0);
}

function mergeChildren(existingChildren, newChild) {
  const normalized = normalizeChildren(existingChildren);
  const key = `${newChild.name.toLowerCase()}|${newChild.age}|${newChild.classId}`;
  const hasChild = normalized.some(
    (c) => `${c.name.toLowerCase()}|${c.age}|${c.classId}` === key,
  );
  if (!hasChild) normalized.push(newChild);
  return normalized;
}

exports.redeemInviteCode = onCall(async (request) => {
  const uid = assertAuth(request);
  const code = String(request.data?.code || '').trim().toUpperCase();
  const childName = String(request.data?.childName || '').trim();
  const childAge = Number(request.data?.childAge || 0);
  const requestedClassId = String(request.data?.classId || '').trim();

  if (!code || !childName || !Number.isFinite(childAge) || childAge <= 0) {
    throw new HttpsError('invalid-argument', 'code, childName and childAge are required');
  }

  const inviteQuery = await db
    .collectionGroup('inviteCodes')
    .where(FieldPath.documentId(), '==', code)
    .limit(1)
    .get();

  if (inviteQuery.empty) throw new HttpsError('not-found', 'Invite code not found');

  const inviteRef = inviteQuery.docs[0].ref;
  const schoolRef = inviteRef.parent.parent;
  if (!schoolRef) throw new HttpsError('internal', 'Invalid invite path');
  const schoolId = schoolRef.id;

  // Bloqueo multi-colegio (una cuenta = un colegio). Si ya existe en otro colegio, rechazamos.
  const membershipsSnap = await db
    .collectionGroup('users')
    .where(FieldPath.documentId(), '==', uid)
    .limit(10)
    .get();

  const foreignMembership = membershipsSnap.docs.find((doc) => doc.ref.parent.parent?.id !== schoolId);
  if (foreignMembership) {
    throw new HttpsError(
      'failed-precondition',
      'Esta cuenta ya pertenece a otro colegio. Usa otra cuenta o soporte para migración.',
    );
  }

  const userRef = schoolRef.collection('users').doc(uid);

  const result = await db.runTransaction(async (tx) => {
    const [inviteSnap, userSnap] = await Promise.all([tx.get(inviteRef), tx.get(userRef)]);

    const invite = inviteSnap.data();
    if (!invite) throw new HttpsError('not-found', 'Invite code not found');

    const classId = requestedClassId || String(invite.classId || '').trim();
    const newChild = {name: childName, age: childAge, classId};

    const userExists = userSnap.exists;
    const existingUser = userSnap.data() || {};

    if (!userExists) {
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

    const existingClassIds = Array.isArray(existingUser.classIds)
      ? existingUser.classIds.map((v) => String(v)).filter(Boolean)
      : [];
    const mergedClassIds = classId
      ? Array.from(new Set([...existingClassIds, classId]))
      : existingClassIds;
    const mergedChildren = mergeChildren(existingUser.children, newChild);

    tx.set(
      userRef,
      {
        displayName:
          String(existingUser.displayName || '').trim() ||
          request.auth.token.name ||
          request.auth.token.email ||
          'Familia',
        role: String(existingUser.role || 'parent'),
        children: mergedChildren,
        classIds: mergedClassIds,
        photoUrl: existingUser.photoUrl || null,
        createdAt: existingUser.createdAt || FieldValue.serverTimestamp(),
        lastActiveAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );

    return {ok: true, schoolId, alreadyMember: userExists};
  });

  return result;
});

exports.getOrCreateChat = onCall(async (request) => {
  const uid = assertAuth(request);
  const schoolId = String(request.data?.schoolId || '').trim();
  const peerUid = String(request.data?.peerUid || '').trim();

  if (!schoolId || !peerUid) {
    throw new HttpsError('invalid-argument', 'schoolId and peerUid are required');
  }
  if (peerUid === uid) {
    throw new HttpsError('invalid-argument', 'Cannot create a chat with yourself');
  }

  const meRef = db.doc(`schools/${schoolId}/users/${uid}`);
  const peerRef = db.doc(`schools/${schoolId}/users/${peerUid}`);
  const [meSnap, peerSnap] = await Promise.all([meRef.get(), peerRef.get()]);

  if (!meSnap.exists || !peerSnap.exists) {
    throw new HttpsError('permission-denied', 'Both users must belong to the same school');
  }

  const participants = [uid, peerUid].sort();
  const chatId = `${participants[0]}_${participants[1]}`;
  const chatRef = db.doc(`schools/${schoolId}/chats/${chatId}`);

  await db.runTransaction(async (tx) => {
    const chatSnap = await tx.get(chatRef);
    if (!chatSnap.exists) {
      tx.set(chatRef, {
        participants,
        createdAt: FieldValue.serverTimestamp(),
        lastMessage: '',
        lastMessageAt: FieldValue.serverTimestamp(),
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
