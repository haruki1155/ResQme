import assert from 'node:assert/strict'; import test from 'node:test'; import {noticeVersion,validateRegistration} from '../src/registration/registration_contract';
const base={fullName:'Synthetic Student',ageYears:17,noticeVersion,acknowledgmentAccepted:true};
test('rejects missing or wrong acknowledgment',()=>{assert.throws(()=>validateRegistration({...base,acknowledgmentAccepted:false}));assert.throws(()=>validateRegistration({...base,noticeVersion:'wrong'}));});
test('derives pending status by age',()=>{assert.equal(validateRegistration(base).status,'pending_guardian');assert.equal(validateRegistration({...base,ageYears:18}).status,'pending_review');});
test('ignores client approval and LRN',()=>{const r=validateRegistration({...base,status:'approved',lrn:'forged'});assert.equal(r.status,'pending_guardian');assert.equal(r.lrn,null);});
