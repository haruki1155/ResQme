import assert from 'node:assert/strict';
import test from 'node:test';
import {requireTier2Eligible} from '../src/medical/tier2_challenge';
import {tier2Uid,tier2Profile,tier2Medical} from './fixtures/tier2_eligibility';

// Security-contract regressions, retained under the original diagnostic filename
// and now included explicitly in the normal unit suite.
const profile=tier2Profile;
const medical=tier2Medical;
for(const scenario of ['unassigned-school','revision-mismatch','minor-without-guardian']) {
  test(`security contract: Tier 2 denies ${scenario}`,()=>{
    const p={...profile},m={...medical};
    if(scenario==='unassigned-school') p.schoolAssignmentStatus='unassigned';
    if(scenario==='revision-mismatch') m.revision=1;
    if(scenario==='minor-without-guardian') p.ageYearsAtRegistration=17;
    assert.throws(()=>requireTier2Eligible(p,m,{uid:tier2Uid}),{code:'permission-denied'});
  });
}

test('complete adult and independently authorized minor satisfy the shared eligibility contract',()=>{
  requireTier2Eligible(profile,medical,{uid:tier2Uid});
  requireTier2Eligible({...profile,ageYearsAtRegistration:17},medical,{uid:tier2Uid,guardianAuthorization:{status:'verified',studentUid:tier2Uid,guardianUid:'fictional-guardian',verifiedAt:new Date(),method:'independent_guardian_verification'}});
});

for(const scenario of ['missing-owner','missing-school-id','invalid-age','missing-revision','missing-medical-schema','wrong-guardian-owner','self-guardian','empty-guardian','unverified-guardian','missing-guardian-date','invalid-guardian-date','wrong-guardian-method']) {
  test(`eligibility fails closed for ${scenario}`,()=>{
    const p:Record<string,unknown>={...profile},m:Record<string,unknown>={...medical};
    const context:{uid:string;guardianAuthorization?:Record<string,unknown>}={uid:tier2Uid};
    if(scenario==='missing-owner') context.uid='';
    if(scenario==='missing-school-id') delete p.schoolId;
    if(scenario==='invalid-age') p.ageYearsAtRegistration=-1;
    if(scenario==='missing-revision') delete p.medicalRevision;
    if(scenario==='missing-medical-schema') delete m.schemaVersion;
    if(scenario.includes('guardian')) {
      p.ageYearsAtRegistration=17;
      context.guardianAuthorization={status:'verified',studentUid:tier2Uid,guardianUid:'fictional-guardian',verifiedAt:new Date(),method:'independent_guardian_verification'};
      if(scenario==='wrong-guardian-owner') context.guardianAuthorization.studentUid='other';
      if(scenario==='self-guardian') context.guardianAuthorization.guardianUid=tier2Uid;
      if(scenario==='empty-guardian') context.guardianAuthorization.guardianUid='';
      if(scenario==='unverified-guardian') context.guardianAuthorization.status='pending';
      if(scenario==='missing-guardian-date') delete context.guardianAuthorization.verifiedAt;
      if(scenario==='invalid-guardian-date') context.guardianAuthorization.verifiedAt=new Date('invalid');
      if(scenario==='wrong-guardian-method') context.guardianAuthorization.method='self_reported';
    }
    assert.throws(()=>requireTier2Eligible(p,m,context),{code:'permission-denied'});
  });
}
