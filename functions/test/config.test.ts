import assert from 'node:assert/strict';
import test from 'node:test';

test('registration callable is exported', async () => {
  const functionsModule = require('../..');
  assert.equal(typeof functionsModule.createStudentRegistration, 'function');
});
