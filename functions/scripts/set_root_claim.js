#!/usr/bin/env node
const {initializeApp} = require('firebase-admin/app');
const {getAuth} = require('firebase-admin/auth');

async function main() {
  const uid = String(process.argv[2] || '').trim();
  if (!uid) {
    console.error('Usage: node scripts/set_root_claim.js <uid>');
    process.exit(1);
  }

  initializeApp();
  const auth = getAuth();
  const user = await auth.getUser(uid);
  const claims = {
    ...(user.customClaims || {}),
    role: 'root',
  };
  await auth.setCustomUserClaims(uid, claims);
  console.log(`Custom claim role=root assigned to uid=${uid}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
