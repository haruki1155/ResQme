import {getApps,initializeApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import {normalizeRosterName,rosterCodeDigest,rosterLookupId} from '../src/school/roster_contract';
import {syntheticSchoolRoster} from '../test/fixtures/synthetic_school_roster';

export function validateLocalRosterSeedEnvironment(env:NodeJS.ProcessEnv):{host:string;key:string} {
  if(env.GCLOUD_PROJECT!=='demo-resqme'||(env.GOOGLE_CLOUD_PROJECT!=null&&env.GOOGLE_CLOUD_PROJECT!=='demo-resqme')) throw new Error('Roster seed is restricted to demo-resqme.');
  const host=env.FIRESTORE_EMULATOR_HOST??'';
  const match=/^(localhost|127\.0\.0\.1|\[::1\]):(\d{1,5})$/.exec(host);
  const port=Number(match?.[2]);
  if(!match||port<1024||port>65535) throw new Error('Roster seed requires loopback Firestore emulator.');
  const key=env.RESQME_SCHOOL_ROSTER_HMAC_KEY??'';
  if(Buffer.byteLength(key,'utf8')<32) throw new Error('Roster seed requires an injected local-only HMAC key.');
  if(env.FIREBASE_CONFIG){
    let config:unknown;
    try{config=JSON.parse(env.FIREBASE_CONFIG);}catch{throw new Error('Invalid Firebase config.');}
    if(!config||typeof config!=='object'||(config as {projectId?:unknown}).projectId!=='demo-resqme') throw new Error('Roster seed config must target demo-resqme.');
  }
  return {host,key};
}

export async function seedLocalSchoolRoster(env:NodeJS.ProcessEnv=process.env):Promise<void> {
  const {host,key}=validateLocalRosterSeedEnvironment(env);
  const existing=getApps().find(app=>app.name==='[DEFAULT]');
  if(existing&&existing.options.projectId!=='demo-resqme') throw new Error('Existing Firebase app is not demo-resqme.');
  if(!existing) initializeApp({projectId:'demo-resqme'});
  const db=getFirestore();
  const refs=syntheticSchoolRoster.map(row=>db.doc(`schoolRosterClaims/${rosterLookupId(row.lrn,key)}`));
  const codeRows=syntheticSchoolRoster.flatMap((row,index)=>row.enrollmentCode?[{row,rosterId:refs[index].id,ref:db.doc(`schoolRosterCodes/${rosterCodeDigest(row.enrollmentCode,key)}`)}]:[]);
  if(new Set(codeRows.map(({ref})=>ref.path)).size!==codeRows.length) throw new Error('Duplicate synthetic enrollment code; refusing to seed.');
  const allRefs=[...refs,...codeRows.map(({ref})=>ref)];
  await db.runTransaction(async tx=>{
    const snapshots=await Promise.all(allRefs.map(ref=>tx.get(ref)));
    if(snapshots.some(snapshot=>snapshot.exists)) throw new Error('Roster fixture collision; refusing to overwrite existing records.');
    syntheticSchoolRoster.forEach((row,index)=>tx.create(refs[index],{
      schemaVersion:1,syntheticFixture:true,fixtureCase:row.caseId,
      schoolId:row.schoolId,normalizedName:normalizeRosterName(row.fullName),
      enrollmentCodeDigest:row.enrollmentCode?rosterCodeDigest(row.enrollmentCode,key):null,
      claimedByUid:'claimedByUid' in row?row.claimedByUid:null,
      createdAt:new Date(),
    }));
    codeRows.forEach(({row,rosterId,ref})=>tx.create(ref,{schemaVersion:1,syntheticFixture:true,rosterId,claimedByUid:'claimedByUid' in row?row.claimedByUid:null,createdAt:new Date()}));
  });
  process.stdout.write(`Seeded ${syntheticSchoolRoster.length} synthetic roster rows to ${host} in demo-resqme.\n`);
}

if(require.main===module) seedLocalSchoolRoster().catch(()=>{process.stderr.write('Local roster seed failed closed.\n');process.exitCode=1;});
