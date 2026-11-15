import type {CallableRequest} from 'firebase-functions/v2/https';

// Test-only observer: never exported by the application entry point.
// This depends on the current resolver reading data immediately after its IP admission check.
// Preserve getters/values and run the supplied handler once; do not call the limiter separately.
export async function observeQrAdmission(
  request:CallableRequest<unknown>,
  run:(request:CallableRequest<unknown>)=>unknown|Promise<unknown>,
):Promise<{
  admission:'missing_ip_metadata'|'invalid_ip_metadata'|'rate_limit_rejection'|'admitted';
  outcome:'not_admitted'|'rejected_after_admission'|'active';
}> {
  let ipObserved=false;
  const state:{metadata:'missing_ip_metadata'|'invalid_ip_metadata'|'usable'}={metadata:'missing_ip_metadata'};
  let dataObserved=false;
  const rawRequest=new Proxy(request.rawRequest,{
    get(target,key) {
      const value=Reflect.get(target,key,target);
      if(key==='ip') {
        ipObserved=true;
        state.metadata=value===undefined||value===null?'missing_ip_metadata':
          typeof value==='string'&&value.length>=3&&value.length<=128?'usable':'invalid_ip_metadata';
      }
      return value;
    },
  });
  const observed=new Proxy(request,{
    get(target,key) {
      if(key==='rawRequest') return rawRequest;
      if(key==='data') dataObserved=true;
      return Reflect.get(target,key,target);
    },
  });
  const result=await run(observed);
  if(!ipObserved) throw new Error('Diagnostic boundary not observed.');
  if(!result||typeof result!=='object'||Object.keys(result).length!==1||
    !('active' in result)||typeof result.active!=='boolean') {
    throw new Error('Unexpected diagnostic response shape.');
  }
  if(dataObserved) return {admission:'admitted',outcome:result.active?'active':'rejected_after_admission'};
  if(result.active) throw new Error('Diagnostic admission ordering changed.');
  return {admission:state.metadata==='usable'?'rate_limit_rejection':state.metadata,outcome:'not_admitted'};
}
