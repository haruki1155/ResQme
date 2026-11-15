import assert from 'node:assert/strict';
import test from 'node:test';
import type {CallableRequest} from 'firebase-functions/v2/https';
import {resolveTier1Qr} from '../src/qr/resolve_tier1_qr';
import {observeQrAdmission} from './helpers/qr_admission_diagnostic';

function request(ip:unknown):CallableRequest<unknown> {
  return {data:null,rawRequest:{ip}} as CallableRequest<unknown>;
}

test('diagnostic observes missing metadata before admission without retaining request values',async()=>{
  const result=await observeQrAdmission(request(undefined),resolveTier1Qr.run);
  assert.deepEqual(result,{admission:'missing_ip_metadata',outcome:'not_admitted'});
});

test('diagnostic observes real admission, downstream rejection, and exhausted rate window',async()=>{
  // Malformed data stops before project/Firestore access. The real limiter runs exactly once per call.
  const input=request('offline-diagnostic-fixture');
  for(let count=0;count<30;count++) {
    assert.deepEqual(await observeQrAdmission(input,resolveTier1Qr.run),{
      admission:'admitted',outcome:'rejected_after_admission',
    });
  }
  assert.deepEqual(await observeQrAdmission(input,resolveTier1Qr.run),{
    admission:'rate_limit_rejection',outcome:'not_admitted',
  });
});

test('diagnostic positive-result classification is observer-only evidence',async()=>{
  const result=await observeQrAdmission(request('offline-positive-fixture'),async observed=>{
    void observed.rawRequest.ip;
    void observed.data;
    return {active:true};
  });
  assert.deepEqual(result,{admission:'admitted',outcome:'active'});
  assert.deepEqual(Object.keys(result).sort(),['admission','outcome']);
});

test('diagnostic propagates handler exceptions without serializing private errors',async()=>{
  const failure=new Error('fixture-only failure');
  await assert.rejects(()=>observeQrAdmission(request(undefined),async()=>{throw failure;}),error=>error===failure);
});

test('diagnostic keeps malformed IP metadata separate from missing metadata',async()=>{
  for(const value of ['',42,'x'.repeat(129)]) {
    assert.deepEqual(await observeQrAdmission(request(value),resolveTier1Qr.run),{
      admission:'invalid_ip_metadata',outcome:'not_admitted',
    });
  }
});

test('diagnostic refuses unexpected response fields and unobserved boundaries',async()=>{
  await assert.rejects(()=>observeQrAdmission(request(undefined),async()=>({active:false})),
    {message:'Diagnostic boundary not observed.'});
  await assert.rejects(()=>observeQrAdmission(request(undefined),async observed=>{
    void observed.rawRequest.ip;
    return {active:false,unexpected:'fixture'};
  }),{message:'Unexpected diagnostic response shape.'});
});
