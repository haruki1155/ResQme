import assert from 'node:assert/strict';
import {generateKeyPairSync,sign} from 'node:crypto';
import test from 'node:test';
import {Timestamp} from 'firebase-admin/firestore';
import type {CallableRequest} from 'firebase-functions/v2/https';
import {readMyTier2Record} from '../src/medical/read_my_tier2_record';
import {tier2SignedMessage} from '../src/medical/tier2_challenge';
import {enrollTier2Device} from '../src/medical/enroll_tier2_device';
import {issueTier2Challenge} from '../src/medical/issue_tier2_challenge';
import {readMyTier2WithPassword} from '../src/medical/read_my_tier2_with_password';
import {tier2Uid,tier2Profile,tier2Medical} from './fixtures/tier2_eligibility';
// CommonJS reference permits a scoped test mock of the existing database boundary.
// No production seam, initialization, SDK transport or network request is used.
const authorization=require('../src/onboarding/authorization') as typeof import('../src/onboarding/authorization');

function fixture() {
  const uid=tier2Uid,deviceId='device_0123456789abcdef',challengeId='a'.repeat(48);
  const {publicKey,privateKey}=generateKeyPairSync('ec',{namedCurve:'prime256v1'});
  const message={uid,deviceId,challengeId,operation:'read_medical',nonce:'fictional-nonce'};
  const rows=new Map<string,Record<string,unknown>>([
    [`studentProfiles/${uid}`,{...tier2Profile}],
    [`studentMedicalRecords/${uid}`,{...tier2Medical,lrn:'not-returned'}],
    [`tier2Devices/${uid}`,{deviceId,status:'active',publicKey:publicKey.export({type:'spki',format:'der'}).toString('base64url')}],
    [`tier2Challenges/${challengeId}`,{...message,consumedAt:null,expiresAt:Timestamp.fromMillis(Date.now()+60_000)}],
  ]);
  const snapshot=(ref:{path:string})=>({exists:rows.has(ref.path),data:()=>rows.get(ref.path),get:(key:string)=>rows.get(ref.path)?.[key]});
  const db={
    doc:(path:string)=>({path}),
    async runTransaction<T>(action:(tx:unknown)=>Promise<T>) {
      const writes:Array<()=>void>=[];
      const result=await action({
        get:async(ref:{path:string})=>snapshot(ref),
        update:(ref:{path:string},fields:Record<string,unknown>)=>writes.push(()=>rows.set(ref.path,{...rows.get(ref.path),...fields})),
        set:(ref:{path:string},fields:Record<string,unknown>)=>writes.push(()=>rows.set(ref.path,fields)),
        create:(ref:{path:string},fields:Record<string,unknown>)=>writes.push(()=>{assert.equal(rows.has(ref.path),false);rows.set(ref.path,fields);}),
      });
      writes.forEach(write=>write()); return result;
    },
  };
  const signature=sign('sha256',Buffer.from(tier2SignedMessage(message)),privateKey).toString('base64url');
  const request={auth:{uid,token:{auth_time:Math.floor(Date.now()/1000)}},data:{deviceId,challengeId,signature}} as unknown as CallableRequest;
  return {uid,deviceId,challengeId,rows,db,request};
}

const protectedCallers={enroll:enrollTier2Device,challenge:issueTier2Challenge,biometric:readMyTier2Record,password:readMyTier2WithPassword};
test('password fallback retains the five-per-ten-minute read limit',async t=>{
  const f=fixture(); f.request.data={};
  t.mock.method(authorization,'onboardingDatabase',()=>f.db as never);
  for(let attempt=0;attempt<5;attempt++) await readMyTier2WithPassword.run(f.request);
  await assert.rejects(()=>readMyTier2WithPassword.run(f.request),{code:'resource-exhausted'});
  assert.equal(f.rows.get(`tier2PasswordRateLimits/${f.uid}`)?.attempts,5);
});
test('password fallback requires auth within 120 seconds before any rate write',async t=>{
  const f=fixture(); f.request.data={}; f.request.auth!.token.auth_time=Math.floor(Date.now()/1000)-121;
  t.mock.method(authorization,'onboardingDatabase',()=>f.db as never);
  await assert.rejects(()=>readMyTier2WithPassword.run(f.request),{code:'failed-precondition'});
  assert.equal(f.rows.has(`tier2PasswordRateLimits/${f.uid}`),false);
});
for(const [name,callable] of Object.entries(protectedCallers)) {
  for(const scenario of ['adult','verified-minor','unassigned-school','revision-mismatch','minor-without-guardian','wrong-guardian-owner']) {
    test(`${name} enforces ${scenario} from authoritative records`,async t=>{
      const f=fixture(),profile=f.rows.get(`studentProfiles/${f.uid}`)!,medical=f.rows.get(`studentMedicalRecords/${f.uid}`)!;
      if(scenario==='unassigned-school') profile.schoolAssignmentStatus='unassigned';
      if(scenario==='revision-mismatch') medical.revision=1;
      if(scenario.includes('minor')||scenario==='wrong-guardian-owner') profile.ageYearsAtRegistration=17;
      if(scenario==='verified-minor'||scenario==='wrong-guardian-owner') {
        f.rows.set(`studentGuardianAuthorizations/${f.uid}`,{status:'verified',studentUid:scenario==='wrong-guardian-owner'?'other':f.uid,guardianUid:'fictional-guardian',verifiedAt:Timestamp.now(),method:'independent_guardian_verification'});
      }
      if(name==='enroll') f.request.data={deviceId:f.deviceId,publicKey:f.rows.get(`tier2Devices/${f.uid}`)!.publicKey};
      if(name==='challenge') f.request.data={deviceId:f.deviceId,operation:'read_medical'};
      if(name==='password') f.request.data={};
      t.mock.method(authorization,'onboardingDatabase',()=>f.db as never);
      if(scenario==='adult'||scenario==='verified-minor') {
        const result=await callable.run(f.request);
        if(name==='password'||name==='biometric') assert.deepEqual(Object.keys(result).sort(),['allergies','conditions','primaryContact']);
        else if(name==='enroll') assert.equal((result as {status:string}).status,'active');
        else assert.equal((result as {operation:string}).operation,'read_medical');
      } else {
        await assert.rejects(()=>callable.run(f.request),{code:'permission-denied'});
        assert.equal(f.rows.get(`tier2Challenges/${f.challengeId}`)?.consumedAt,null);
        assert.equal(f.rows.get(`tier2Devices/${f.uid}`)?.keyVersion,undefined);
        assert.equal([...f.rows.keys()].filter(path=>path.startsWith('tier2Challenges/')).length,1);
      }
    });
  }
  test(`${name} rejects missing authentication before database initialization`,async()=>{
    const f=fixture();
    delete f.request.auth;
    await assert.rejects(()=>callable.run(f.request),{code:'unauthenticated'});
  });
}

test('handler consumes a valid proof once and returns only the medical allowlist',async t=>{
  const f=fixture();
  t.mock.method(authorization,'onboardingDatabase',()=>f.db as never);
  const result=await readMyTier2Record.run(f.request);
  assert.deepEqual(Object.keys(result).sort(),['allergies','conditions','primaryContact']);
  assert.notEqual(f.rows.get(`tier2Challenges/${f.challengeId}`)?.consumedAt,null);
  await assert.rejects(()=>readMyTier2Record.run(f.request),{code:'permission-denied'});
});

for(const scenario of ['expired','consumed','wrong-owner','wrong-device','wrong-operation','revoked-device','replaced-key','invalid-signature','unapproved','revoked-school','incomplete-medical','synthetic-medical','stale-auth']) {
  test(`handler denies ${scenario} without consuming the proof`,async t=>{
    const f=fixture(),challenge=f.rows.get(`tier2Challenges/${f.challengeId}`)!,device=f.rows.get(`tier2Devices/${f.uid}`)!,profile=f.rows.get(`studentProfiles/${f.uid}`)!,medical=f.rows.get(`studentMedicalRecords/${f.uid}`)!;
    if(scenario==='expired') challenge.expiresAt=Timestamp.fromMillis(Date.now()-1);
    if(scenario==='consumed') challenge.consumedAt=Timestamp.now();
    if(scenario==='wrong-owner') challenge.uid='fictional-other';
    if(scenario==='wrong-device') challenge.deviceId='device_other_0123456789';
    if(scenario==='wrong-operation') challenge.operation='write_medical';
    if(scenario==='revoked-device') device.status='revoked';
    if(scenario==='replaced-key') device.publicKey=generateKeyPairSync('ec',{namedCurve:'prime256v1'}).publicKey.export({type:'spki',format:'der'}).toString('base64url');
    if(scenario==='invalid-signature') f.request.data.signature='A'.repeat(90);
    if(scenario==='unapproved') profile.schoolApprovalStatus='pending';
    if(scenario==='revoked-school') profile.schoolApprovalStatus='revoked';
    if(scenario==='incomplete-medical') medical.medicalStatus='not_started';
    if(scenario==='synthetic-medical') medical.syntheticOnly=true;
    if(scenario==='stale-auth') f.request.auth!.token.auth_time=Math.floor(Date.now()/1000)-301;
    const before=challenge.consumedAt;
    t.mock.method(authorization,'onboardingDatabase',()=>f.db as never);
    await assert.rejects(()=>readMyTier2Record.run(f.request),{code:scenario==='stale-auth'?'failed-precondition':'permission-denied'});
    assert.equal(f.rows.get(`tier2Challenges/${f.challengeId}`)?.consumedAt,before);
  });
}
