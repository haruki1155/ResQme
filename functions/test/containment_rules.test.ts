import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {resolve} from 'node:path';
import test from 'node:test';
import {assertFails, initializeTestEnvironment, type RulesTestEnvironment} from '@firebase/rules-unit-testing';
import {collection, deleteDoc, doc, getDoc, getDocs, limit, query, setDoc, updateDoc} from 'firebase/firestore';

function safeEndpoint(project: string | undefined, endpoint: string | undefined) {
  assert.equal(project, 'demo-resqme', 'Containment tests require demo-resqme');
  assert.ok(endpoint === '127.0.0.1:8080' || endpoint === 'localhost:8080', 'Containment tests require loopback Firestore port 8080');
  return {host: endpoint.split(':')[0], port: 8080};
}

const paths = [
  'studentProfiles/g1-owner',
  'studentProfiles/g1-owner/acknowledgments/g1-notice',
  'studentMedicalRecords/g1-owner',
  'studentMedicalRecords/g1-owner/acknowledgments/g1-request',
  'studentMedicalRecords/g1-owner/requests/g1-request',
  'studentQrCredentials/g1-owner',
  'qaTesters/g1-owner',
  'unknown/g1-owner',
];
let environment: RulesTestEnvironment | undefined;
const root = resolve(__dirname, '../../..');
const rulesPath = resolve(root, process.env.CONTAINMENT_RULES_SOURCE ?? 'firestore.containment.rules');
assert.ok([resolve(root, 'firestore.rules'), resolve(root, 'firestore.containment.rules')].includes(rulesPath), 'Unexpected Rules source');

test('configuration rejects missing/mismatched project and unsafe endpoints', () => {
  assert.deepEqual(safeEndpoint('demo-resqme', '127.0.0.1:8080'), {host: '127.0.0.1', port: 8080});
  assert.deepEqual(safeEndpoint('demo-resqme', 'localhost:8080'), {host: 'localhost', port: 8080});
  for (const project of [undefined, 'resqme-943ee', 'demo-other']) {
    assert.throws(() => safeEndpoint(project, '127.0.0.1:8080'));
  }
  for (const endpoint of [undefined, 'example.com:8080', '0.0.0.0:8080', '127.0.0.1:8180', 'https://localhost:8080']) {
    assert.throws(() => safeEndpoint('demo-resqme', endpoint));
  }
});

test.before(async () => {
  const endpoint = safeEndpoint(process.env.GCLOUD_PROJECT, process.env.FIRESTORE_EMULATOR_HOST);
  environment = await initializeTestEnvironment({projectId: 'demo-resqme', firestore: {...endpoint, rules: await readFile(rulesPath, 'utf8')}});
  await environment.withSecurityRulesDisabled(async context => {
    for (const path of paths) await setDoc(doc(context.firestore(), path), {syntheticOnly: true, fixture: 'g1-containment'});
  });
});

test.after(async () => { await environment?.cleanup(); });

test('replacement is exactly the reviewed deny-all policy with no additional allows', async () => {
  const source = await readFile(rulesPath, 'utf8');
  assert.equal(source.replace(/\s+/g, ''), "rules_version='2';servicecloud.firestore{match/databases/{database}/documents{match/{document=**}{allowread,write:iffalse;}}}");
});

for (const principal of ['owner', 'cross-user', 'anonymous']) {
  test(`${principal} access is denied across all paths`, {timeout: 30000}, async () => {
    assert.ok(environment);
    const context = principal === 'anonymous' ? environment.unauthenticatedContext() : environment.authenticatedContext(principal === 'owner' ? 'g1-owner' : 'g1-other');
    const database = context.firestore();
    let denied = 0;
    for (const path of paths) {
      const reference = doc(database, path);
      const parent = collection(database, path.substring(0, path.lastIndexOf('/')));
      await assertFails(getDoc(reference)); denied++;
      await assertFails(getDocs(query(parent, limit(1)))); denied++;
      await assertFails(setDoc(doc(database, `${path}-new`), {syntheticOnly: true})); denied++;
      await assertFails(setDoc(reference, {forged: true})); denied++;
      await assertFails(updateDoc(reference, {forged: true})); denied++;
      await assertFails(deleteDoc(reference)); denied++;
    }
    assert.equal(denied, 48);
    console.log(`${principal}: ${denied} denied operations verified`);
  });
}
