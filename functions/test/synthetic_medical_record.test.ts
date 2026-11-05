import assert from 'node:assert/strict';
import test from 'node:test';
import {validateMedicalSave} from '../src/medical/medical_contract';
const base = {conditions:{state:'unknown'},allergies:{state:'none_known'},acknowledgment:{version:'synthetic-medical-v1',syntheticDataConfirmed:true},expectedRevision:0,requestId:'request-0001'};
test('medical states remain explicit and normalized', () => {
  const value=validateMedicalSave({...base,conditions:{state:'listed',details:' Synthetic condition '}});
  assert.deepEqual(value.conditions,{state:'listed',details:'Synthetic condition'});
  assert.deepEqual(value.allergies,{state:'none_known',details:null});
});
test('medical rejects malformed, oversized, forged and unacknowledged inputs', () => {
  for(const patch of [{conditions:{}},{conditions:{state:'listed',details:' '}},{allergies:{state:'listed',details:'x'.repeat(2001)}},{conditions:{state:'none_known',details:'hidden'}},{uid:'other'},{status:'approved'},{guardianVerified:true},{acknowledgment:{version:'wrong',syntheticDataConfirmed:true}},{acknowledgment:{version:'synthetic-medical-v1',syntheticDataConfirmed:false}},{expectedRevision:-1},{requestId:'short'},{emergencyContact:{fullName:'Synthetic Contact',relationship:'Parent',phoneNumber:'bad'}}]) {
    assert.throws(()=>validateMedicalSave({...base,...patch}));
  }
});
