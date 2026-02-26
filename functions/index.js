const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {initializeApp} = require('firebase-admin/app');
const {getAuth} = require('firebase-admin/auth');
const {FieldValue, getFirestore} = require('firebase-admin/firestore');
const {getMessaging} = require('firebase-admin/messaging');
const {getStorage} = require('firebase-admin/storage');

initializeApp();
const db = getFirestore();

function assertAuth(request) {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Authentication required');
  return uid;
}

function assertRootClaim(request) {
  const role = String(request.auth?.token?.role || '').trim();
  if (role !== 'root') {
    throw new HttpsError('permission-denied', 'Root role required');
  }
}

function normalizeRole(role) {
  const r = String(role || '').trim();
  return r === 'admin' || r === 'moderator' ? r : 'parent';
}

function normalizeCustomRole(role) {
  const r = String(role || '').trim();
  return ['root', 'admin', 'moderator', 'parent'].includes(r) ? r : null;
}

async function resolveSchoolIdForUid(uid) {
  const schoolsSnap = await db.collection('schools').get();
  if (schoolsSnap.empty) return null;

  const checks = await Promise.all(
    schoolsSnap.docs.map(async (schoolDoc) => {
      const userSnap = await schoolDoc.ref.collection('users').doc(uid).get();
      if (!userSnap.exists) return null;

      const ts = userSnap.data()?.lastActiveAt;
      const ms = ts?.toMillis?.() ?? ts?.toDate?.()?.getTime?.() ?? 0;
      return {schoolId: schoolDoc.id, lastActiveMs: ms};
    }),
  );

  const memberships = checks.filter((v) => v !== null);
  if (!memberships.length) return null;

  memberships.sort((a, b) => b.lastActiveMs - a.lastActiveMs);
  return memberships[0].schoolId;
}

function assertSameSchool(providedSchoolId, resolvedSchoolId) {
  if (providedSchoolId && resolvedSchoolId && providedSchoolId !== resolvedSchoolId) {
    throw new HttpsError('failed-precondition', 'School mismatch');
  }
}

function chunk(array, size) {
  const out = [];
  for (let i = 0; i < array.length; i += size) out.push(array.slice(i, i + size));
  return out;
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


exports.onboardSelectSchool = onCall(async (request) => {
  const uid = assertAuth(request);
  const providedSchoolId = String(request.data?.schoolId || '').trim();
  if (!providedSchoolId) {
    throw new HttpsError('invalid-argument', 'schoolId is required');
  }

  const catalogRef = db.doc(`colegios/${providedSchoolId}`);
  const catalogSnap = await catalogRef.get();
  if (!catalogSnap.exists) {
    throw new HttpsError('not-found', 'Colegio no encontrado');
  }

  const catalog = catalogSnap.data() || {};
  if (catalog.activo !== true) {
    throw new HttpsError('failed-precondition', 'Colegio inactivo');
  }

  const schoolName = String(catalog.nombre || '').trim();
  const schoolLocalidad = String(catalog.localidad || '').trim();
  const schoolProvincia = String(catalog.provincia || '').trim();
  if (!schoolName || !schoolLocalidad || !schoolProvincia) {
    throw new HttpsError('failed-precondition', 'Catálogo del colegio incompleto');
  }

  const requestedDisplayName = String(request.data?.displayName || '').trim();
  const tokenDisplayName = String(request.auth?.token?.name || '').trim();
  const tokenEmail = String(request.auth?.token?.email || '').trim();
  const displayName =
    requestedDisplayName || tokenDisplayName || tokenEmail || 'Familia';

  const requestedPhotoUrl = String(request.data?.photoUrl || '').trim();
  const tokenPhotoUrl = String(request.auth?.token?.picture || '').trim();
  const photoUrl = (requestedPhotoUrl || tokenPhotoUrl || '').trim() || null;

  const globalRef = db.doc(`users/${uid}`);
  const membershipRef = db.doc(`schools/${providedSchoolId}/users/${uid}`);

  await db.runTransaction(async (tx) => {
    const [globalSnap, membershipSnap] = await Promise.all([
      tx.get(globalRef),
      tx.get(membershipRef),
    ]);

    const existing = globalSnap.data() || {};
    const existingSchoolId = String(existing.schoolId || '').trim();
    if (existingSchoolId && existingSchoolId !== providedSchoolId) {
      throw new HttpsError('failed-precondition', 'Esta cuenta ya pertenece a otro colegio');
    }

    const now = FieldValue.serverTimestamp();

    tx.set(
      globalRef,
      {
        schoolId: providedSchoolId,
        schoolName,
        schoolLocalidad,
        schoolProvincia,
        displayName,
        photoUrl,
        lastActiveAt: now,
        updatedAt: now,
        ...(globalSnap.exists ? {} : {createdAt: now}),
      },
      {merge: true},
    );

    const membership = membershipSnap.data() || {};
    const children = Array.isArray(membership.children) ? membership.children : [];
    const classIds = Array.isArray(membership.classIds) ? membership.classIds : [];

    tx.set(
      membershipRef,
      {
        displayName,
        photoUrl,
        role: 'parent',
        children,
        classIds,
        lastActiveAt: now,
        updatedAt: now,
        ...(membershipSnap.exists ? {} : {createdAt: now}),
      },
      {merge: true},
    );
  });

  return {ok: true, schoolId: providedSchoolId};
});

exports.redeemInviteCode = onCall(async (request) => {
  const uid = assertAuth(request);
  const code = String(request.data?.code || '').trim().toUpperCase();
  const childName = String(request.data?.childName || '').trim();
  const childAge = Number(request.data?.childAge || 0);
  const requestedClassId = String(request.data?.classId || '').trim();
  const providedSchoolId = String(request.data?.schoolId || '').trim();

  if (!code || !childName || !Number.isFinite(childAge) || childAge <= 0) {
    throw new HttpsError('invalid-argument', 'code, childName and childAge are required');
  }

  let inviteRef = null;

  if (providedSchoolId) {
    const directRef = db.doc(`schools/${providedSchoolId}/inviteCodes/${code}`);
    const directSnap = await directRef.get();
    if (directSnap.exists) {
      inviteRef = directRef;
    }
  }

  const schoolsSnap = await db.collection('schools').get();
  if (!inviteRef) {
    for (const schoolDoc of schoolsSnap.docs) {
      const candidateRef = schoolDoc.ref.collection('inviteCodes').doc(code);
      const candidateSnap = await candidateRef.get();
      if (candidateSnap.exists) {
        inviteRef = candidateRef;
        break;
      }
    }
  }

  if (!inviteRef) throw new HttpsError('not-found', 'Invite code not found');

  const schoolRef = inviteRef.parent.parent;
  if (!schoolRef) throw new HttpsError('internal', 'Invalid invite path');
  const schoolId = schoolRef.id;

  // Bloqueo multi-colegio (una cuenta = un colegio). Si ya existe en otro colegio, rechazamos.
  const memberships = await Promise.all(
    schoolsSnap.docs.map(async (schoolDoc) => {
      const userSnap = await schoolDoc.ref.collection('users').doc(uid).get();
      return userSnap.exists ? schoolDoc.id : null;
    }),
  );

  const foreignMembership = memberships.find((m) => m && m !== schoolId);
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
        role: normalizeRole(existingUser.role),
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

exports.setUserRole = onCall(async (request) => {
  const actorUid = assertAuth(request);
  assertRootClaim(request);

  const targetUid = String(request.data?.uid || '').trim();
  const requestedRole = normalizeCustomRole(request.data?.role);

  if (!targetUid) throw new HttpsError('invalid-argument', 'uid is required');
  if (!requestedRole) {
    throw new HttpsError('invalid-argument', 'role must be one of: root, admin, moderator, parent');
  }

  const userRecord = await getAuth().getUser(targetUid);
  const nextClaims = {
    ...(userRecord.customClaims || {}),
    role: requestedRole,
  };

  await getAuth().setCustomUserClaims(targetUid, nextClaims);
  await db.collection('adminAudit').add({
    action: 'setUserRole',
    actorUid,
    targetUid,
    role: requestedRole,
    createdAt: FieldValue.serverTimestamp(),
  });

  return {ok: true, uid: targetUid, role: requestedRole};
});

exports.getOrCreateChat = onCall(async (request) => {
  const uid = assertAuth(request);
  const peerUid = String(request.data?.peerUid || '').trim();
  const providedSchoolId = String(request.data?.schoolId || '').trim();

  if (!peerUid) throw new HttpsError('invalid-argument', 'peerUid is required');
  if (peerUid === uid) {
    throw new HttpsError('invalid-argument', 'Cannot create a chat with yourself');
  }

  const schoolId = (await resolveSchoolIdForUid(uid)) || providedSchoolId;
  if (!schoolId) throw new HttpsError('failed-precondition', 'No school membership found');
  assertSameSchool(providedSchoolId, schoolId);

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
        participantMap: {[participants[0]]: true, [participants[1]]: true},
        createdByUid: uid,
        createdAt: FieldValue.serverTimestamp(),
        lastMessage: '',
        lastMessageAt: FieldValue.serverTimestamp(),
        lastMessageSenderUid: '',
        lastReadAt: {
          [participants[0]]: FieldValue.serverTimestamp(),
          [participants[1]]: FieldValue.serverTimestamp(),
        },
      });
    }
  });

  return {ok: true, chatId, schoolId};
});

exports.sendMessage = onCall(async (request) => {
  const uid = assertAuth(request);
  const chatId = String(request.data?.chatId || '').trim();
  const text = String(request.data?.text || '').trim();
  const providedSchoolId = String(request.data?.schoolId || '').trim();

  if (!chatId || !text) throw new HttpsError('invalid-argument', 'chatId and text are required');
  if (text.length > 2000) throw new HttpsError('invalid-argument', 'Message too long');

  const schoolId = (await resolveSchoolIdForUid(uid)) || providedSchoolId;
  if (!schoolId) throw new HttpsError('failed-precondition', 'No school membership found');
  assertSameSchool(providedSchoolId, schoolId);

  const chatRef = db.doc(`schools/${schoolId}/chats/${chatId}`);
  const chatSnap = await chatRef.get();
  if (!chatSnap.exists) throw new HttpsError('not-found', 'Chat not found');

  const chat = chatSnap.data() || {};
  const participants = Array.isArray(chat.participants) ? chat.participants.map(String) : [];
  if (participants.length !== 2 || !participants.includes(uid)) {
    throw new HttpsError('permission-denied', 'Not a participant');
  }

  const peerUid = participants.find((p) => p !== uid);
  if (!peerUid) throw new HttpsError('internal', 'Invalid chat participants');

  const msgRef = chatRef.collection('messages').doc();
  await db.runTransaction(async (tx) => {
    tx.set(msgRef, {
      senderUid: uid,
      text,
      status: 'sent',
      createdAt: FieldValue.serverTimestamp(),
    });
    tx.update(chatRef, {
      lastMessage: text,
      lastMessageAt: FieldValue.serverTimestamp(),
      lastMessageSenderUid: uid,
      [`lastReadAt.${uid}`]: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
  });

  // Push (best-effort). Si falla, el envío del mensaje NO debe fallar.
  try {
    const peerSnap = await db.doc(`schools/${schoolId}/users/${peerUid}`).get();
    const tokens = Array.isArray(peerSnap.data()?.fcmTokens) ? peerSnap.data().fcmTokens : [];
    if (tokens.length) {
      const payload = {
        notification: {
          title: 'Nuevo mensaje',
          body: text.length > 120 ? `${text.slice(0, 117)}...` : text,
        },
        data: {
          chatId,
          schoolId,
          senderUid: uid,
        },
      };

      const res = await getMessaging().sendEachForMulticast({tokens, ...payload});
      const invalid = [];
      res.responses.forEach((r, idx) => {
        if (!r.success) {
          const code = r.error?.code || '';
          if (code.includes('registration-token-not-registered') || code.includes('invalid-registration-token')) {
            invalid.push(tokens[idx]);
          }
        }
      });
      if (invalid.length) {
        await db.doc(`schools/${schoolId}/users/${peerUid}`).set(
          {fcmTokens: FieldValue.arrayRemove(...invalid), updatedAt: FieldValue.serverTimestamp()},
          {merge: true},
        );
      }
    }
  } catch (e) {
    // swallow
  }

  return {ok: true};
});

exports.markChatRead = onCall(async (request) => {
  const uid = assertAuth(request);
  const chatId = String(request.data?.chatId || '').trim();
  const providedSchoolId = String(request.data?.schoolId || '').trim();

  if (!chatId) throw new HttpsError('invalid-argument', 'chatId is required');

  const schoolId = (await resolveSchoolIdForUid(uid)) || providedSchoolId;
  if (!schoolId) throw new HttpsError('failed-precondition', 'No school membership found');
  assertSameSchool(providedSchoolId, schoolId);

  const chatRef = db.doc(`schools/${schoolId}/chats/${chatId}`);
  const chatSnap = await chatRef.get();
  if (!chatSnap.exists) throw new HttpsError('not-found', 'Chat not found');

  const chat = chatSnap.data() || {};
  const participants = Array.isArray(chat.participants) ? chat.participants.map(String) : [];
  if (!participants.includes(uid)) {
    throw new HttpsError('permission-denied', 'Not a participant');
  }

  await chatRef.set(
    {
      lastReadAt: {[uid]: FieldValue.serverTimestamp()},
      updatedAt: FieldValue.serverTimestamp(),
    },
    {merge: true},
  );

  return {ok: true};
});

exports.deleteMyAccount = onCall(async (request) => {
  const uid = assertAuth(request);
  const providedSchoolId = String(request.data?.schoolId || '').trim();
  const schoolId = (await resolveSchoolIdForUid(uid)) || providedSchoolId;
  if (!schoolId) throw new HttpsError('failed-precondition', 'No school membership found');
  assertSameSchool(providedSchoolId, schoolId);

  const posts = await db.collection(`schools/${schoolId}/posts`).where('authorUid', '==', uid).get();
  const events = await db.collection(`schools/${schoolId}/events`).where('organizerUid', '==', uid).get();
  const eventsForAttendees = await db.collection(`schools/${schoolId}/events`).get();
  const chats = await db.collection(`schools/${schoolId}/chats`).where('participants', 'array-contains', uid).get();

  const ops = [];
  posts.docs.forEach((doc) => ops.push({type: 'update', ref: doc.ref, data: {status: 'deleted', updatedAt: FieldValue.serverTimestamp()}}));
  events.docs.forEach((doc) => ops.push({type: 'update', ref: doc.ref, data: {status: 'deleted', updatedAt: FieldValue.serverTimestamp()}}));
  for (const eventDoc of eventsForAttendees.docs) {
    const attendeeRef = eventDoc.ref.collection('attendees').doc(uid);
    const attendeeSnap = await attendeeRef.get();
    if (attendeeSnap.exists) {
      ops.push({type: 'delete', ref: attendeeRef});
    }
  }

  // Mensajes del usuario: anonimizamos (status=deleted, text='') para que el otro participante no vea contenido.
  for (const chatDoc of chats.docs) {
    const chatRef = chatDoc.ref;
    const msgSnap = await chatRef.collection('messages').where('senderUid', '==', uid).limit(500).get();
    msgSnap.docs.forEach((m) =>
      ops.push({
        type: 'update',
        ref: m.ref,
        data: {status: 'deleted', text: '', deletedAt: FieldValue.serverTimestamp()},
      }),
    );

    // Si el lastMessage pertenece al usuario borrado, lo limpiamos.
    const lastMsgSnap = await chatRef.collection('messages').orderBy('createdAt', 'desc').limit(1).get();
    const lastMsg = lastMsgSnap.docs[0]?.data();
    if (lastMsg && String(lastMsg.senderUid || '') === uid) {
      ops.push({type: 'update', ref: chatRef, data: {lastMessage: '', updatedAt: FieldValue.serverTimestamp()}});
    }
  }

  // Borrar membresía (solo backend) y luego Auth.
  ops.push({type: 'delete', ref: db.doc(`schools/${schoolId}/users/${uid}`)});

  // Commit en lotes.
  for (const group of chunk(ops, 400)) {
    const batch = db.batch();
    for (const op of group) {
      if (op.type === 'update') batch.update(op.ref, op.data);
      else if (op.type === 'delete') batch.delete(op.ref);
    }
    await batch.commit();
  }

  await getStorage().bucket().file(`schools/${schoolId}/users/${uid}/profile.jpg`).delete({ignoreNotFound: true});
  await getAuth().deleteUser(uid);

  return {ok: true, schoolId};
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

exports.addEventComment = onCall(async (request) => {
  const uid = assertAuth(request);
  const providedSchoolId = String(request.data?.schoolId || '').trim();
  const eventId = String(request.data?.eventId || '').trim();
  let body = String(request.data?.body || '').trim();

  if (!eventId) throw new HttpsError('invalid-argument', 'eventId is required');
  if (!body) throw new HttpsError('invalid-argument', 'body is required');
  if (body.length > 1000) body = body.slice(0, 1000);

  const resolvedSchoolId = await resolveSchoolIdForUid(uid);
  assertSameSchool(providedSchoolId, resolvedSchoolId);
  const schoolId = providedSchoolId || resolvedSchoolId;
  if (!schoolId) throw new HttpsError('failed-precondition', 'School not resolved');

  const membershipSnap = await db.doc(`schools/${schoolId}/users/${uid}`).get();
  if (!membershipSnap.exists) {
    throw new HttpsError('permission-denied', 'Not a member of this school');
  }

  const membership = membershipSnap.data() || {};
  const tokenName = String(request.auth?.token?.name || '').trim();
  const tokenEmail = String(request.auth?.token?.email || '').trim();
  const displayName =
    String(membership.displayName || '').trim() || tokenName || tokenEmail || 'Familia';
  const tokenPhotoUrl = String(request.auth?.token?.picture || '').trim();
  const photoUrl = String(membership.photoUrl || '').trim() || tokenPhotoUrl || null;

  const eventRef = db.doc(`schools/${schoolId}/events/${eventId}`);
  const commentRef = eventRef.collection('comments').doc();
  const snippet = body.length > 140 ? `${body.slice(0, 140)}…` : body;

  const txResult = await db.runTransaction(async (tx) => {
    const eventSnap = await tx.get(eventRef);
    if (!eventSnap.exists) throw new HttpsError('not-found', 'Evento no encontrado');

    const event = eventSnap.data() || {};
    if (String(event.status || 'active') !== 'active') {
      throw new HttpsError('failed-precondition', 'Evento inactivo');
    }

    const prevCount = Number(event.commentsCount || 0);
    const nextCount = Number.isFinite(prevCount) && prevCount >= 0 ? prevCount + 1 : 1;
    const now = FieldValue.serverTimestamp();

    tx.set(commentRef, {
      authorUid: uid,
      authorName: displayName,
      authorPhotoUrl: photoUrl,
      body,
      createdAt: now,
      status: 'active',
    });

    tx.update(eventRef, {
      commentsCount: nextCount,
      lastCommentAt: now,
      lastCommentByUid: uid,
      lastCommentSnippet: snippet,
      updatedAt: now,
    });

    return {commentsCount: nextCount};
  });

  return {ok: true, schoolId, eventId, commentsCount: txResult.commentsCount};
});
