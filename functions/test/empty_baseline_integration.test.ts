import assert from 'node:assert/strict';
import test from 'node:test';
import {initializeApp,deleteApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import {metadataDocuments} from '../tools/empty_baseline/protocol';

test('unsupported REST listing fails closed when emulator returns sentinel fields', {timeout:15000},async()=>{
 assert.equal(process.env.GCLOUD_PROJECT,'demo-resqme');
 assert.equal(process.env.FIRESTORE_EMULATOR_HOST,'127.0.0.1:8080');
 const app=initializeApp({projectId:'demo-resqme'},'baseline-mask-proof');
 const db=getFirestore(app);const root='baselineMaskProof';
 const existing=db.doc(`${root}/existing`),nested=db.doc(`${root}/missing/children/nested`);
 try{
  await existing.set({privateStudentName:'SYNTHETIC_DO_NOT_RETURN'});
  await nested.set({privateMedical:'SYNTHETIC_DO_NOT_RETURN'});
  const u=new URL(`http://127.0.0.1:8080/v1/projects/demo-resqme/databases/(default)/documents/${root}`);
  u.searchParams.set('showMissing','true');u.searchParams.set('pageSize','10');
  u.searchParams.set('mask.fieldPaths','__name__');
  u.searchParams.set('fields','documents(name,createTime,updateTime),nextPageToken');
  const response=await fetch(u,{headers:{Authorization:'Bearer owner'},signal:AbortSignal.timeout(5000)});
  assert.equal(response.status,200);const wire=await response.json() as any;
  assert.equal(JSON.stringify(wire).includes('SYNTHETIC_DO_NOT_RETURN'),true,'pin emulator incompatibility rather than claim metadata proof');
  assert.throws(()=>metadataDocuments(wire,'demo'),{message:'baseline_metadata_rejected'});
  assert.equal(wire.documents.length,2);
  assert.ok(wire.documents.some((d:any)=>d.name.endsWith('/existing')&&d.createTime&&d.updateTime));
  assert.ok(wire.documents.some((d:any)=>d.name.endsWith('/missing')&&!d.createTime&&!d.updateTime)); }finally{await existing.delete();await nested.delete();await db.terminate();await deleteApp(app);}
});

test('positive RPC proof: empty protobuf mask excludes fields for existing and missing parent', {timeout:15000},async()=>{
 assert.equal(process.env.GCLOUD_PROJECT,'demo-resqme');assert.equal(process.env.FIRESTORE_EMULATOR_HOST,'127.0.0.1:8080');
 const {loopbackRpc,MetadataRpcTransport}=await import('../tools/empty_baseline/firestore_rpc.js');
 const app=initializeApp({projectId:'demo-resqme'},'baseline-rpc-proof');const db=getFirestore(app);
 const parent='projects/demo-resqme/databases/(default)/documents';const root='baselineRpcProof';
 const existing=db.doc(`${root}/existing`),nested=db.doc(`${root}/missing/children/nested`);
 const boundary=loopbackRpc(process.env);const rawResponses:any[]=[];const requests:any[]=[];
 const transport=new MetadataRpcTransport(process.env,{close:()=>boundary.close(),invoke:async(method,request,ms,signal)=>{
  requests.push(request);const response=await boundary.invoke(method,request,ms,signal);rawResponses.push(response);console.log(JSON.stringify({rawKeys:Object.keys(response),documentKeys:(response.documents??[]).map((d:any)=>Object.keys(d)),fieldCounts:(response.documents??[]).map((d:any)=>Object.keys(d.fields??{}).length),timestampShapes:(response.documents??[]).map((d:any)=>d.createTime?{keys:Object.keys(d.createTime),secondsType:typeof d.createTime.seconds,nanosType:typeof d.createTime.nanos}:null)}));return response;
 }});
 try{
  await existing.set({privateName:'FORBIDDEN_RPC_SYNTHETIC',privateContact:'FORBIDDEN_RPC_SYNTHETIC'});
  await nested.set({privateMedical:'FORBIDDEN_RPC_SYNTHETIC'});
  const codec=boundary.codec.ListDocuments;
  const omitted=codec.requestDeserialize(codec.requestSerialize({parent,collectionId:root}));
  const present=codec.requestDeserialize(codec.requestSerialize({parent,collectionId:root,mask:{fieldPaths:[]}}));
  assert.equal(Object.hasOwn(omitted,'mask'),false);assert.equal(Object.hasOwn(present,'mask'),true);
  const signal=new AbortController().signal;
  const docs:any[]=[];let token:string|undefined;
  do{const page=await transport.documents(parent,root,1,token,signal);docs.push(...page.documents);token=page.nextPageToken;}while(token);
  assert.equal(docs.length,2);assert.equal(docs.find(d=>d.name.endsWith('/existing')).exists,true);assert.equal(docs.find(d=>d.name.endsWith('/missing')).exists,false);
  const missing=docs.find(d=>!d.exists).name;
  const children=await transport.collections(missing,1,undefined,signal);assert.deepEqual(children.collectionIds,['children']);
  const child=await transport.documents(missing,'children',1,undefined,signal);assert.equal(child.documents[0].exists,true);
  assert.equal(JSON.stringify(rawResponses).includes('FORBIDDEN_RPC_SYNTHETIC'),false);
  for(const response of rawResponses)for(const d of response.documents??[])assert.ok(Object.keys(d).every(k=>['name','createTime','updateTime'].includes(k)),'raw response must exclude business fields');
  for(const request of requests.filter(r=>r.collectionId))assert.deepEqual(request.mask,{fieldPaths:[]});
 }finally{transport.close();await existing.delete();await nested.delete();await db.terminate();await deleteApp(app);}
});
