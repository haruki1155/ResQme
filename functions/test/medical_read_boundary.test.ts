import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {resolve} from 'node:path';
import test from 'node:test';
import type {CallableRequest} from 'firebase-functions/v2/https';
import {
  getMyMedicalRecordStatus,
  getMySyntheticMedicalRecord,
} from '../src/medical/get_my_synthetic_medical_record';

const authorization = require('../src/onboarding/authorization') as typeof import('../src/onboarding/authorization');

function mockDb(entries: Array<[string, Record<string, unknown>]>) {
  const rows = new Map(entries);
  const get = async (path: string) => {
    const data = rows.get(path);
    return {
      exists: data !== undefined,
      data: () => (data ? structuredClone(data) : undefined),
      get: (field: string) => (data ? data[field] : undefined),
    };
  };
  return {
    doc: (path: string) => ({path, get: () => get(path)}),
    async runTransaction<T>(action: (tx: {get: (ref: {path: string}) => ReturnType<typeof get>}) => Promise<T>) {
      return action({get: (ref) => get(ref.path)});
    },
  };
}

function callableRequest(uid: string | undefined, data: unknown = {}, authTime = Math.floor(Date.now() / 1000)) {
  return {
    auth: uid ? {uid, token: {auth_time: authTime}} : undefined,
    data,
  } as unknown as CallableRequest;
}

test('firestore.rules denies direct client reads of studentMedicalRecords', async () => {
  const rules = await readFile(resolve(process.cwd(), '../firestore.rules'), 'utf8');
  const medicalBlock = rules.match(/match \/studentMedicalRecords\/\{uid\}\s*\{[\s\S]*?\n    \}/);
  assert.ok(medicalBlock, 'studentMedicalRecords match block must exist');
  assert.doesNotMatch(medicalBlock[0], /allow\s+read\s*:\s*if\s+request\.auth/);
  assert.match(medicalBlock[0], /allow\s+read,\s*write:\s*if\s+false/);
});

test('getMyMedicalRecordStatus returns metadata-only status without health fields', async (t) => {
  const db = mockDb([
    ['studentProfiles/student-1', {schemaVersion: 1, status: 'pending_review', fullName: 'Fictional Student', ageYearsAtRegistration: 20, medicalStatus: 'complete', medicalRevision: 2, lrn: '123456789012'}],
    ['studentMedicalRecords/student-1', {schemaVersion: 1, medicalStatus: 'complete', selfReported: true, revision: 2, conditions: {state: 'listed', details: 'Fictional asthma'}, allergies: {state: 'none_known', details: null}, primaryContact: {fullName: 'Fictional Guardian', relationship: 'Parent', phoneNumber: '09170000001'}}],
  ]);
  t.mock.method(authorization, 'onboardingDatabase', () => db as never);
  const result = await getMyMedicalRecordStatus.run(callableRequest('student-1', {}));
  assert.deepEqual(result, {medicalStatus: 'complete', revision: 2, completed: true});
  assert.equal('conditions' in result, false);
  assert.equal('allergies' in result, false);
  assert.equal('primaryContact' in result, false);
  assert.equal('lrn' in result, false);
});

test('getMyMedicalRecordStatus rejects unauthenticated and extra authority fields', async () => {
  await assert.rejects(() => getMyMedicalRecordStatus.run(callableRequest(undefined, {})), {code: 'unauthenticated'});
  await assert.rejects(() => getMyMedicalRecordStatus.run(callableRequest('student-1', {uid: 'other'})), {code: 'invalid-argument'});
});

test('getMySyntheticMedicalRecord requires fresh auth and qaTester flag and refuses production records', async (t) => {
  const staleTime = Math.floor(Date.now() / 1000) - 600;
  const db = mockDb([
    ['qaTesters/student-1', {enabled: true, syntheticOnly: true}],
    ['studentProfiles/student-1', {schemaVersion: 1, status: 'pending_review', fullName: 'Fictional Student', ageYearsAtRegistration: 20, emergencyContacts: {primary: {fullName: 'Fictional Contact', relationship: 'Parent', phoneNumber: '09170000001'}}}],
    ['studentMedicalRecords/student-1', {schemaVersion: 1, syntheticOnly: false, medicalStatus: 'complete', selfReported: true, revision: 1, conditions: {state: 'listed', details: 'Production secret'}}],
  ]);
  t.mock.method(authorization, 'onboardingDatabase', () => db as never);
  await assert.rejects(() => getMySyntheticMedicalRecord.run(callableRequest('student-1', {}, staleTime)), {code: 'failed-precondition'});
  await assert.rejects(() => getMySyntheticMedicalRecord.run(callableRequest('student-1', {})), {code: 'failed-precondition'});
});

test('getMySyntheticMedicalRecord returns only synthetic record and primary contact for enabled qaTester', async (t) => {
  const db = mockDb([
    ['qaTesters/student-1', {enabled: true, syntheticOnly: true}],
    ['studentProfiles/student-1', {schemaVersion: 1, status: 'pending_review', fullName: 'Fictional Student', ageYearsAtRegistration: 20, lrn: '123456789012', emergencyContacts: {primary: {fullName: 'Fictional Contact', relationship: 'Parent', phoneNumber: '09170000001'}}}],
    ['studentMedicalRecords/student-1', {schemaVersion: 1, syntheticOnly: true, medicalStatus: 'completed_synthetic', guardianAuthorizationStatus: 'not_verified', revision: 1, conditions: {state: 'unknown', details: null}, allergies: {state: 'none_known', details: null}}],
  ]);
  t.mock.method(authorization, 'onboardingDatabase', () => db as never);
  const result = await getMySyntheticMedicalRecord.run(callableRequest('student-1', {}));
  assert.deepEqual(result, {
    revision: 1,
    medicalStatus: 'completed_synthetic',
    completed: true,
    primaryContact: {fullName: 'Fictional Contact', relationship: 'Parent', phoneNumber: '09170000001'},
    conditions: {state: 'unknown', details: null},
    allergies: {state: 'none_known', details: null},
  });
  assert.equal('lrn' in result, false);
});
