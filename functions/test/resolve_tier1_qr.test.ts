import assert from 'node:assert/strict';
import test from 'node:test';
import {allowTier1Resolution,isCanonicalQrPayload,validateResolveQrRequest} from '../src/qr/resolve_tier1_qr';

test('resolver accepts only a canonical opaque ResQMe v1 payload request',()=>{
  const payload=`resqme:v1:${Buffer.alloc(32,7).toString('base64url')}`;
  validateResolveQrRequest({payload});
  assert.equal(isCanonicalQrPayload(payload),true);
  for(const value of [null,{}, {payload:'not-a-qr'}, {payload,uid:'other'}, 'text']) {
    assert.throws(()=>validateResolveQrRequest(value));
  }
  assert.equal(isCanonicalQrPayload('resqme:v1:bad'),false);
});
test('public QR lookup has a bounded per-IP in-memory request window',()=>{
  const ip='test-rate-limit-ip';
  for(let count=0;count<30;count++) assert.equal(allowTier1Resolution(ip,1000),true);
  assert.equal(allowTier1Resolution(ip,1000),false);
  assert.equal(allowTier1Resolution(ip,61_000),true);
  assert.equal(allowTier1Resolution(undefined,61_000),false);
});
