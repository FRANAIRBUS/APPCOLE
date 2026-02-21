const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {initializeApp} = require('firebase-admin/app');
const {getAuth} = require('firebase-admin/auth');
const {getFirestore, FieldValue} = require('firebase-admin/firestore');

initializeApp();
const db = getFirestore();

exports.redeemInviteCode = onCall(async (request) => {
  const uid = request.auth?.uid;
  const code = String(request.data?.code || '').trim().toUpperCase();

  if (!uid) throw new HttpsError('unauthenticated', 'Auth required');
  if (!code) throw new HttpsError('invalid-argument', 'Code required');

  const snap = await db.collectionGroup('inviteCodes').where('__name__', '==', code).limit(1).get();
  if (snap.empty) throw new HttpsError('not-found', 'Invalid invite code');

  const inviteRef = snap.docs[0].ref;
  const schoolRef = inviteRef.parent.parent;
  if (!schoolRef) throw new HttpsError('internal', 'Invalid invite path');

  const schoolId = schoolRef.id;

  await db.runTransaction(async (tx) => {
    const inviteDoc = await tx.get(inviteRef);
    const data = inviteDoc.data();
    if (!data) throw new HttpsError('not-found', 'Invite not found');

    const uses = Number(data.uses || 0);
    const maxUses = Number(data.maxUses || 0);
    const expiresAt = data.expiresAt?.toDate ? data.expiresAt.toDate() : null;

    if (maxUses > 0 && uses >= maxUses) throw new HttpsError('failed-precondition', 'Invite exhausted');
    if (expiresAt && expiresAt.getTime() < Date.now()) throw new HttpsError('failed-precondition', 'Invite expired');

    tx.update(inviteRef, {uses: FieldValue.increment(1)});

    const userRef = schoolRef.collection('users').doc(uid);
    tx.set(
      userRef,
      {
        classIds: data.classId ? [String(data.classId)] : [],
        createdAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
  });

  return {schoolId};
});

exports.getOrCreateChat = onCall(async (request) => {
  const uid = request.auth?.uid;
  const schoolId = String(request.data?.schoolId || '').trim();
  const peerUid = String(request.data?.peerUid || '').trim();

  if (!uid) throw new HttpsError('unauthenticated', 'Auth required');
  if (!schoolId || !peerUid || uid === peerUid) throw new HttpsError('invalid-argument', 'Invalid participants');

  const sorted = [uid, peerUid].sort();
  const chatId = `${sorted[0]}_${sorted[1]}`;
  const chatRef = db.doc(`schools/${schoolId}/chats/${chatId}`);

  await chatRef.set(
    {
      participants: sorted,
      lastMessage: null,
      lastMessageAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    },
    {merge: true},
  );

  return {chatId};
});

exports.deleteMyAccount = onCall(async (request) => {
  const uid = request.auth?.uid;
  const schoolId = String(request.data?.schoolId || '').trim();

  if (!uid) throw new HttpsError('unauthenticated', 'Auth required');
  if (!schoolId) throw new HttpsError('invalid-argument', 'schoolId required');

  const userRef = db.doc(`schools/${schoolId}/users/${uid}`);
  await userRef.delete();

  const chats = await db.collection(`schools/${schoolId}/chats`).where('participants', 'array-contains', uid).get();

  const batch = db.batch();
  for (const doc of chats.docs) {
    batch.delete(doc.ref);
  }
  await batch.commit();

  await getAuth().deleteUser(uid);

  return {deleted: true};
});
