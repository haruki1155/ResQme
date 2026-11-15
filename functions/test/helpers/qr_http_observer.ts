import type {HttpsFunction} from 'firebase-functions/v2/https';

export type AdmissionMetadata={ipMetadata:'missing'|'invalid'|'usable'|'unavailable';admission:'unknown'};

export function observeQrHttp(original:HttpsFunction,observe:(value:AdmissionMetadata)=>void):HttpsFunction {
  const wrapped=((req:Parameters<HttpsFunction>[0],res:Parameters<HttpsFunction>[1])=>{
    // Read Express' existing IP projection. Never replace req, rawRequest, data,
    // headers, getters, auth, res methods, or SDK handler/limiter internals.
    let ipMetadata:AdmissionMetadata['ipMetadata']='unavailable';
    try {
      const ip:unknown=req.ip;
      ipMetadata=ip===undefined||ip===null?'missing':
        typeof ip==='string'&&ip.length>=3&&ip.length<=128?'usable':'invalid';
    } catch { /* Observation failure must not affect the HTTP handler. */ }
    try { observe({ipMetadata,admission:'unknown'}); } catch { /* Best effort only. */ }
    return original(req,res);
  }) as HttpsFunction;
  // Discovery metadata only. In particular, do not expose/use .run().
  for(const key of ['__endpoint','__trigger'] as const) {
    const descriptor=Object.getOwnPropertyDescriptor(original,key);
    if(descriptor) Object.defineProperty(wrapped,key,descriptor);
  }
  return wrapped;
}
