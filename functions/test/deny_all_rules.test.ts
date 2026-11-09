import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {resolve} from 'node:path';
import test from 'node:test';
import {
  assertFails,
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  setDoc,
} from 'firebase/firestore';

let environment: RulesTestEnvironment;

test.before(async () => {
  const endpoint = process.env.FIRESTORE_EMULATOR_HOST;
  assert.ok(endpoint, 'FIRESTORE_EMULATOR_HOST must be set by the emulator');
  const [host, port] = endpoint.split(':');
  environment = await initializeTestEnvironment({
    projectId: 'demo-resqme',
    firestore: {
      host,
      port: Number(port),
      rules: await readFile(
        resolve(process.cwd(), '../firestore.containment.rules'),
        'utf8',
      ),
    },
  });
});

test.after(async () => {
  await environment.cleanup();
});

test('deny-all rules reject reads and writes for authenticated clients', async () => {
  const database = environment.authenticatedContext('synthetic-student').firestore();
  await assertFails(getDoc(doc(database, 'studentProfiles/synthetic-student')));
  await assertFails(getDocs(collection(database, 'studentProfiles')));
  await assertFails(
    setDoc(doc(database, 'studentProfiles/synthetic-student'), {fullName: 'Synthetic'}),
  );
  await assertFails(
    deleteDoc(doc(database, 'studentProfiles/synthetic-student')),
  );
  await assertFails(
    getDoc(doc(database, 'studentQrCredentials/synthetic-student')),
  );
  await assertFails(
    setDoc(doc(database, 'studentMedicalRecords/synthetic-student'), {
      conditions: 'none',
    }),
  );
});

test('deny-all rules reject unauthenticated profile access', async () => {
  const database = environment.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(database, 'studentProfiles/synthetic-student')));
  await assertFails(
    setDoc(doc(database, 'studentProfiles/synthetic-student'), {fullName: 'Synthetic'}),
  );
});
