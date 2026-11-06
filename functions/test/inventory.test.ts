import assert from 'node:assert/strict';
import test from 'node:test';
import {spawnSync} from 'node:child_process';
import {resolve} from 'node:path';
import {localConfig, scopes, limits} from '../tools/g2_inventory/contract';
import {LocalFirestoreTransport} from '../tools/g2_inventory/transport';
import {runInventory, classifyEvidence} from '../tools/g2_inventory/inventory';
import {documentPrefix, InventoryError, type ReadTransport, type ScopeId, type ProjectedDocument} from '../tools/g2_inventory/contract';

const env = {GCLOUD_PROJECT: 'demo-resqme', FIRESTORE_EMULATOR_HOST: '127.0.0.1:8080'};
const controller = () => new AbortController().signal;

test('inventory local config rejects missing, hosted, conflicting and unsafe targets', () => {
  assert.equal(localConfig(env).origin, 'http://127.0.0.1:8080');
  assert.equal(localConfig({...env, FIRESTORE_EMULATOR_HOST: 'localhost:8080'}).origin, 'http://127.0.0.1:8080');
  for (const change of [{GCLOUD_PROJECT: undefined}, {GCLOUD_PROJECT: 'resqme-943ee'}, {GOOGLE_CLOUD_PROJECT: 'other'}, {FIRESTORE_EMULATOR_HOST: undefined}, {FIRESTORE_EMULATOR_HOST: 'example.com:8080'}, {FIRESTORE_EMULATOR_HOST: '127.0.0.1:8180'}, {FIRESTORE_EMULATOR_HOST: '0.0.0.0:8080'}, {FIREBASE_CONFIG: '{"projectId":"resqme-943ee"}'}]) {
    assert.throws(() => localConfig({...env, ...change}));
  }
  assert.deepEqual(limits, {pageSize:100, perQuery:500, total:2000, collections:100, requestMs:30000, overallMs:600000});
});

test('actual requests contain exact projections/cursors and only the fixed emulator owner marker', async () => {
  const requests: {url:string; body:any; init:RequestInit}[] = [];
  const transport = new LocalFirestoreTransport(env, async (url, init) => {
    requests.push({url:String(url), body:JSON.parse(String(init?.body)), init:init!});
    return new Response('[]');
  });
  for (const scope of scopes) await transport.query(scope.id, undefined, 100, controller());
  for (const [index, request] of requests.entries()) {
    assert.equal(request.url, 'http://127.0.0.1:8080/v1/projects/demo-resqme/databases/(default)/documents:runQuery');
    assert.deepEqual(request.body.structuredQuery.select.fields, (scopes[index].fields.length ? scopes[index].fields : ['__name__']).map(fieldPath => ({fieldPath})));
    assert.deepEqual(request.body.structuredQuery.orderBy, [{field:{fieldPath:'__name__'},direction:'ASCENDING'}]);
    assert.equal(request.body.structuredQuery.limit,100);
    assert.equal(request.init.redirect,'error');
    assert.equal(new Headers(request.init.headers).get('Authorization'),'Bearer owner');
  }
  const cursor='projects/demo-resqme/databases/(default)/documents/studentProfiles/synthetic-cursor';
  await transport.query('profiles',cursor,3,controller());
  assert.deepEqual(requests.at(-1)!.body.structuredQuery.startAt,{values:[{referenceValue:cursor}],before:false});
  assert.deepEqual(requests.filter(r=>r.body.structuredQuery.from[0].allDescendants).map(r=>r.body.structuredQuery.from[0].collectionId),['acknowledgments','requests']);
});

test('transport refuses arbitrary scopes, oversized pages and server projection violations', async () => {
  let calls=0;
  const transport=new LocalFirestoreTransport(env,async()=>{calls++;return new Response(JSON.stringify([{document:{name:'projects/demo-resqme/databases/(default)/documents/studentProfiles/synthetic',fields:{fullName:{stringValue:'FORBIDDEN_SENTINEL'}}}}]));});
  await assert.rejects(transport.query('profiles',undefined,100,controller()), /projection_violation/);
  await assert.rejects(transport.query('arbitrary' as any,undefined,100,controller()));
  await assert.rejects(transport.query('profiles',undefined,101,controller()));
  assert.equal(calls,1);
  const referenceOnly=new LocalFirestoreTransport(env,async()=>new Response(JSON.stringify([{document:{name:'projects/demo-resqme/databases/(default)/documents/studentProfiles/synthetic/acknowledgments/notice',fields:{email:{stringValue:'FORBIDDEN_SENTINEL'}}}}])));
  await assert.rejects(referenceOnly.query('acknowledgments',undefined,10,controller()),/projection_violation/);
});

test('root collection discovery is paginated and does not issue document queries',async()=>{
  const calls:any[]=[];
  const transport=new LocalFirestoreTransport(env,async(url,init)=>{calls.push({url,body:JSON.parse(String(init?.body))});return new Response(JSON.stringify({collectionIds:['unknownSynthetic'],nextPageToken:'opaque-local-token'}));});
  assert.deepEqual(await transport.collections('prior-token',12,controller()),{ids:['unknownSynthetic'],next:'opaque-local-token'});
  assert.match(calls[0].url,/:listCollectionIds$/);
  assert.deepEqual(calls[0].body,{pageSize:12,pageToken:'prior-token'});
});

test('transport errors, oversized bodies and redirects never leak their contents',async()=>{
  for (const response of [new Response('SECRET_SERVER_CONTENT',{status:403}),new Response('x'.repeat(1048577)),new Response('SECRET_REDIRECT',{status:302,headers:{Location:'https://example.com'}})]) {
    const transport=new LocalFirestoreTransport(env,async()=>response);
    await assert.rejects(transport.query('profiles',undefined,1,controller()), error=>!String(error).includes('SECRET') && /permission_denied|request_failed|response_too_large/.test(String(error)));
  }
});

function row(path:string,fields:Record<string,any>={}):ProjectedDocument {return {name:documentPrefix+path,fields};}
class FakeReads implements ReadTransport {
  calls:{scope:ScopeId;after?:string;size:number}[]=[];
  ids=['studentProfiles'];
  rows:Partial<Record<ScopeId,ProjectedDocument[]>>={};
  async collections(_token:string|undefined,size:number,_signal:AbortSignal) {return {ids:this.ids.slice(0,size)};}
  async query(scope:ScopeId,after:string|undefined,size:number,_signal:AbortSignal) {
    this.calls.push({scope,after,size});
    return (this.rows[scope]??[]).filter(r=>!after||Buffer.compare(Buffer.from(r.name),Buffer.from(after))>0).slice(0,size);
  }
}
test('empty complete inventory is not G2 closure or clearance',async()=>{
  const fake=new FakeReads();fake.ids=[];
  const result=await runInventory(fake);
  assert.equal(result.report.status,'COMPLETE');assert.equal(result.report.examined,0);
  assert.equal(result.report.g2Complete,false);assert.equal(result.report.clearance,'NOT_GRANTED');
  assert.equal(fake.calls.length,6);
});
test('pagination is ordered, bounded and never treats a cap as clean',async()=>{
  const fake=new FakeReads();fake.rows.profiles=Array.from({length:5},(_,i)=>row(`studentProfiles/private-uid-${i}`,{schemaVersion:{integerValue:'1'},status:{stringValue:'pending_review'}}));
  const result=await runInventory(fake,{limits:{pageSize:2}});
  assert.equal(result.report.examined,5);assert.equal(result.report.status,'COMPLETE');
  assert.deepEqual(fake.calls.filter(c=>c.scope==='profiles').map(c=>c.size),[2,2,2]);
  for(const reduced of [{perQuery:3},{total:3}]){
    const capped=await runInventory(fake,{limits:{pageSize:2,...reduced}});
    assert.equal(capped.report.examined,3);assert.equal(capped.report.status,'INCOMPLETE');assert.equal(capped.report.clearance,'NOT_GRANTED');
  }
  fake.ids=['one','two'];
  assert.equal((await runInventory(fake,{limits:{collections:2}})).report.status,'INCOMPLETE');
});
test('classification requires independent evidence for creation and subsequent changes',()=>{
  assert.equal(classifyEvidence(), 'UNRESOLVED');
  assert.equal(classifyEvidence({source:'independent-review',authorizedCreation:true,changesCovered:false,unauthorizedChange:false,conflicting:false,reference:'review-1'}),'UNRESOLVED');
  assert.equal(classifyEvidence({source:'independent-review',authorizedCreation:true,changesCovered:true,unauthorizedChange:false,conflicting:false,reference:'review-1'}),'TRUSTED');
  assert.equal(classifyEvidence({source:'independent-review',authorizedCreation:false,changesCovered:true,unauthorizedChange:true,conflicting:false,reference:'review-2'}),'UNTRUSTED');
  assert.equal(classifyEvidence({source:'independent-review',authorizedCreation:true,changesCovered:true,unauthorizedChange:true,conflicting:true,reference:'review-3'}),'UNRESOLVED');
  assert.equal(classifyEvidence({source:'document' as any,authorizedCreation:true,changesCovered:true,unauthorizedChange:false,conflicting:false,reference:'forged'}),'UNRESOLVED');
});
test('reports redact identifiers, flag orphan QA/QR and default all authority to unresolved',async()=>{
  const fake=new FakeReads();fake.ids=['unknown-private-root'];fake.rows.qa=[row('qaTesters/PRIVATE_UID',{enabled:{booleanValue:true},syntheticOnly:{booleanValue:true}})];fake.rows.qr=[row('studentQrCredentials/PRIVATE_UID',{verificationStatus:{stringValue:'unverified'}})];
  const result=await runInventory(fake);
  const json=JSON.stringify(result.report);
  for(const privateText of ['PRIVATE_UID','unknown-private-root','qaTesters/'])assert.ok(!json.includes(privateText));
  assert.equal(result.report.unresolved,2);assert.equal(result.report.unknownRootCollections,1);
  assert.ok(result.report.records.every(r=>r.classification==='UNRESOLVED'));
  assert.ok(result.report.consistency.some(r=>r.issue==='missing_profile'));
  assert.equal(result.privateEvidence.aliases['PRIVATE_UID'],'account-001');
});
test('malformed/oversized fields and forged status halt safely with values suppressed',async()=>{
  for(const fields of [{status:{stringValue:'SECRET_MEDICAL_TEXT'}},{status:{stringValue:'x'.repeat(10000)}},{status:{mapValue:{fields:{secret:'SECRET'}}}},{enabled:{stringValue:'SECRET'}}]){
    const fake=new FakeReads();const scope='enabled' in fields?'qa':'profiles';fake.rows[scope]=[row(`${scope==='qa'?'qaTesters':'studentProfiles'}/PRIVATE_UID`,fields)];
    const result=await runInventory(fake);assert.equal(result.report.status,'INCOMPLETE');assert.equal(result.report.unexpectedRecords,1);
    assert.ok(!JSON.stringify(result).includes('SECRET'));assert.equal(result.privateEvidence.records.length,0);
  }
});
test('unexpected group paths and pagination violations fail closed',async()=>{
  const fake=new FakeReads();fake.rows.acknowledgments=[row('unknown/PRIVATE_UID/acknowledgments/notice')];
  assert.equal((await runInventory(fake)).report.status,'INCOMPLETE');
  fake.rows={profiles:[row('studentProfiles/b'),row('studentProfiles/a')]};
  const result=await runInventory(fake);assert.equal(result.report.status,'INCOMPLETE');assert.ok(result.report.reasons.includes('pagination_error'));
});
test('request timeout, global deadline, cancellation and permission failure never clear inventory',async()=>{
  const hang=new FakeReads();hang.collections=async()=>new Promise(()=>{});
  const timed=await runInventory(hang,{limits:{requestMs:10}});assert.equal(timed.report.status,'FAILED');assert.ok(timed.report.reasons.includes('request_timeout'));
  const cancelled=new AbortController();cancelled.abort();
  assert.equal((await runInventory(new FakeReads(),{signal:cancelled.signal})).report.status,'FAILED');
  const partial=new FakeReads();partial.rows.profiles=[row('studentProfiles/private')];partial.query=async(scope)=>{if(scope==='profiles')return partial.rows.profiles!;throw new InventoryError('permission_denied');};
  const result=await runInventory(partial);assert.equal(result.report.status,'INCOMPLETE');assert.equal(result.report.examined,1);
  const deadline=new FakeReads();let now=0;deadline.collections=async()=>{now=20;return {ids:[]};};
  assert.ok((await runInventory(deadline,{now:()=>now,limits:{overallMs:10}})).report.reasons.includes('overall_deadline'));
});

test('CLI rejects hosted, missing and unsafe configuration and hosted flags before I/O',()=>{
  const executable=resolve(__dirname,'../tools/g2_inventory/runner.js');
  for(const [args,change] of [[[],{GCLOUD_PROJECT:'resqme-943ee'}],[[],{GCLOUD_PROJECT:''}],[[],{FIRESTORE_EMULATOR_HOST:'example.com:8080'}],[['--hosted'],{}]] as [string[],NodeJS.ProcessEnv][]){
    const run=spawnSync(process.execPath,[executable,...args],{env:{...process.env,...env,...change},encoding:'utf8',timeout:3000});
    assert.equal(run.status,2);assert.ok(!run.stdout);assert.match(run.stderr,/inventory_local_configuration_rejected/);assert.ok(!run.stderr.includes('example.com'));
  }
});

test('root pagination detects repeated tokens/IDs and never scans discovered unknown collections',async()=>{
  const fake=new FakeReads();let page=0;
  fake.collections=async(token,size)=>{assert.equal(size,token?99:100);page++;return token?{ids:['unknown-private'],next:undefined}:{ids:['studentProfiles'],next:'page-two'};};
  const result=await runInventory(fake);assert.equal(result.report.status,'COMPLETE');assert.equal(page,2);
  assert.ok(fake.calls.every(c=>scopes.some(s=>s.id===c.scope)));
  fake.collections=async()=>({ids:['studentProfiles'],next:'repeat'});
  const duplicate=await runInventory(fake);assert.equal(duplicate.report.status,'INCOMPLETE');assert.ok(duplicate.report.reasons.includes('pagination_error'));
});
test('actual in-flight cancellation aborts transport and module import has no I/O',async()=>{
  const fake=new FakeReads();const abort=new AbortController();let aborted=false;
  fake.collections=async(_token,_size,signal)=>new Promise((_resolve,reject)=>{signal.addEventListener('abort',()=>{aborted=true;reject(new Error('PRIVATE_ERROR'));},{once:true});setImmediate(()=>abort.abort());});
  const result=await runInventory(fake,{signal:abort.signal});assert.equal(result.report.status,'FAILED');assert.ok(aborted);assert.ok(!JSON.stringify(result).includes('PRIVATE_ERROR'));
  const original=global.fetch;let calls=0;
  try {global.fetch=async()=>{calls++;throw new Error('Import must not fetch');};require('../tools/g2_inventory/runner');assert.equal(calls,0);}finally{global.fetch=original;}
});

test('HTTP-200 streamed errors and malformed collection responses cannot masquerade as empty',async()=>{
  for(const response of [[{error:{code:7,message:'PRIVATE_ERROR'}}],[{}],[{unexpected:'PRIVATE_ERROR'}]]){
    const transport=new LocalFirestoreTransport(env,async()=>new Response(JSON.stringify(response)));
    await assert.rejects(transport.query('profiles',undefined,100,controller()),/invalid_query_page/);
  }
  const transport=new LocalFirestoreTransport(env,async()=>new Response('null'));
  await assert.rejects(transport.collections(undefined,100,controller()),/invalid_collection_page/);
});

test('collection discovery HTTP-200 errors never produce a complete empty inventory',async()=>{
  for(const response of [{error:{code:7,message:'PRIVATE_DISCOVERY_ERROR'}},{unexpected:'PRIVATE_DISCOVERY_ERROR'}]){
    const transport=new LocalFirestoreTransport(env,async url=>new Response(JSON.stringify(String(url).endsWith(':listCollectionIds')?response:[])));
    const result=await runInventory(transport);
    assert.equal(result.report.status,'FAILED');assert.ok(result.report.reasons.includes('invalid_collection_page'));
    assert.ok(!JSON.stringify(result).includes('PRIVATE_DISCOVERY_ERROR'));
  }
  const empty=new LocalFirestoreTransport(env,async url=>new Response(String(url).endsWith(':listCollectionIds')?'{}':'[]'));
  assert.equal((await runInventory(empty)).report.status,'COMPLETE');
});
