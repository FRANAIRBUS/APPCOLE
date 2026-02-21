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

exports.redeemInviteCode = onCall(async (request) => {
  const uid = assertAuth(request);
  const code = String(request.data?.code || '').trim().toUpperCase();
  const childName = String(request.data?.childName || '').trim();
  const childAge = Number(request.data?.childAge || 0);
  const requestedClassId = String(request.data?.classId || '').trim();

  if (!code || !childName || !Number.isFinite(childAge) || childAge <= 0) {
    throw new HttpsError('invalid-argument', 'code, childName and childAge are required');
  }

  const inviteQuery = await db.collectionGroup('inviteCodes').where('__name__', '==', code).limit(1).get();
  if (inviteQuery.empty) throw new HttpsError('not-found', 'Invite code not found');

  const inviteRef = inviteQuery.docs[0].ref;
  const schoolRef = inviteRef.parent.parent;
  if (!schoolRef) throw new HttpsError('internal', 'Invalid invite path');

  let schoolId = schoolRef.id;

  await db.runTransaction(async (tx) => {
    const inviteSnap = await tx.get(inviteRef);
    const invite = inviteSnap.data();
    if (!invite) throw new HttpsError('not-found', 'Invite code not found');

    const uses = Number(invite.uses || 0);
    const maxUses = Number(invite.maxUses || 0);
    const expiresAt = invite.expiresAt?.toDate?.();
    if (maxUses > 0 && uses >= maxUses) throw new HttpsError('failed-precondition', 'Invite exhausted');
    if (expiresAt && expiresAt.getTime() < Date.now()) throw new HttpsError('failed-precondition', 'Invite expired');

    const classId = requestedClassId || String(invite.classId || '');
    tx.update(inviteRef, {uses: FieldValue.increment(1)});

    tx.set(
      schoolRef.collection('users').doc(uid),
      {
        displayName: request.auth.token.name || request.auth.token.email || 'Familia',
        role: 'parent',
        children: [{name: childName, age: childAge, classId}],
        classIds: classId ? [classId] : [],
        createdAt: FieldValue.serverTimestamp(),
        lastActiveAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
  });

  return {ok: true, schoolId};
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
