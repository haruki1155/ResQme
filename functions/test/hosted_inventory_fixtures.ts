import assert from 'node:assert/strict';
import {artifactFiles,baseline,sha256,validateApproval,type HostedManifest} from '../tools/g2_inventory/hosted/approval';
import {scopes,limits} from '../tools/g2_inventory/contract';
import type {SessionDependencies} from '../tools/g2_inventory/hosted/session';
import type {EvidenceIO} from '../tools/g2_inventory/hosted/evidence';
export const now=Date.parse('2026-11-07T00:00:00Z');
export function fixture():HostedManifest {
 return {schemaVersion:1,runId:'synthetic-run-001',approvalReference:'synthetic-owner-reference',validFrom:new Date(now-1000).toISOString(),validUntil:new Date(now+3600000).toISOString(),artifacts:Object.fromEntries(artifactFiles.map(p=>[p,p==='firestore.containment.rules'?baseline.sha256:'a'.repeat(64)])),nodeVersion:process.version,operator:{email:'operator@example.test',subject:'synthetic-subject',adcPath:'C:\\private\\synthetic-adc.json',adcSha256:'b'.repeat(64)},target:{project:'resqme-943ee',projectNumber:'519076598217',database:'(default)',location:'nam5'},g1:{...baseline},scopes:JSON.parse(JSON.stringify(scopes)),limits:{...limits},evidence:{path:'C:\\private\\evidence',ownerSid:'S-1-5-21-100',readerSids:['S-1-5-21-100'],retentionDeadline:new Date(now+86400000).toISOString(),disposalMethod:'Owner manually removes evidence under separate authorization',responsibleOperator:'operator@example.test',unsyncedAttested:true}};
}
export function approved(){const m=fixture();return validateApproval(m,{hashes:m.artifacts,nodeVersion:process.version},now);}
export const rules="rules_version = '2';\nservice cloud.firestore {\n  match /databases/{database}/documents {\n    match /{document=**} {\n      allow read, write: if false;\n    }\n  }\n}\n";
export function fakeSession(){
 const calls:string[]=[];const a=approved();const adc=Buffer.from('{"type":"authorized_user","client_id":"synthetic","client_secret":"synthetic","refresh_token":"synthetic"}');
 const deps:SessionDependencies={adcBytes:adc,now:()=>now,deadline:now+600000,send:async(url,init)=>{calls.push(String(url));assert.equal(new Headers(init?.headers).get('Authorization'),'Bearer SYNTHETIC_TOKEN');const u=String(url);let data:any;
 if(u.includes('/releases/'))data={name:baseline.release,rulesetName:baseline.ruleset};else if(u.includes('/rulesets/'))data={name:baseline.ruleset,source:{files:[{name:'firestore.containment.rules',content:rules}]}};
 else if(u.includes('/databases/'))data={name:'projects/resqme-943ee/databases/(default)',locationId:'nam5',type:'FIRESTORE_NATIVE'};
 else data={projectId:'resqme-943ee',projectNumber:'519076598217',state:'ACTIVE'};return new Response(JSON.stringify(data));},authFactory:()=>({token:async()=> 'SYNTHETIC_TOKEN',info:async()=>({sub:'synthetic-subject',email:'operator@example.test',email_verified:true,expiry_date:now+3600000})})};
 return {a:{...a,manifest:{...a.manifest,operator:{...a.manifest.operator,adcSha256:sha256(adc)}}} as typeof a,deps,calls};
}
export function fakeEvidence(){const files:Record<string,string>={};const facts={platform:'win32',filesystem:'NTFS',fixed:true,canonical:'C:\\private\\evidence',ownerSid:'S-1-5-21-100',safePath:true,outsideGit:true,protected:true,aces:[{sid:'S-1-5-21-100',allow:true,simple:true,rights:'FullControl'}]};const io:EvidenceIO={inspect:async path=>({...facts,canonical:path}),gitRoots:async()=>['C:\\repo'],reserve:async()=>{},write:async(path,data)=>{files[path]=data;},commit:(path,data,signal)=>{if(signal.aborted)throw new Error();files[path]=data;}};return {io,facts,files};}
