import assert from 'node:assert/strict';
import test from 'node:test';
import {
  sanitizeStudentProfile,
  validateStudentProfileRequest,
} from '../src/profile/get_my_student_profile';

const profile = {
  schemaVersion: 1,
  fullName: 'Synthetic Student',
  ageYearsAtRegistration: 17,
  status: 'pending_guardian',
  schoolApprovalStatus: 'pending',
  medicalStatus: 'not_started',
  medicalRevision: 0,
  lrn: null,
  gender: 'Female',
  personalContactNumber: '09123456789',
  emergencyContacts: {
    primary: {
      fullName: 'Synthetic Guardian',
      relationship: 'Parent',
      phoneNumber: '+639123456789',
      internalNote: 'must not be returned',
    },
    secondary: {
      fullName: 'Synthetic Contact',
      phoneNumber: '09123456789',
      privateFlag: true,
    },
    unrelated: {secret: 'must not be returned'},
  },
  schoolId: 'private-school-id',
  medicalRecord: {conditions: 'private'},
  acknowledgment: {affirmativeAction: true},
  qrCredential: {payload: 'private'},
  internalMetadata: {privateFlag: true},
};

test('returns only the approved profile response fields', () => {
  assert.deepEqual(sanitizeStudentProfile(profile), {
    schemaVersion: 1,
    fullName: 'Synthetic Student',
    ageYearsAtRegistration: 17,
    status: 'pending_guardian',
    schoolApprovalStatus: 'pending',
    medicalStatus: 'not_started',
    medicalRevision: 0,
    gender: 'Female',
    personalContactNumber: '09123456789',
    emergencyContacts: {
      primary: {
        fullName: 'Synthetic Guardian',
        relationship: 'Parent',
        phoneNumber: '+639123456789',
      },
      secondary: {
        fullName: 'Synthetic Contact',
        phoneNumber: '09123456789',
      },
    },
  });
});

test('defaults new eligibility states for existing profiles', () => {
  assert.deepEqual(
    sanitizeStudentProfile({
      schemaVersion: 1,
      fullName: 'Synthetic Student',
      ageYearsAtRegistration: 18,
      status: 'pending_review',
      schoolApprovalStatus: 'pending',
      medicalStatus: 'not_started',
      medicalRevision: 0,
      lrn: null,
    }),
    {
      schemaVersion: 1,
      fullName: 'Synthetic Student',
      ageYearsAtRegistration: 18,
      status: 'pending_review',
      schoolApprovalStatus: 'pending',
      medicalStatus: 'not_started',
      medicalRevision: 0,
    },
  );
});

test('rejects malformed required and optional profile values', () => {
  for (const changes of [
    {schemaVersion: 2},
    {fullName: ' '},
    {ageYearsAtRegistration: '17'},
    {ageYearsAtRegistration: 131},
    {status: 'approved'},
    {schoolApprovalStatus: 'forged'},
    {medicalStatus: {complete: true}},
    {medicalRevision: -1},
    {lrn: 'private'},
    {gender: 3},
    {personalContactNumber: false},
    {emergencyContacts: 'invalid'},
    {emergencyContacts: {primary: 'invalid'}},
    {emergencyContacts: {secondary: {phoneNumber: 123}}},
  ]) {
    assert.throws(() => sanitizeStudentProfile({...profile, ...changes}));
  }
});

test('profile requests cannot provide a UID or other authority fields', () => {
  assert.doesNotThrow(() => validateStudentProfileRequest({}));
  for (const value of [
    null,
    'uid',
    [],
    {uid: 'another-student'},
    {userId: 'another-student'},
    {status: 'approved'},
  ]) {
    assert.throws(() => validateStudentProfileRequest(value));
  }
});
