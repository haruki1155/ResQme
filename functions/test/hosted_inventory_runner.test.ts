import assert from 'node:assert/strict';import test from 'node:test';
import {runHostedInventory,validateManifestLocation,type HostedDependencies} from '../tools/g2_inventory/hosted/runner';
import {fixture,now,fakeSession,fakeEvidence} from './hosted_inventory_fixtures';
import {sha256} from '../tools/g2_inventory/hosted/approval';
function dependencies(){const f=fakeSession(),e=fakeEvidence(),m=fixture();m.operator.adcSha256=sha256(f.deps.adcBytes);const order:string[]=[];let lastToken='';const send=f.deps.send;const d:HostedDependencies={manifest:m,artifacts:{hashes:m.artifacts,nodeVersion:process.version},env:{},now:()=>now,evidence:e.io,confirmation:{isTTY:true,readLine:async prompt=>prompt==='reference'?m.approvalReference:`APPROVE READ-ONLY INVENTORY ${lastToken}`},onValidated:a=>{lastToken=a.digest;},readAdc:async()=>{order.push('adc');return f.deps.adcBytes;},session:{...f.deps,send:async(url,init)=>{order.push('http');if(String(url).includes('/documents:'))return new Response(String(url).endsWith(':listCollectionIds')?'{}':'[]');return send(url,init);}}};return {d,e,order,m};}
test('runner confirms before ADC/HTTP, writes private evidence and never grants G2 clearance',async()=>{const f=dependencies();const result=await runHostedInventory(f.d);assert.equal(result.exitCode,0);assert.equal(result.status,'COMPLETE');assert.ok(f.order.indexOf('adc')<f.order.indexOf('http'));const report=Object.entries(f.e.files).find(([p])=>p.endsWith('sanitized-report.json'))![1];const receipt=JSON.parse(Object.entries(f.e.files).find(([p])=>p.endsWith('run-complete.json'))![1]);assert.equal(JSON.parse(report).publication,'PROVISIONAL');assert.equal(receipt.status,'COMPLETE');assert.equal(receipt.reportSha256,sha256(report));assert.ok(Object.values(f.e.files).some(s=>s.includes('NOT_GRANTED')));});
test('missing/mismatched approval, environment and EOF cause zero credential reads/network',async()=>{
 for(const mutate of [(f:ReturnType<typeof dependencies>)=>f.d.manifest=null,(f:ReturnType<typeof dependencies>)=>f.m.target.project='other',(f:ReturnType<typeof dependencies>)=>f.d.env={FIRESTORE_EMULATOR_HOST:'127.0.0.1:8080'},(f:ReturnType<typeof dependencies>)=>f.d.confirmation.readLine=async()=>null]){const f=dependencies();mutate(f);const result=await runHostedInventory(f.d);assert.equal(result.exitCode,2);assert.equal(f.order.length,0);}
});
test('final G1 change, partial responses, write failure and cancellation fail closed',async()=>{
 const f=dependencies();let releases=0;const send=f.d.session.send;
 f.d.session.send=async(url,init)=>{if(String(url).includes('/releases/')&&++releases===2)return new Response('{}');return send(url,init);};assert.equal((await runHostedInventory(f.d)).status,'INCOMPLETE');
 const g=dependencies();g.e.io.write=async()=>{throw new Error('SECRET')};assert.equal((await runHostedInventory(g.d)).exitCode,2);assert.equal(g.order.length,0);
 const h=dependencies();const abort=new AbortController();abort.abort();h.d.signal=abort.signal;assert.notEqual((await runHostedInventory(h.d)).exitCode,0);assert.equal(h.order.length,0);
});
test('late ignored-signal evidence writes never publish authoritative COMPLETE after timeout',async()=>{
 const f=dependencies();const start=Date.now();f.d.now=Date.now;
 f.m.validFrom=new Date(start-1000).toISOString();f.m.validUntil=new Date(start+3600000).toISOString();f.m.evidence.retentionDeadline=new Date(start+86400000).toISOString();f.m.limits={...f.m.limits,overallMs:100,requestMs:80};
 f.d.session.authFactory=()=>({token:async()=> 'SYNTHETIC_TOKEN',info:async()=>({sub:'synthetic-subject',email:'operator@example.test',email_verified:true,expiry_date:start+3600000})});
 const write=f.e.io.write;f.e.io.write=async(path,data,signal)=>{if(path.includes('sanitized-report'))await new Promise(resolve=>setTimeout(resolve,200));return write(path,data,signal);};
 const result=await runHostedInventory(f.d);assert.notEqual(result.exitCode,0);
 await new Promise(resolve=>setTimeout(resolve,220));
 assert.ok(!Object.keys(f.e.files).some(path=>path.endsWith('run-complete.json')));
 for(const content of Object.values(f.e.files))assert.notEqual(JSON.parse(content).status,'COMPLETE');
});
test('cancellation while confirmation is pending returns promptly with zero ADC or HTTP',async()=>{
 const f=dependencies();f.m.limits={...f.m.limits,overallMs:150};const abort=new AbortController();f.d.signal=abort.signal;f.d.confirmation.readLine=async()=>new Promise(()=>{});
 const running=runHostedInventory(f.d);setTimeout(()=>abort.abort(),5);
 const result=await Promise.race([running,new Promise<never>((_,reject)=>setTimeout(()=>reject(new Error('cancellation did not return promptly')),100))]);assert.notEqual(result.exitCode,0);assert.equal(f.order.length,0);
});
test('private execution manifests must be real local files outside any Git repository',()=>{
 const path='C:\\private\\approval.json';validateManifestLocation(path,{canonical:path,isLink:false,isFile:true,insideGit:false});
 for(const facts of [{canonical:'C:\\other\\approval.json',isLink:false,isFile:true,insideGit:false},{canonical:path,isLink:true,isFile:true,insideGit:false},{canonical:path,isLink:false,isFile:true,insideGit:true},{canonical:path,isLink:false,isFile:false,insideGit:false}])assert.throws(()=>validateManifestLocation(path,facts));
});
