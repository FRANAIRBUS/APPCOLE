#!/usr/bin/env node
/* eslint-disable no-console */
const fs = require('node:fs');
const path = require('node:path');
const {initializeApp} = require('firebase-admin/app');
const {getFirestore, FieldValue} = require('firebase-admin/firestore');

const MAX_BATCH = 400;

const DIACRITIC_MAP = {
  a: 'a',
  á: 'a',
  à: 'a',
  ä: 'a',
  â: 'a',
  ã: 'a',
  å: 'a',
  e: 'e',
  é: 'e',
  è: 'e',
  ë: 'e',
  ê: 'e',
  i: 'i',
  í: 'i',
  ì: 'i',
  ï: 'i',
  î: 'i',
  o: 'o',
  ó: 'o',
  ò: 'o',
  ö: 'o',
  ô: 'o',
  õ: 'o',
  u: 'u',
  ú: 'u',
  ù: 'u',
  ü: 'u',
  û: 'u',
  ñ: 'n',
  ç: 'c',
};

function normalizeForSearch(value) {
  const lowered = String(value || '').toLowerCase().trim();
  if (!lowered) return '';

  let out = '';
  let prevSpace = false;
  for (const char of lowered) {
    const mapped = DIACRITIC_MAP[char] || char;
    const keep = /[a-z0-9]/.test(mapped);
    if (keep) {
      out += mapped;
      prevSpace = false;
    } else if (!prevSpace) {
      out += ' ';
      prevSpace = true;
    }
  }
  return out.replace(/\s+/g, ' ').trim();
}

function parseArgs(argv) {
  const args = {
    file: '',
    dryRun: false,
    updatedBy: 'import-script',
    inactiveByDefault: false,
  };
  for (let i = 0; i < argv.length; i += 1) {
    const token = argv[i];
    if (token === '--file') {
      args.file = String(argv[i + 1] || '').trim();
      i += 1;
      continue;
    }
    if (token === '--dry-run') {
      args.dryRun = true;
      continue;
    }
    if (token === '--updated-by') {
      args.updatedBy = String(argv[i + 1] || '').trim() || 'import-script';
      i += 1;
      continue;
    }
    if (token === '--inactive-by-default') {
      args.inactiveByDefault = true;
      continue;
    }
  }
  return args;
}

function loadRows(filePath) {
  const absolute = path.resolve(process.cwd(), filePath);
  if (!fs.existsSync(absolute)) {
    throw new Error(`File not found: ${absolute}`);
  }
  const raw = fs.readFileSync(absolute, 'utf8');
  const json = JSON.parse(raw);

  if (Array.isArray(json)) return json;
  if (Array.isArray(json.colegios)) return json.colegios;
  if (Array.isArray(json.items)) return json.items;
  throw new Error('JSON must be an array or { colegios: [...] }');
}

function pick(row, keys) {
  for (const key of keys) {
    const val = row?.[key];
    if (val !== undefined && val !== null && String(val).trim() !== '') {
      return String(val).trim();
    }
  }
  return '';
}

function toSchoolDoc(row, updatedBy, inactiveByDefault) {
  const codigoCentro = pick(row, ['codigoCentro', 'codigo', 'id', 'code']);
  const nombre = pick(row, ['nombre', 'name']);
  const localidad = pick(row, ['localidad', 'municipio', 'city']);
  const provincia = pick(row, ['provincia', 'province']);

  if (!codigoCentro || !nombre || !localidad || !provincia) {
    return {ok: false, reason: 'Missing required field(s)', row};
  }

  return {
    ok: true,
    id: codigoCentro,
    data: {
      codigoCentro,
      nombre,
      localidad,
      provincia,
      nombre_normalizado: normalizeForSearch(nombre),
      localidad_normalizada: normalizeForSearch(localidad),
      provincia_normalizada: normalizeForSearch(provincia),
      activo: inactiveByDefault ? false : true,
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy,
    },
  };
}

async function commitInChunks(db, docs) {
  let committed = 0;
  for (let i = 0; i < docs.length; i += MAX_BATCH) {
    const slice = docs.slice(i, i + MAX_BATCH);
    const batch = db.batch();
    for (const entry of slice) {
      const ref = db.collection('colegios').doc(entry.id);
      batch.set(ref, entry.data, {merge: true});
    }
    await batch.commit();
    committed += slice.length;
    console.log(`Committed ${committed}/${docs.length}`);
  }
}

async function main() {
  const {file, dryRun, updatedBy, inactiveByDefault} = parseArgs(process.argv.slice(2));
  if (!file) {
    console.error('Usage: node scripts/import_colegios.js --file <path> [--dry-run] [--updated-by <uid>] [--inactive-by-default]');
    process.exit(1);
  }

  const rows = loadRows(file);
  if (!rows.length) {
    console.log('No rows to import.');
    return;
  }

  const valid = [];
  const invalid = [];
  for (const row of rows) {
    const parsed = toSchoolDoc(row, updatedBy, inactiveByDefault);
    if (parsed.ok) valid.push(parsed);
    else invalid.push(parsed);
  }

  const dedup = new Map();
  for (const item of valid) {
    dedup.set(item.id, item);
  }
  const docs = [...dedup.values()];

  console.log(`Rows input: ${rows.length}`);
  console.log(`Valid rows: ${valid.length}`);
  console.log(`Unique by codigoCentro: ${docs.length}`);
  console.log(`Invalid rows: ${invalid.length}`);

  if (invalid.length) {
    console.log('First invalid row sample:');
    console.log(JSON.stringify(invalid[0], null, 2));
  }

  if (dryRun) {
    console.log('Dry-run mode. No writes performed.');
    return;
  }

  initializeApp();
  const db = getFirestore();
  await commitInChunks(db, docs);
  console.log('Import completed.');
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
