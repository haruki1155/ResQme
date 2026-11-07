import assert from 'node:assert/strict';
import test from 'node:test';
import {canonicalManifest,validateApproval,confirmApproval,artifactFiles,baseline, type HostedManifest} from '../tools/g2_inventory/hosted/approval';
import {scopes,limits} from '../tools/g2_inventory/contract';

import {fixture,now,approved} from './hosted_inventory_fixtures';
test('manifest validates exact fixed contract and canonical digest',()=>{
 const m=fixture();assert.equal(validateApproval(m,{hashes:m.artifacts,nodeVersion:process.version},now).digest.length,64);
 assert.equal(canonicalManifest({z:1,a:[2,1]}),'{"a":[2,1],"z":1}');
 for(const value of [undefined,NaN,Infinity,9007199254740992,()=>1, {bad:undefined}])assert.throws(()=>canonicalManifest(value));
});
test('rejects extra/missing fields, bad targets, scopes, budgets, hashes, runtime and policy',()=>{
 const changes=[(m:any)=>m.extra=true,(m:any)=>delete m.operator,(m:any)=>m.target.project='other',(m:any)=>m.target.database='other',(m:any)=>m.g1.ruleset='other',(m:any)=>m.scopes[0].fields.push('fullName'),(m:any)=>m.limits.total=2001,(m:any)=>m.validUntil=new Date(now-1).toISOString(),(m:any)=>m.validFrom='invalid',(m:any)=>m.operator.subject='',(m:any)=>m.evidence.disposalMethod='',(m:any)=>m.evidence.readerSids.push('Everyone'),(m:any)=>m.evidence.unsyncedAttested=false,(m:any)=>delete m.artifacts[artifactFiles[0]],(m:any)=>m.artifacts['extra.js']='a'.repeat(64)];
 for(const change of changes){const m=fixture();change(m);assert.throws(()=>validateApproval(m,{hashes:m.artifacts,nodeVersion:process.version},now));}
 const m=fixture();assert.throws(()=>validateApproval(m,{hashes:{...m.artifacts,[artifactFiles[0]]:'c'.repeat(64)},nodeVersion:process.version},now));assert.throws(()=>validateApproval(m,{hashes:m.artifacts,nodeVersion:'v0'},now));
});
test('approval requires exact TTY confirmation and matching external reference',async()=>{
 const a=approved();let reads=0;
 await confirmApproval(a,{isTTY:true,readLine:async()=>++reads===1?`APPROVE READ-ONLY INVENTORY ${a.digest}`:a.manifest.approvalReference});
 for(const input of [{isTTY:false,readLine:async()=>''},{isTTY:true,readLine:async()=> '--yes'},{isTTY:true,readLine:async()=>null}])await assert.rejects(confirmApproval(a,input));
 await assert.rejects(confirmApproval(a,{isTTY:true,readLine:async(prompt)=>prompt==='confirmation'?`APPROVE READ-ONLY INVENTORY ${a.digest}`:'wrong'}));
});
test('broad Windows principals and mismatched containment bytes cannot be approved',()=>{
 for(const sid of ['S-1-1-0','S-1-5-11','S-1-5-32-545','S-1-5-32-546']){const m=fixture();m.evidence.readerSids.push(sid);assert.throws(()=>validateApproval(m,{hashes:m.artifacts,nodeVersion:process.version},now));}
 const m=fixture();m.artifacts['firestore.containment.rules']='c'.repeat(64);assert.throws(()=>validateApproval(m,{hashes:m.artifacts,nodeVersion:process.version},now));
 assert.throws(()=>canonicalManifest(new Array(2)));
});
