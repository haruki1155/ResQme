import assert from 'node:assert/strict';
import test from 'node:test';
import {emulatorConfig} from './emulator_config';
const env = {GCLOUD_PROJECT: 'demo-resqme', FIREBASE_AUTH_EMULATOR_HOST: '127.0.0.1:9099', FIRESTORE_EMULATOR_HOST: '127.0.0.1:8080', FUNCTIONS_EMULATOR_HOST: '127.0.0.1:5001'};
test('accepts consistent loopback demo configuration', () => { assert.equal(emulatorConfig(env).functions.port, 5001); });
test('rejects mismatched project', () => { assert.throws(() => emulatorConfig({...env, GCLOUD_PROJECT: 'resqme-943ee'})); });
test('rejects missing, remote and incorrect-port endpoints', () => {
  for (const key of ['FIREBASE_AUTH_EMULATOR_HOST', 'FIRESTORE_EMULATOR_HOST', 'FUNCTIONS_EMULATOR_HOST']) {
    for (const value of [undefined, 'example.com:8080', '0.0.0.0:8080', '127.0.0.1:1']) assert.throws(() => emulatorConfig({...env, [key]: value}));
  }
});
