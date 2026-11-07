import assert from 'node:assert/strict';
import test from 'node:test';
import {documentPrefixFor,validName,scopes} from '../tools/g2_inventory/contract';
import {queryBody,decodeQuery} from '../tools/g2_inventory/query_codec';
import {HostedFirestoreTransport} from '../tools/g2_inventory/hosted/transport';
import {runInventory} from '../tools/g2_inventory/inventory';
test('closed namespaces reject arbitrary targets and foreign references',()=>{
 assert.throws(()=>documentPrefixFor('other' as any));
 const path=documentPrefixFor('staging')+'studentProfiles/synthetic';assert.equal(validName('profiles',path,'staging'),'synthetic');assert.throws(()=>validName('profiles',path));
 assert.throws(()=>decodeQuery('profiles',[{document:{name:path.replace('(default)','other')}}],100,'staging'));
});
test('hosted uses identical projections and read operations only',async()=>{
 const calls:any[]=[];const transport=new HostedFirestoreTransport({query:async(method,body)=>{calls.push({method,body});return [] as any;}});
 for(const scope of scopes)await transport.query(scope.id,undefined,100,new AbortController().signal);
 for(let i=0;i<scopes.length;i++){assert.deepEqual(calls[i].body,queryBody(scopes[i].id,undefined,100,'demo'));assert.equal(calls[i].method,'runQuery');}
 assert.throws(()=>queryBody('profiles',undefined,101,'staging'));
 for(const data of [[{error:{message:'PRIVATE'}}],[{}]])assert.throws(()=>decodeQuery('profiles',data,100,'staging'));
});
test('engine reuses staging namespace and never clears historical records',async()=>{
 let sent=false;const transport=new HostedFirestoreTransport({query:async(method)=>method==='listCollectionIds'?{collectionIds:[]}:sent?[]:(sent=true,[{document:{name:documentPrefixFor('staging')+'studentProfiles/private',fields:{schemaVersion:{integerValue:'1'},status:{stringValue:'pending_review'}}}}])});
 const result=await runInventory(transport,{namespace:'staging'});assert.equal(result.report.status,'COMPLETE');assert.equal(result.report.unresolved,1);assert.equal(result.report.g2Complete,false);assert.ok(!JSON.stringify(result.report).includes('/private'));
});
