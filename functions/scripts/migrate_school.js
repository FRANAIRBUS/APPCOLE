#!/usr/bin/env node
/* eslint-disable no-console */
const {initializeApp} = require('firebase-admin/app');
const {getFirestore, FieldPath, FieldValue} = require('firebase-admin/firestore');
const {getStorage} = require('firebase-admin/storage');

const READ_PAGE = 200;
const WRITE_BATCH = 400;

function parseArgs(argv) {
  const args = {
    from: '',
    to: '',
    apply: false,
    allowMerge: false,
    deleteOld: false,
    updateGlobalUsers: true,
    rewriteSchoolId: false,
    copyStorage: false,
  };

  for (let i = 0; i < argv.length; i += 1) {
    const token = argv[i];
    if (token === '--from') {
      args.from = String(argv[i + 1] || '').trim();
      i += 1;
      continue;
    }
    if (token === '--to') {
      args.to = String(argv[i + 1] || '').trim();
      i += 1;
      continue;
    }
    if (token === '--apply') {
      args.apply = true;
      continue;
    }
    if (token === '--allow-merge') {
      args.allowMerge = true;
      continue;
    }
    if (token === '--delete-old') {
      args.deleteOld = true;
      continue;
    }
    if (token === '--no-update-global-users') {
      args.updateGlobalUsers = false;
      continue;
    }
    if (token === '--rewrite-school-id') {
      args.rewriteSchoolId = true;
      continue;
    }
    if (token === '--copy-storage') {
      args.copyStorage = true;
      continue;
    }
  }

  return args;
}

function usage() {
  console.log('Usage: node scripts/migrate_school.js --from <oldId> --to <newId> [--apply]');
  console.log('Optional flags:');
  console.log('  --allow-merge           Allow data in destination school');
  console.log('  --delete-old            Delete old school after copy (move)');
  console.log('  --no-update-global-users  Skip updating users/{uid}.schoolId snapshot');
  console.log('  --rewrite-school-id     Rewrite data.schoolId == oldId to newId while copying');
  console.log('  --copy-storage          Copy storage files under schools/<oldId>/ to schools/<newId>/');
  console.log('  --apply                 Perform writes (omit for dry-run)');
}

function maybeRewriteSchoolId(data, fromId, toId, rewrite) {
  if (!rewrite || !data || typeof data !== 'object') return data;
  if (data.schoolId !== fromId) return data;
  return {...data, schoolId: toId};
}

async function hasAnyDocs(colRef) {
  const snap = await colRef.limit(1).get();
  return !snap.empty;
}

async function copyCollection({
  db,
  srcCol,
  destCol,
  dryRun,
  stats,
  fromId,
  toId,
  rewriteSchoolId,
}) {
  let lastDoc = null;
  while (true) {
    let query = srcCol.orderBy(FieldPath.documentId()).limit(READ_PAGE);
    if (lastDoc) query = query.startAfter(lastDoc);
    const snap = await query.get();
    if (snap.empty) break;

    if (!dryRun) {
      const batch = db.batch();
      for (const doc of snap.docs) {
        const data = maybeRewriteSchoolId(doc.data(), fromId, toId, rewriteSchoolId);
        batch.set(destCol.doc(doc.id), data, {merge: true});
      }
      await batch.commit();
    }

    stats.docsCopied += snap.size;

    for (const doc of snap.docs) {
      const subcols = await doc.ref.listCollections();
      for (const subcol of subcols) {
        stats.subcollections += 1;
        await copyCollection({
          db,
          srcCol: subcol,
          destCol: destCol.doc(doc.id).collection(subcol.id),
          dryRun,
          stats,
          fromId,
          toId,
          rewriteSchoolId,
        });
      }
    }

    lastDoc = snap.docs[snap.docs.length - 1];
  }
}

async function deleteDocTree({docRef, dryRun, stats}) {
  const subcols = await docRef.listCollections();
  for (const subcol of subcols) {
    await deleteCollection({colRef: subcol, dryRun, stats});
  }

  if (!dryRun) {
    await docRef.delete();
  }
  stats.docsDeleted += 1;
}

async function deleteCollection({colRef, dryRun, stats}) {
  let lastDoc = null;
  while (true) {
    let query = colRef.orderBy(FieldPath.documentId()).limit(READ_PAGE);
    if (lastDoc) query = query.startAfter(lastDoc);
    const snap = await query.get();
    if (snap.empty) break;

    for (const doc of snap.docs) {
      await deleteDocTree({docRef: doc.ref, dryRun, stats});
    }

    lastDoc = snap.docs[snap.docs.length - 1];
  }
}

function chunk(array, size) {
  const out = [];
  for (let i = 0; i < array.length; i += size) out.push(array.slice(i, i + size));
  return out;
}

async function collectUserIds({colRef}) {
  const ids = [];
  let lastDoc = null;
  while (true) {
    let query = colRef.orderBy(FieldPath.documentId()).limit(READ_PAGE);
    if (lastDoc) query = query.startAfter(lastDoc);
    const snap = await query.get();
    if (snap.empty) break;
    ids.push(...snap.docs.map((d) => d.id));
    lastDoc = snap.docs[snap.docs.length - 1];
  }
  return ids;
}

async function updateGlobalUsers({
  db,
  userIds,
  colegio,
  dryRun,
  stats,
  toId,
}) {
  const payload = {
    schoolId: toId,
    schoolName: String(colegio.nombre || '').trim(),
    schoolLocalidad: String(colegio.localidad || '').trim(),
    schoolProvincia: String(colegio.provincia || '').trim(),
    updatedAt: FieldValue.serverTimestamp(),
  };

  for (const group of chunk(userIds, WRITE_BATCH)) {
    if (!dryRun) {
      const batch = db.batch();
      for (const uid of group) {
        batch.set(db.collection('users').doc(uid), payload, {merge: true});
      }
      await batch.commit();
    }
    stats.globalUsersUpdated += group.length;
  }
}

async function copyStoragePrefix({fromId, toId, dryRun, stats}) {
  const bucket = getStorage().bucket();
  const prefix = `schools/${fromId}/`;
  let pageToken = undefined;

  while (true) {
    const [files, , response] = await bucket.getFiles({
      prefix,
      autoPaginate: false,
      pageToken,
    });

    for (const file of files) {
      const destName = file.name.replace(prefix, `schools/${toId}/`);
      if (!dryRun) {
        await file.copy(bucket.file(destName));
      }
      stats.storageFilesCopied += 1;
    }

    pageToken = response?.nextPageToken;
    if (!pageToken) break;
  }
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (!args.from || !args.to) {
    usage();
    process.exit(1);
  }
  if (args.from === args.to) {
    console.error('from and to cannot be the same.');
    process.exit(1);
  }

  const dryRun = !args.apply;
  initializeApp();
  const db = getFirestore();

  const colegioSnap = await db.collection('colegios').doc(args.to).get();
  if (!colegioSnap.exists) {
    console.error(`Destination colegio not found: colegios/${args.to}`);
    process.exit(1);
  }

  const destUsersCol = db.collection(`schools/${args.to}/users`);
  const destHasUsers = await hasAnyDocs(destUsersCol);
  if (destHasUsers && !args.allowMerge) {
    console.error('Destination school has data (users). Use --allow-merge if this is intended.');
    process.exit(1);
  }

  const stats = {
    docsCopied: 0,
    subcollections: 0,
    docsDeleted: 0,
    globalUsersUpdated: 0,
    storageFilesCopied: 0,
  };

  console.log(`Mode: ${dryRun ? 'dry-run' : 'apply'}`);
  console.log(`Copying schools/${args.from} -> schools/${args.to}`);

  const srcDoc = db.doc(`schools/${args.from}`);
  const destDoc = db.doc(`schools/${args.to}`);
  const srcSnap = await srcDoc.get();
  if (srcSnap.exists) {
    const data = maybeRewriteSchoolId(srcSnap.data(), args.from, args.to, args.rewriteSchoolId);
    if (!dryRun) {
      await destDoc.set(data, {merge: true});
    }
    stats.docsCopied += 1;
  }

  const subcols = await srcDoc.listCollections();
  for (const subcol of subcols) {
    stats.subcollections += 1;
    await copyCollection({
      db,
      srcCol: subcol,
      destCol: destDoc.collection(subcol.id),
      dryRun,
      stats,
      fromId: args.from,
      toId: args.to,
      rewriteSchoolId: args.rewriteSchoolId,
    });
  }

  if (args.updateGlobalUsers) {
    const userIds = await collectUserIds({colRef: db.collection(`schools/${args.from}/users`)});
    await updateGlobalUsers({
      db,
      userIds,
      colegio: colegioSnap.data() || {},
      dryRun,
      stats,
      toId: args.to,
    });
  }

  if (args.copyStorage) {
    await copyStoragePrefix({fromId: args.from, toId: args.to, dryRun, stats});
  }

  if (args.deleteOld) {
    console.log('Deleting old school...');
    await deleteDocTree({docRef: srcDoc, dryRun, stats});
  }

  console.log('Done.');
  console.log(JSON.stringify(stats, null, 2));
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
