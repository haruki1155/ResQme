import assert from 'node:assert/strict';
import test from 'node:test';
import {evaluateRosterClaim,matchingRosterSchool,normalizeLrn,normalizeRosterName,rosterCodeDigest,rosterLookupId} from '../src/school/roster_contract';
import {syntheticSchoolRoster} from './fixtures/synthetic_school_roster';
import {validateLocalRosterSeedEnvironment} from '../tools/seed_local_school_roster';

const key='local-only-synthetic-test-key-not-for-hosted-use';
test('requires a 12 digit string and preserves leading zeroes',()=>{
 assert.equal(normalizeLrn('001234567890'),'001234567890');
 for(const value of [123456789012,'12345678901','abcdefghijkl']) assert.throws(()=>normalizeLrn(value));
});
test('normalizes roster names and uses keyed non-enumerable document identifiers',()=>{
 assert.equal(normalizeRosterName('  SYNTHETIC   Student '),'synthetic student');
 assert.match(rosterLookupId('001234567890',key),/^[a-f0-9]{64}$/);
 assert.notEqual(rosterLookupId('001234567890',key),rosterLookupId('001234567890',`${key}x`));
});
test('five local cases cover three auto matches, manual fallback and a claimed conflict',()=>{
 assert.equal(syntheticSchoolRoster.length,5);
 assert.equal(new Set(syntheticSchoolRoster.flatMap(row=>row.enrollmentCode?[row.enrollmentCode]:[])).size,4);
 const [a,b,c,d,e]=syntheticSchoolRoster;
 for(const row of [a,b,c]) assert.equal(evaluateRosterClaim({roster:{schoolId:row.schoolId,normalizedName:normalizeRosterName(row.fullName),enrollmentCodeDigest:rosterCodeDigest(row.enrollmentCode!,key)},codeClaim:{rosterId:rosterLookupId(row.lrn,key)},rosterId:rosterLookupId(row.lrn,key),lrn:row.lrn,fullName:row.fullName,enrollmentCode:row.enrollmentCode,uid:'uid-new',key}),'auto_approve');
 assert.equal(evaluateRosterClaim({roster:{schoolId:d.schoolId,normalizedName:normalizeRosterName(d.fullName),enrollmentCodeDigest:null},lrn:d.lrn,fullName:d.fullName,enrollmentCode:null,uid:'uid-d',key}),'manual_review');
 assert.equal(evaluateRosterClaim({roster:{schoolId:e.schoolId,normalizedName:normalizeRosterName(e.fullName),enrollmentCodeDigest:rosterCodeDigest(e.enrollmentCode!,key),claimedByUid:'uid-claimed'},codeClaim:{rosterId:rosterLookupId(e.lrn,key),claimedByUid:'uid-claimed'},rosterId:rosterLookupId(e.lrn,key),lrn:e.lrn,fullName:e.fullName,enrollmentCode:e.enrollmentCode,uid:'uid-other',key}),'conflict');
 assert.equal(evaluateRosterClaim({roster:{schoolId:a.schoolId,normalizedName:normalizeRosterName(a.fullName),enrollmentCodeDigest:rosterCodeDigest(a.enrollmentCode!,key)},codeClaim:{rosterId:rosterLookupId(a.lrn,key)},rosterId:rosterLookupId(a.lrn,key),lrn:a.lrn,fullName:'Different Synthetic Student',enrollmentCode:a.enrollmentCode,uid:'uid-x',key}),'manual_review');
 assert.equal(evaluateRosterClaim({roster:{schoolId:a.schoolId,normalizedName:normalizeRosterName(a.fullName),enrollmentCodeDigest:rosterCodeDigest(a.enrollmentCode!,key)},codeClaim:{rosterId:rosterLookupId(a.lrn,key)},rosterId:rosterLookupId(a.lrn,key),lrn:a.lrn,fullName:a.fullName,enrollmentCode:'WRONG-LOCAL-CODE-000001',uid:'uid-x',key}),'manual_review');
 assert.equal(evaluateRosterClaim({roster:{schoolId:a.schoolId,normalizedName:normalizeRosterName(a.fullName),enrollmentCodeDigest:rosterCodeDigest(a.enrollmentCode!,key)},codeClaim:{rosterId:rosterLookupId(b.lrn,key)},rosterId:rosterLookupId(a.lrn,key),lrn:a.lrn,fullName:a.fullName,enrollmentCode:a.enrollmentCode,uid:'uid-x',key}),'manual_review');
 assert.equal(evaluateRosterClaim({roster:{schoolId:a.schoolId,normalizedName:normalizeRosterName(a.fullName),enrollmentCodeDigest:rosterCodeDigest(a.enrollmentCode!,key),codeExpiresAt:10},codeClaim:{rosterId:rosterLookupId(a.lrn,key)},rosterId:rosterLookupId(a.lrn,key),lrn:a.lrn,fullName:a.fullName,enrollmentCode:a.enrollmentCode,uid:'uid-x',key,now:10}),'manual_review');
 assert.equal(matchingRosterSchool(undefined,a.fullName),null);
});
test('local seeder requires demo project, loopback Firestore and an injected local key',()=>{
 const base={GCLOUD_PROJECT:'demo-resqme',FIRESTORE_EMULATOR_HOST:'127.0.0.1:8080',RESQME_SCHOOL_ROSTER_HMAC_KEY:key};
 assert.doesNotThrow(()=>validateLocalRosterSeedEnvironment(base));
 for(const env of [{...base,GCLOUD_PROJECT:'resqme-943ee'},{...base,FIRESTORE_EMULATOR_HOST:'firestore.googleapis.com:443'},{...base,FIRESTORE_EMULATOR_HOST:''},{...base,GOOGLE_CLOUD_PROJECT:'resqme-943ee'},{...base,RESQME_SCHOOL_ROSTER_HMAC_KEY:'short'},{GCLOUD_PROJECT:'demo-resqme',FIRESTORE_EMULATOR_HOST:'127.0.0.1:8080',RESQME_ROSTER_HMAC_KEY:key}]) assert.throws(()=>validateLocalRosterSeedEnvironment(env));
});
