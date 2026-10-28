import assert from 'node:assert/strict';
import test from 'node:test';

test('A0 functions module exposes no public endpoint', async () => {
  const functionsModule = require('../..');

  assert.deepEqual(functionsModule, {});
});
