import assert from 'node:assert/strict';
import test from 'node:test';
import {validateMedicalCompletion} from '../src/medical/medical_contract';

const base = {
  conditions: {state: 'unknown'},
  allergies: {state: 'none_known'},
  primaryContact: {
    fullName: 'Synthetic Contact', relationship: 'Parent', phoneNumber: '09123456789',
  },
  selfReportConfirmed: true, expectedRevision: 0, requestId: 'request-0001',
};

test('accepts explicit unknown and none-known with required primary contact', () => {
  const result = validateMedicalCompletion(base);
  assert.equal(result.conditions.state, 'unknown');
  assert.equal(result.allergies.state, 'none_known');
  assert.deepEqual(result.primaryContact, {
    fullName: 'Synthetic Contact', relationship: 'Parent', phoneNumber: '09123456789',
  });
});

test('requires details only for listed conditions and allergies', () => {
  const result = validateMedicalCompletion({
    ...base,
    conditions: {state: 'listed', details: 'Synthetic condition'},
    allergies: {state: 'listed', details: 'Synthetic allergy'},
  });
  assert.equal(result.conditions.details, 'Synthetic condition');
  assert.equal(result.allergies.details, 'Synthetic allergy');
  assert.throws(() => validateMedicalCompletion({
    ...base, conditions: {state: 'listed'},
  }));
  assert.throws(() => validateMedicalCompletion({
    ...base, allergies: {state: 'listed', details: ' '},
  }));
});

test('rejects missing contact, unsupported fields and forged completion status', () => {
  for (const patch of [
    {primaryContact: undefined},
    {primaryContact: {...base.primaryContact, phoneNumber: 'bad'}},
    {selfReportConfirmed: false},
    {status: 'approved'},
    {uid: 'other'},
  ]) assert.throws(() => validateMedicalCompletion({...base, ...patch}));
});
