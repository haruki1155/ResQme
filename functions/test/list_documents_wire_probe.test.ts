/** Independent synthetic wire diagnostic; imports no ResQMe verifier/auth modules. */
import assert from 'node:assert/strict';
import test from 'node:test';
import {readFileSync} from 'node:fs';
import {dirname,resolve} from 'node:path';
import * as grpc from '@grpc/grpc-js';
import {fromJSON} from '@grpc/proto-loader';
import {initializeApp,deleteApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';

test('independent raw-buffer ListDocuments emulator diagnostic', {timeout:15000},async()=>{
 assert.equal(process.env.GCLOUD_PROJECT,'demo-resqme');assert.equal(process.env.FIRESTORE_EMULATOR_HOST,'127.0.0.1:8080');
 const descriptor=JSON.parse(readFileSync(resolve(dirname(require.resolve('@google-cloud/firestore')),'../protos/v1.json'),'utf8'));
 const defs=fromJSON(descriptor,{longs:String,defaults:false});const pkg=grpc.loadPackageDefinition(defs) as any;
 const codec=pkg.google.firestore.v1.Firestore.service.ListDocuments;
 const client=new grpc.Client('127.0.0.1:8080',grpc.credentials.createInsecure(),{'grpc.enable_retries':0,'grpc.max_receive_message_length':1048576});
 const app=initializeApp({projectId:'demo-resqme'},'independent-wire-probe');const db=getFirestore(app);
 const base='projects/demo-resqme/databases/(default)/documents';const collectionId='independentWireProbe';
 const a=db.doc(`${collectionId}/existing`),b=db.doc(`${collectionId}/missing/sub/nested`);
 const sentinel='INDEPENDENT_SYNTHETIC_FORBIDDEN_BYTES';
 const invoke=(request:any)=>new Promise<Buffer>((resolveCall,rejectCall)=>{
  const md=new grpc.Metadata();md.set('authorization','Bearer owner');
  client.makeUnaryRequest('/google.firestore.v1.Firestore/ListDocuments',codec.requestSerialize,(raw:Buffer)=>raw,request,md,{deadline:Date.now()+4000},(error,raw)=>{if(error)rejectCall(Error('local_probe_rpc_failed'));else resolveCall(raw as Buffer);});
 });
 try{
  await a.set({privateSentinel:sentinel,syntheticPublic:'synthetic-only'});await b.set({privateSentinel:sentinel});
  const variants=[{label:'omitted',extra:{}},{label:'present-empty',extra:{mask:{fieldPaths:[]}}},{label:'nonempty-control',extra:{mask:{fieldPaths:['syntheticPublic']}}},{label:'existing-only-empty',extra:{showMissing:false,mask:{fieldPaths:[]}}}];
  for(const variant of variants){
   const request={parent:base,collectionId,showMissing:true,pageSize:100,...variant.extra};
   const encoded=codec.requestSerialize(request);const roundtrip=codec.requestDeserialize(encoded);
   assert.equal(Object.hasOwn(roundtrip,'mask'),variant.label!=='omitted');
   if(['present-empty','existing-only-empty'].includes(variant.label))assert.equal(Object.keys(roundtrip.mask).length,0);
   const raw=await invoke(request);const decoded=codec.responseDeserialize(raw);
   const hasSentinelInRaw=raw.includes(Buffer.from(sentinel));
   // Pin observed emulator limitation; this is NOT a metadata-only acceptance test.
   assert.equal(hasSentinelInRaw,variant.label!=='existing-only-empty');
   assert.equal(decoded.documents.length,variant.label==='existing-only-empty'?1:2);
   assert.ok(decoded.documents.some((d:any)=>d.name.endsWith('/existing')&&d.createTime&&d.updateTime));
   if(variant.label!=='existing-only-empty')assert.ok(decoded.documents.some((d:any)=>d.name.endsWith('/missing')&&!d.createTime&&!d.updateTime));
   console.log(JSON.stringify({variant:variant.label,maskPresent:Object.hasOwn(roundtrip,'mask'),privateBytesInRaw:hasSentinelInRaw,documentCount:decoded.documents.length,fieldCounts:decoded.documents.map((d:any)=>Object.keys(d.fields??{}).length)}));
  }
 }finally{client.close();await a.delete();await b.delete();await db.terminate();await deleteApp(app);}
});
