import assert from 'node:assert/strict';
import test from 'node:test';
import {validateQrRequest} from '../src/qr/ensure_my_tier1_qr';
test('QR issuance accepts no client ownership, token or authority fields',()=>{
  validateQrRequest({});validateQrRequest(null);
  for(const value of [{uid:'other'},{status:'approved'},{token:'fake'},{medical:true},'uid',[]]) assert.throws(()=>validateQrRequest(value));
});
