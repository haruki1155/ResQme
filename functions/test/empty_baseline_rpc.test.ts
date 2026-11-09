import assert from 'node:assert/strict';
import test from 'node:test';
import {MetadataRpcTransport,type RpcBoundary} from '../tools/empty_baseline/firestore_rpc';
const env={GCLOUD_PROJECT:'demo-resqme',FIRESTORE_EMULATOR_HOST:'127.0.0.1:8080'};
const parent='projects/demo-resqme/databases/(default)/documents';
test('explicit mask, pagination and missing parent metadata use injected boundary',async()=>{
 const seen:any[]=[];const rpc:RpcBoundary={invoke:async(method,request)=>{seen.push({method,request});return {documents:[{name:parent+'/proof/missing'}],nextPageToken:'synthetic-next'};},close:()=>{}};
 const transport=new MetadataRpcTransport(env,rpc);
 const page=await transport.documents(parent,'proof',2,undefined,new AbortController().signal);
 assert.equal(page.documents[0].exists,false);assert.equal(page.nextPageToken,'synthetic-next');
 await transport.documents(parent,'proof',2,page.nextPageToken,new AbortController().signal);
 assert.deepEqual(seen[0].request.mask,{fieldPaths:[]});assert.equal(seen[0].request.showMissing,true);assert.equal(seen[0].request.pageSize,2);
 assert.equal(seen[1].request.pageToken,'synthetic-next');assert.equal(seen.length,2);
});
test('unsafe target, fields, caps, ignored cancellation and timeout stop safely',async()=>{
 let calls=0;const rpc:RpcBoundary={invoke:async()=>{calls++;return {documents:[{name:parent+'/proof/doc',fields:{secret:'DO_NOT_LOG'}}]};},close:()=>{}};
 assert.throws(()=>new MetadataRpcTransport({...env,GCLOUD_PROJECT:'resqme-943ee'},rpc));
 assert.throws(()=>new MetadataRpcTransport({...env,FIRESTORE_EMULATOR_HOST:'remote:8080'},rpc));
 const t=new MetadataRpcTransport(env,rpc,{requests:1});
 await assert.rejects(t.documents(parent,'proof',1,undefined,new AbortController().signal),e=>!String(e).includes('DO_NOT_LOG'));
 await assert.rejects(t.documents(parent,'proof',1,undefined,new AbortController().signal));assert.equal(calls,1);
 const noResponse:RpcBoundary={invoke:()=>new Promise(()=>{}),close:()=>{}};
 const timed=new MetadataRpcTransport(env,noResponse,{requestMs:10});
 await assert.rejects(timed.documents(parent,'proof',1,undefined,new AbortController().signal));
 const c=new AbortController();c.abort();const before=calls;
 await assert.rejects(new MetadataRpcTransport(env,rpc).documents(parent,'proof',1,undefined,c.signal));assert.equal(calls,before);
 await assert.rejects(new MetadataRpcTransport(env,rpc).documents(parent,'proof',101,undefined,new AbortController().signal));assert.equal(calls,before);
});
