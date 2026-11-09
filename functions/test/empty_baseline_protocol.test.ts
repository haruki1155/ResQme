import assert from 'node:assert/strict';
import test from 'node:test';
import {authAccountsUrl,discoveryUrl,metadataDocuments} from '../tools/empty_baseline/protocol';
test('tenant users use their own path and never a default-population query',()=>{
 const u=new URL(authAccountsUrl('synthetic-tenant'));
 assert.equal(u.pathname,'/v1/projects/resqme-943ee/tenants/synthetic-tenant/accounts:batchGet');
 assert.equal(u.searchParams.has('tenantId'),false);
 assert.equal(new URL(authAccountsUrl()).pathname,'/v1/projects/resqme-943ee/accounts:batchGet');
 assert.throws(()=>authAccountsUrl('../other'));
});
test('discovery pages are bounded by remaining shared capacity',()=>{
 assert.equal(new URL(discoveryUrl('tenants',19)).searchParams.get('pageSize'),'1');
 assert.equal(new URL(discoveryUrl('activeBuckets',12)).searchParams.get('maxResults'),'8');
 assert.equal(new URL(discoveryUrl('deletedBuckets',19)).searchParams.get('maxResults'),'1');
 for(const n of [20,21,-1,1.5,NaN])assert.throws(()=>discoveryUrl('deletedBuckets',n));
});
test('metadata decoder rejects student fields and foreign references',()=>{
 const name='projects/resqme-943ee/databases/(default)/documents/test/doc';
 assert.throws(()=>metadataDocuments({documents:[{name,fields:{secret:{stringValue:'SYNTHETIC'}}}]},'staging'));
 assert.throws(()=>metadataDocuments({documents:[{name:name.replace('resqme-943ee','other')}]},'staging'));
 assert.throws(()=>metadataDocuments({documents:[{name,createTime:'invalid'}]},'staging'));
 assert.throws(()=>metadataDocuments({error:{}},'staging'));
 assert.throws(()=>metadataDocuments({documents:null},'staging'));
 const docs=metadataDocuments({documents:[{name},{name:name+'2',createTime:'2026-11-08T00:00:00Z',updateTime:'2026-11-08T00:00:00Z'}]},'staging');
 assert.equal(docs[0].exists,false);assert.equal(docs[1].exists,true);
});
