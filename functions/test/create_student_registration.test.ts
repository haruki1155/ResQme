import assert from 'node:assert/strict'; import test from 'node:test'; import {noticeVersion,validateRegistration} from '../src/registration/registration_contract';
const base={fullName:'Synthetic Student',ageYears:17,noticeVersion,acknowledgmentAccepted:true};
test('rejects missing or wrong acknowledgment',()=>{assert.throws(()=>validateRegistration({...base,acknowledgmentAccepted:false}));assert.throws(()=>validateRegistration({...base,noticeVersion:'wrong'}));});
test('derives pending status by age',()=>{assert.equal(validateRegistration(base).status,'pending_guardian');assert.equal(validateRegistration({...base,ageYears:18}).status,'pending_review');});
test('ignores client approval and LRN',()=>{const r=validateRegistration({...base,status:'approved',lrn:'forged'});assert.equal(r.status,'pending_guardian');assert.equal(r.lrn,null);});
test('normalizes all approved optional fields and nulls blanks', () => {
  const input = {...base, gender: ' Female ', personalPhone: '0912 345 6789', guardianName: ' Synthetic Guardian ', guardianRelationship: 'Parent', guardianPhone: '+63 912 345 6789', secondaryName: ' Synthetic Contact ', secondaryPhone: '0912-345-6789'};
  const result = validateRegistration(input) as Record<string, unknown>;
  assert.equal(result.gender, 'Female');
  assert.equal(result.personalContactNumber, '09123456789');
  assert.deepEqual(result.emergencyContacts, {primary: {fullName: 'Synthetic Guardian', relationship: 'Parent', phoneNumber: '+639123456789'}, secondary: {fullName: 'Synthetic Contact', phoneNumber: '09123456789'}});
  assert.equal((validateRegistration({...base, gender: ' '}) as Record<string, unknown>).gender, null);
});
test('rejects malformed names, optional values and half secondary contacts', () => {
  for (const value of [{secondaryName:'Synthetic Contact'}, {secondaryPhone:'09123456789'}, {guardianPhone:'bad'}, {gender:123}, {guardianName:'x'}, {fullName:'x'}, {personalPhone:'bad'}]) {
    assert.throws(() => validateRegistration({...base, ...value}));
  }
});
