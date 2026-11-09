/** Pure protocol guards only. No credentials, transport or runnable hosted entry point. */
const project='resqme-943ee';
function segment(value:string){if(!/^[A-Za-z0-9_-]{1,256}$/.test(value))throw Error('baseline_path_rejected');return encodeURIComponent(value);}
export function authAccountsUrl(tenant?:string){
 const path=tenant===undefined?'':`/tenants/${segment(tenant)}`;
 const url=new URL(`https://identitytoolkit.googleapis.com/v1/projects/${project}${path}/accounts:batchGet`);
 url.searchParams.set('maxResults','1');url.searchParams.set('fields','users(localId),nextPageToken');return url.toString();
}
/** Caller must pass combined active+deleted bucket count; no independent per-population allowance. */
export function discoveryUrl(kind:'tenants'|'activeBuckets'|'deletedBuckets',alreadyDiscovered:number){
 if(!Number.isInteger(alreadyDiscovered)||alreadyDiscovered<0||alreadyDiscovered>=20)throw Error('baseline_capacity_reached');
 const remaining=20-alreadyDiscovered;
 const url=new URL(kind==='tenants'?`https://identitytoolkit.googleapis.com/v2/projects/${project}/tenants`:'https://storage.googleapis.com/storage/v1/b');
 url.searchParams.set(kind==='tenants'?'pageSize':'maxResults',String(remaining));
 url.searchParams.set('fields',kind==='tenants'?'tenants(name),nextPageToken':'items(name,projectNumber,softDeletePolicy),nextPageToken,unreachable');
 if(kind!=='tenants'){url.searchParams.set('project',project);url.searchParams.set('projection','noAcl');}
 if(kind==='deletedBuckets')url.searchParams.set('softDeleted','true');
 return url.toString();
}
function record(value:unknown,keys:string[]):asserts value is Record<string,any>{
 if(!value||typeof value!=='object'||Array.isArray(value)||Object.keys(value).some(k=>!keys.includes(k)))throw Error('baseline_metadata_rejected');
}
export function metadataDocuments(value:unknown,namespace:'staging'|'demo'){
 record(value,['documents','nextPageToken']);
 if(value.nextPageToken!==undefined&&(typeof value.nextPageToken!=='string'||!value.nextPageToken||value.nextPageToken.length>8192))throw Error('baseline_metadata_rejected');
 const docs=Object.hasOwn(value,'documents')?value.documents:[];if(!Array.isArray(docs)||docs.length>100)throw Error('baseline_metadata_rejected');
 const prefix=`projects/${namespace==='staging'?project:'demo-resqme'}/databases/(default)/documents/`;
 const seen=new Set<string>();
 return docs.map(d=>{
  record(d,['name','createTime','updateTime']);
  if(typeof d.name!=='string'||!d.name.startsWith(prefix))throw Error('baseline_metadata_rejected');
  const parts=d.name.slice(prefix.length).split('/');
  if(parts.length<2||parts.length%2||parts.some((p:string)=>!p||p==='.'||p==='..'||/[\x00-\x1f%]/.test(p))||seen.has(d.name))throw Error('baseline_metadata_rejected');
  seen.add(d.name);
  const exists=d.createTime!==undefined||d.updateTime!==undefined;
  if(exists&&[d.createTime,d.updateTime].some(v=>typeof v!=='string'||!/^\d{4}-\d{2}-\d{2}T/.test(v)||!Number.isFinite(Date.parse(v))))throw Error('baseline_metadata_rejected');
  return {name:d.name as string,exists};
 });
}
