import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {resolve} from 'node:path';
import test from 'node:test';
import {
  assertFails,
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from '@firebase/rules-unit-testing';
import {doc, getDoc} from 'firebase/firestore';

let testEnvironment: RulesTestEnvironment;

test.before(async () => {
  const endpoint = process.env.FIRESTORE_EMULATOR_HOST;
  assert.ok(endpoint, 'FIRESTORE_EMULATOR_HOST must be set by the emulator');

  const [host, port] = endpoint.split(':');
  testEnvironment = await initializeTestEnvironment({
    projectId: 'resqme-943ee',
    firestore: {
      host,
      port: Number(port),
      rules: await readFile(resolve(process.cwd(), '../firestore.rules'), 'utf8'),
    },
  });
});

test.after(async () => {
  await testEnvironment.cleanup();
});

test('A0 Firestore rules deny an unauthenticated read', async () => {
  const database = testEnvironment.unauthenticatedContext().firestore();

  await assertFails(getDoc(doc(database, 'students', 'synthetic-student')));
});
