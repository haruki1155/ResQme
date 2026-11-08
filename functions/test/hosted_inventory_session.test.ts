import assert from 'node:assert/strict';import test from 'node:test';
import {openVerifiedSession,verifyG1,type SessionDependencies} from '../tools/g2_inventory/hosted/session';
import {fakeSession,now} from './hosted_inventory_fixtures';
import {baseline,sha256} from '../tools/g2_inventory/hosted/approval';
test('effective user token identity and G1 verified before queries',async()=>{const f=fakeSession();const s=await openVerifiedSession(f.a,f.deps,new AbortController().signal);await verifyG1(s,f.a,new AbortController().signal);assert.ok(f.calls.length>=4);assert.equal(s.adapterReadOnly,true);assert.equal(s.operatorIamPermissions,'NOT_ASSESSED');});
test('missing/contradictory identity, expiry and wrong ADC fail closed before HTTP',async()=>{
 for(const change of [{sub:undefined},{email:undefined},{email_verified:false},{user_id:'other'},{email:'other@example.test'},{expiry_date:now+30000}]){const f=fakeSession();f.deps.authFactory=()=>({token:async()=> 'SYNTHETIC_TOKEN',info:async()=>({sub:'synthetic-subject',email:'operator@example.test',email_verified:true,expiry_date:now+3600000,...change})});await assert.rejects(openVerifiedSession(f.a,f.deps,new AbortController().signal));assert.equal(f.calls.length,0);}
 for(const type of ['service_account','external_account','impersonated_service_account']){const f=fakeSession();f.deps.adcBytes=Buffer.from(JSON.stringify({type}));await assert.rejects(openVerifiedSession(f.a,f.deps,new AbortController().signal));assert.equal(f.calls.length,0);}
});
test('wrong project, source or API errors reject without corrective calls',async()=>{
 for(const response of [{projectId:'other'},{error:{message:'SECRET'}},null]){const f=fakeSession();f.deps.send=async()=>new Response(JSON.stringify(response));await assert.rejects(openVerifiedSession(f.a,f.deps,new AbortController().signal),e=>!String(e).includes('SECRET'));}
 const f=fakeSession();const s=await openVerifiedSession(f.a,f.deps,new AbortController().signal);f.deps.send=async()=>new Response('{}');await assert.rejects(verifyG1(s,f.a,new AbortController().signal));
});
test('session refuses full-document bodies and oversized pages before network',async()=>{
 const f=fakeSession();const s=await openVerifiedSession(f.a,f.deps,new AbortController().signal);const before=f.calls.length;
 for(const body of [{structuredQuery:{from:[{collectionId:'studentProfiles'}]}},{pageSize:101},{pageSize:1,unknown:true}])await assert.rejects(s.query('structuredQuery' in body?'runQuery':'listCollectionIds',body,new AbortController().signal));
 assert.equal(f.calls.length,before);
});
test('Google user ADC refresh and token-info use only injected POST endpoints and form data',async()=>{
 const f=fakeSession();delete f.deps.authFactory;const send=f.deps.send;const calls:string[]=[];
 f.deps.send=async(url,init)=>{
  const address=String(url);if(address.startsWith('https://oauth2.googleapis.com/')){
   calls.push(address);assert.equal(init?.method,'POST');assert.equal(init?.redirect,'error');assert.match(new Headers(init?.headers).get('Content-Type')??'',/application\/x-www-form-urlencoded/);
   if(address.endsWith('/token')){assert.ok(String(init?.body).includes('refresh_token=synthetic'));return new Response(JSON.stringify({access_token:'SYNTHETIC_TOKEN',expires_in:3600,token_type:'Bearer'}));}
   assert.equal(new Headers(init?.headers).get('Authorization'),'Bearer SYNTHETIC_TOKEN');return new Response(JSON.stringify({sub:'synthetic-subject',email:'operator@example.test',email_verified:'true',expires_in:3600,scope:'openid email'}));
  }return send(url,init);
 };
 await openVerifiedSession(f.a,f.deps,new AbortController().signal);assert.deepEqual(calls,['https://oauth2.googleapis.com/token','https://oauth2.googleapis.com/tokeninfo']);
});
test('empty or conflicting secondary identity claims fail closed',async()=>{
 const f=fakeSession();f.deps.authFactory=()=>({token:async()=> 'SYNTHETIC_TOKEN',info:async()=>({sub:'synthetic-subject',user_id:'',email:'operator@example.test',email_verified:true,expiry_date:now+3600000})});await assert.rejects(openVerifiedSession(f.a,f.deps,new AbortController().signal));assert.equal(f.calls.length,0);
});

test('verified-email accepts only explicit boolean or string true and rejects conflicts before metadata',async()=>{
 const cases: Array<{claims:Record<string,unknown>;allowed:boolean}>=[
  {claims:{email_verified:true},allowed:true},{claims:{email_verified:'true'},allowed:true},
  ...[false,'false',undefined,null,1,'TRUE',' true ',{},[]].map(value=>({claims:{email_verified:value},allowed:false})),
  {claims:{email_verified:true,verified_email:false},allowed:false},
  {claims:{email_verified:'true',verified_email:'false'},allowed:false},
  {claims:{email_verified:undefined,verified_email:true},allowed:false},
  {claims:{email_verified:true,verified_email:'true'},allowed:true},
  {claims:{email_verified:true,verified_email:1},allowed:false}
 ];
 for(const {claims,allowed} of cases){
  const f=fakeSession();f.deps.authFactory=()=>({token:async()=> 'SYNTHETIC_TOKEN',info:async()=>({sub:'synthetic-subject',email:'operator@example.test',expiry_date:now+3600000,...claims})});
  if(allowed){await openVerifiedSession(f.a,f.deps,new AbortController().signal);assert.ok(f.calls.length>=4);}
  else{await assert.rejects(openVerifiedSession(f.a,f.deps,new AbortController().signal));assert.equal(f.calls.length,0);}
 }
});
