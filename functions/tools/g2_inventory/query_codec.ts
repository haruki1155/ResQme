import {InventoryError,scopeFor,validName,type ScopeId,type DocumentNamespace,type ProjectedDocument} from './contract';
import {isDeepStrictEqual} from 'node:util';
import {scopes} from './contract';
export function assertReadBody(method:'runQuery'|'listCollectionIds',body:any,maxPage:number){
 try{
  if(method==='listCollectionIds'){
   if(!isDeepStrictEqual(body,collectionBody(body?.pageToken,body?.pageSize))||body.pageSize>maxPage||(body.pageToken!==undefined&&(typeof body.pageToken!=='string'||!body.pageToken||body.pageToken.length>8192)))throw new Error();return;
  }
  const q=body?.structuredQuery;const scope=scopes.find(s=>s.collection===q?.from?.[0]?.collectionId);if(!scope||q.limit>maxPage)throw new Error();
  const after=q.startAt?.values?.[0]?.referenceValue;
  if(!isDeepStrictEqual(body,queryBody(scope.id,after,q.limit,'staging')))throw new Error();
 }catch{throw new InventoryError('query_body_rejected');}
}
function pageSize(n:number){if(!Number.isInteger(n)||n<1||n>100)throw new InventoryError('invalid_page_size');}
export function collectionBody(token:string|undefined,size:number){pageSize(size);return {pageSize:size,...(token?{pageToken:token}:{})};}
export function decodeCollections(data:any){
 if(!data||typeof data!=='object'||Array.isArray(data)||Object.keys(data).some(key=>!['collectionIds','nextPageToken'].includes(key))||!Array.isArray(data.collectionIds??[])||(data.collectionIds??[]).some((id:unknown)=>typeof id!=='string'||!id||id.includes('/')||Buffer.byteLength(id)>1500)||(data.nextPageToken!==undefined&&(typeof data.nextPageToken!=='string'||data.nextPageToken.length>8192)))throw new InventoryError('invalid_collection_page');
 return {ids:data.collectionIds??[],...(data.nextPageToken?{next:data.nextPageToken}:{})};
}
export function queryBody(id:ScopeId,after:string|undefined,size:number,namespace:DocumentNamespace='demo'){
 const scope=scopeFor(id);pageSize(size);if(after)validName(id,after,namespace);
 return {structuredQuery:{from:[{collectionId:scope.collection,...(scope.group?{allDescendants:true}:{})}],select:{fields:(scope.fields.length?scope.fields:['__name__']).map(fieldPath=>({fieldPath}))},orderBy:[{field:{fieldPath:'__name__'},direction:'ASCENDING'}],limit:size,...(after?{startAt:{values:[{referenceValue:after}],before:false}}:{})}};
}
export function decodeQuery(id:ScopeId,data:any,size:number,namespace:DocumentNamespace='demo'):ProjectedDocument[]{
 const scope=scopeFor(id);if(!Array.isArray(data))throw new InventoryError('invalid_query_page');const documents:ProjectedDocument[]=[];
 for(const row of data){
  if(!row||typeof row!=='object'||row.error)throw new InventoryError('invalid_query_page');
  if(!row.document){if(typeof row.readTime!=='string'||Object.keys(row).some(key=>!['readTime','transaction','skippedResults','done'].includes(key)))throw new InventoryError('invalid_query_page');continue;}
  const d=row.document;validName(id,d.name,namespace);const fields=d.fields??{};
  if(!fields||typeof fields!=='object'||Array.isArray(fields)||Object.keys(fields).some(key=>!scope.fields.includes(key)))throw new InventoryError('projection_violation');
  for(const time of [d.createTime,d.updateTime])if(time!==undefined&&(typeof time!=='string'||!/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d{1,9})?Z$/.test(time)))throw new InventoryError('invalid_metadata');
  documents.push({name:d.name,fields,...(d.createTime?{createTime:d.createTime}:{}),...(d.updateTime?{updateTime:d.updateTime}:{})});
 }
 if(documents.length>size)throw new InventoryError('invalid_query_page');return documents;
}
