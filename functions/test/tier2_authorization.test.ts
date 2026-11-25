import assert from 'node:assert/strict';
import {generateKeyPairSync,sign} from 'node:crypto';
import test from 'node:test';
import {requireRecentAuth,requireTier2Eligible,sanitizeTier2Record,studentEnrollmentSignedMessage,tier2SignedMessage,validateChallengeRequest,validateDeviceEnrollment,validateProof,verifyTier2Signature} from '../src/medical/tier2_challenge';
import {tier2Uid,tier2Profile,tier2Medical} from './fixtures/tier2_eligibility';

test('Tier 2 requires recent authentication and approved complete records',()=>{
  requireRecentAuth(950,1000,100);
  assert.throws(()=>requireRecentAuth(899,1000,100),{code:'failed-precondition'});
  assert.throws(()=>requireRecentAuth(1010,1000),{code:'failed-precondition'});
  requireTier2Eligible(tier2Profile,tier2Medical,{uid:tier2Uid});
  assert.throws(()=>requireTier2Eligible({...tier2Profile,schoolApprovalStatus:'pending'},tier2Medical,{uid:tier2Uid}),{code:'permission-denied'});
  assert.throws(()=>requireTier2Eligible(tier2Profile,{...tier2Medical,selfReported:false},{uid:tier2Uid}),{code:'permission-denied'});
  assert.throws(()=>requireTier2Eligible(tier2Profile,tier2Medical),{code:'permission-denied'});
});

test('Tier 2 reader returns only validated medical allowlist fields',()=>{
  const source={conditions:{state:'listed',details:'Fictional asthma',internal:'private'},allergies:{state:'none_known',details:null},primaryContact:{fullName:'Fictional Person',relationship:'Parent',phoneNumber:'09123456789',secret:'hidden'}};
  const safe=sanitizeTier2Record({...source,conditions:{state:'listed',details:'Fictional asthma'},primaryContact:{fullName:'Fictional Person',relationship:'Parent',phoneNumber:'09123456789'}});
  assert.deepEqual(Object.keys(safe).sort(),['allergies','conditions','primaryContact']);
  assert.throws(()=>sanitizeTier2Record(source),{code:'failed-precondition'});
});

test('device key and signed challenge proof are bound to exact owner/device/operation',()=>{
  const {publicKey,privateKey}=generateKeyPairSync('ec',{namedCurve:'prime256v1'});
  const deviceId='device_0123456789abcdef';
  const publicValue=publicKey.export({type:'spki',format:'der'}).toString('base64url');
  const enrollChallengeId='b'.repeat(48);
  const enrollMsg=studentEnrollmentSignedMessage({uid:'owner-a',deviceId,challengeId:enrollChallengeId,nonce:'enroll-nonce'});
  const enrollSig=sign('sha256',Buffer.from(enrollMsg),privateKey).toString('base64url');
  assert.deepEqual(
    validateDeviceEnrollment({challengeId:enrollChallengeId,deviceId,publicKey:publicValue,signature:enrollSig}),
    {challengeId:enrollChallengeId,deviceId,publicKey:publicValue,signature:enrollSig},
  );
  assert.throws(()=>validateDeviceEnrollment({deviceId,publicKey:publicValue}),{code:'invalid-argument'});
  assert.equal(verifyTier2Signature(publicValue,enrollMsg,enrollSig),true);
  assert.equal(verifyTier2Signature(publicValue,studentEnrollmentSignedMessage({uid:'owner-b',deviceId,challengeId:enrollChallengeId,nonce:'enroll-nonce'}),enrollSig),false);
  assert.deepEqual(validateChallengeRequest({deviceId,operation:'read_medical'}),{deviceId,operation:'read_medical'});
  const fields={uid:'owner-a',deviceId,operation:'read_medical',challengeId:'a'.repeat(48),nonce:'random-one-time-nonce'};
  const message=tier2SignedMessage(fields),signature=sign('sha256',Buffer.from(message),privateKey).toString('base64url');
  assert.equal(verifyTier2Signature(publicValue,message,signature),true);
  assert.equal(verifyTier2Signature(publicValue,tier2SignedMessage({...fields,uid:'owner-b'}),signature),false);
  assert.deepEqual(validateProof({challengeId:fields.challengeId,deviceId,signature}),{challengeId:fields.challengeId,deviceId,signature});
  for(const value of [{deviceId,operation:'write_medical'},{deviceId,operation:'read_medical',uid:'forged'}]) assert.throws(()=>validateChallengeRequest(value));
});
