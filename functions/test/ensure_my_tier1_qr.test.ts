import assert from 'node:assert/strict';
import test from 'node:test';
import {hashQr,isQrPayload,validateQrRequest} from '../src/qr/ensure_my_tier1_qr';
test('QR issuance accepts no client ownership, token or authority fields',()=>{
  validateQrRequest({});validateQrRequest(null);
  for(const value of [{uid:'other'},{status:'approved'},{token:'fake'},{medical:true},'uid',[]]) assert.throws(()=>validateQrRequest(value));
});
test('QR payload validator accepts only canonical high entropy v1 references',()=>{
  const payload=`resqme:v1:${Buffer.alloc(32,9).toString('base64url')}`;
  assert.equal(isQrPayload(payload),true);
  assert.equal(isQrPayload(`${payload}=`),false);
  assert.equal(isQrPayload('resqme:v1:invalid'),false);
  assert.equal(hashQr(payload).length,64);
});
