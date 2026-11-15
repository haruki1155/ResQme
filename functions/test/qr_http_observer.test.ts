import assert from 'node:assert/strict';
import {EventEmitter} from 'node:events';
import test from 'node:test';
import {onCall, type HttpsFunction, type Request} from 'firebase-functions/v2/https';
import {allowTier1Resolution,resolveTier1Qr} from '../src/qr/resolve_tier1_qr';
import {observeQrHttp, type AdmissionMetadata} from './helpers/qr_http_observer';

// In-process HTTP-interface fixtures: no socket, listener, emulator or Firebase resource.
function fixture(ip:unknown, body:unknown={data:null}, method='POST') {
  const headers:Record<string,string>={'content-type':'application/json'};
  const req={ip,body,method,headers,header(name:string){return headers[name.toLowerCase()];}} as unknown as Request;
  const events=new EventEmitter();
  const res=Object.assign(events,{
    statusCode:200,body:undefined as unknown,headers:{} as Record<string,unknown>,
    setHeader(name:string,value:unknown){this.headers[name]=value;},
    getHeader(name:string){return this.headers[name];},
    status(code:number){this.statusCode=code;return this;},
    send(value:unknown){this.body=value;events.emit('finish');return this;},
    end(){events.emit('finish');return this;},
  });
  return {req,res:res as unknown as Parameters<HttpsFunction>[1],output:res};
}

test('HTTP observer delegates original identities once and preserves return and endpoint metadata',()=>{
  const f=fixture('offline-private-ip');
  const observations:AdmissionMetadata[]=[];
  let calls=0;
  const returned=Promise.resolve();
  const original=Object.assign((req:unknown,res:unknown)=>{
    calls++;assert.equal(req,f.req);assert.equal(res,f.res);return returned;
  },{__endpoint:{platform:'gcfv2'},__trigger:{fixture:true}}) as HttpsFunction;
  const wrapped=observeQrHttp(original,value=>observations.push(value));
  assert.equal(wrapped(f.req,f.res),returned);
  assert.equal(calls,1);
  assert.equal(wrapped.__endpoint,original.__endpoint);
  assert.deepEqual(wrapped.__trigger,original.__trigger);
  assert.deepEqual(observations,[{ipMetadata:'usable',admission:'unknown'}]);
});

test('SDK HTTP entry performs decoding and retains raw request and auth context',async()=>{
  const f=fixture('fixture-ip',{data:{number:{'@type':'type.googleapis.com/google.protobuf.Int64Value',value:'7'}}});
  let calls=0;
  const original=onCall(request=>{
    calls++;assert.equal(request.rawRequest,f.req);
    assert.deepEqual(request.data,{number:7});
    assert.equal(request.auth,undefined);
    return {active:false};
  });
  await observeQrHttp(original,()=>{})(f.req,f.res);
  assert.equal(calls,1);
  assert.equal(f.output.statusCode,200);
  assert.deepEqual(f.output.body,{result:{active:false}});
});

test('real resolver HTTP path preserves response and single limiter consumption',async()=>{
  const observations:AdmissionMetadata[]=[];
  const wrapped=observeQrHttp(resolveTier1Qr,value=>observations.push(value));
  for(let count=0;count<29;count++) {
    const f=fixture('http-observer-offline-only');
    await wrapped(f.req,f.res);
    assert.deepEqual(f.output.body,{result:{active:false}});
  }
  // Malformed data avoids all database access; usable IP cannot prove admission.
  assert.equal(observations.length,29);
  assert.ok(observations.every(value=>value.ipMetadata==='usable'&&value.admission==='unknown'));
  // One remaining permit proves each HTTP invocation consumed exactly one.
  assert.equal(allowTier1Resolution('http-observer-offline-only'),true);
  assert.equal(allowTier1Resolution('http-observer-offline-only'),false);
});

test('privacy-safe categories do not retain metadata values and observer failure cannot alter delegation',()=>{
  for(const [ip,category] of [[undefined,'missing'],[null,'missing'],['','invalid'],[42,'invalid'],['x'.repeat(129),'invalid'],['abc','usable']] as const) {
    const f=fixture(ip);let calls=0;
    const original=Object.assign(()=>{calls++;},{__endpoint:{}}) as HttpsFunction;
    const observations:AdmissionMetadata[]=[];
    observeQrHttp(original,value=>observations.push(value))(f.req,f.res);
    assert.deepEqual(observations,[{ipMetadata:category,admission:'unknown'}]);
    observeQrHttp(original,()=>{throw new Error('private sink failure');})(f.req,f.res);
    assert.equal(calls,2);
  }
});

test('SDK rejects malformed callable envelopes before the resolver handler',async()=>{
  const f=fixture('fixture-ip',{unexpected:'private-fixture'});
  let calls=0;
  const original=onCall(()=>{calls++;return {active:true};});
  await observeQrHttp(original,()=>{})(f.req,f.res);
  assert.equal(calls,0);
  assert.equal(f.output.statusCode,400);
  assert.deepEqual(f.output.body,{error:{message:'Bad Request',status:'INVALID_ARGUMENT'}});
});

test('SDK CORS preflight response is preserved without invoking the callable handler',async()=>{
  const f=fixture('fixture-ip',undefined,'OPTIONS');
  f.req.headers.origin='https://offline-fixture.invalid';
  f.req.headers['access-control-request-headers']='content-type';
  let calls=0;
  const original=onCall(()=>{calls++;return {active:true};});
  await observeQrHttp(original,()=>{})(f.req,f.res);
  assert.equal(calls,0);
  assert.equal(f.output.statusCode,204);
  assert.equal(f.output.headers['Access-Control-Allow-Origin'],'https://offline-fixture.invalid');
  assert.equal(f.output.headers['Access-Control-Allow-Methods'],'POST');
});

test('metadata getter failure is contained without substituting request properties',()=>{
  const f=fixture(undefined);const observations:AdmissionMetadata[]=[];
  Object.defineProperty(f.req,'ip',{get(){throw new Error('private metadata');}});
  const descriptor=Object.getOwnPropertyDescriptor(f.req,'ip');let calls=0;
  const original=Object.assign((req:unknown)=>{calls++;assert.equal(req,f.req);},{__endpoint:{}}) as HttpsFunction;
  observeQrHttp(original,value=>observations.push(value))(f.req,f.res);
  assert.equal(calls,1);
  assert.deepEqual(Object.getOwnPropertyDescriptor(f.req,'ip'),descriptor);
  assert.deepEqual(observations,[{ipMetadata:'unavailable',admission:'unknown'}]);
});

test('original synchronous errors propagate unchanged',()=>{
  const failure=new Error('private original error');const f=fixture(undefined);let calls=0;
  const original=Object.assign(()=>{calls++;throw failure;},{__endpoint:{}}) as HttpsFunction;
  assert.throws(()=>observeQrHttp(original,()=>{})(f.req,f.res),error=>error===failure);
  assert.equal(calls,1);
});

test('original rejected promise is returned unchanged',async()=>{
  const failure=new Error('private async failure');const f=fixture('fixture-ip');
  const returned=Promise.reject(failure);
  const original=Object.assign(()=>returned,{__endpoint:{}}) as HttpsFunction;
  const result=observeQrHttp(original,()=>{})(f.req,f.res);
  assert.equal(result,returned);
  await assert.rejects(result as Promise<void>,error=>error===failure);
});

test('isolated entry is gated and keeps the production export inventory and metadata',()=>{
  const enabled=process.env.RESQME_QR_HTTP_OBSERVER;
  const project=process.env.GCLOUD_PROJECT;
  try {
    delete process.env.RESQME_QR_HTTP_OBSERVER;
    assert.throws(()=>require('./qr_http_observer_entry'),/explicitly enabled isolated demo profile/);
    process.env.RESQME_QR_HTTP_OBSERVER='1';
    process.env.GCLOUD_PROJECT='resqme-943ee';
    assert.throws(()=>require('./qr_http_observer_entry'),/explicitly enabled isolated demo profile/);
    process.env.GCLOUD_PROJECT='demo-resqme';
    const production=require('../src/index');
    const isolated=require('./qr_http_observer_entry');
    assert.deepEqual(Object.keys(isolated).sort(),Object.keys(production).sort());
    assert.equal(Object.keys(isolated).length,16);
    for(const key of Object.keys(production)) {
      if(key!=='resolveTier1Qr') assert.equal(isolated[key],production[key]);
    }
    assert.notEqual(isolated.resolveTier1Qr,production.resolveTier1Qr);
    assert.equal(isolated.resolveTier1Qr.__endpoint,production.resolveTier1Qr.__endpoint);
    assert.equal('run' in isolated.resolveTier1Qr,false);
  } finally {
    if(enabled===undefined) delete process.env.RESQME_QR_HTTP_OBSERVER;else process.env.RESQME_QR_HTTP_OBSERVER=enabled;
    if(project===undefined) delete process.env.GCLOUD_PROJECT;else process.env.GCLOUD_PROJECT=project;
  }
});
