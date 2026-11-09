import assert from 'node:assert/strict';
import test from 'node:test';

test('registration callable is exported', async () => {
  const functionsModule = require('../..');
  assert.equal(typeof functionsModule.createStudentRegistration, 'function');
});

test('approved staging callables use the dedicated runtime identity', () => {
  const functionsModule = require('../..');
  const expectedAccount =
    'resqme-functions-runtime@resqme-943ee.iam.gserviceaccount.com';

  for (const name of [
    'createStudentRegistration',
    'getMyStudentProfile',
    'ensureMyTier1Qr',
  ]) {
    assert.equal(
      functionsModule[name].__endpoint.serviceAccountEmail,
      expectedAccount,
    );
  }
});
