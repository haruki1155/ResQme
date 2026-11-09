import assert from 'node:assert/strict';
import test from 'node:test';
import {validateReplaceQrRequest} from '../src/qr/replace_my_tier1_qr';

test('QR replacement accepts no client-controlled identity or authority',()=>{
  validateReplaceQrRequest({});
  for(const request of [{uid:'other'},{payload:'forged'},{schoolApprovalStatus:'approved'},null]) {
    assert.throws(()=>validateReplaceQrRequest(request));
  }
});
