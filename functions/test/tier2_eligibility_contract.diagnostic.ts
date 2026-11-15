import assert from 'node:assert/strict';
import test from 'node:test';
import {requireTier2Eligible} from '../src/medical/tier2_challenge';

// Explicit pending security-contract regressions. Run separately; failures are
// retained as blockers, not silently added to/removed from the configured suite.
const profile={schemaVersion:1,schoolApprovalStatus:'approved',medicalStatus:'complete',medicalRevision:2,schoolAssignmentStatus:'assigned',schoolId:'fictional-school',ageYearsAtRegistration:20};
const medical={medicalStatus:'complete',selfReported:true,revision:2};
for(const scenario of ['unassigned-school','revision-mismatch','minor-without-guardian']) {
  test(`pending contract: Tier 2 denies ${scenario}`,()=>{
    const p={...profile},m={...medical};
    if(scenario==='unassigned-school') p.schoolAssignmentStatus='unassigned';
    if(scenario==='revision-mismatch') m.revision=1;
    if(scenario==='minor-without-guardian') p.ageYearsAtRegistration=17;
    assert.throws(()=>requireTier2Eligible(p,m),{code:'permission-denied'});
  });
}
