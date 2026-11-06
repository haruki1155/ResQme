import {InventoryError, localConfig, scopeFor, validName, type ReadTransport, type ProjectedDocument, type ScopeId} from './contract';

// Explicit emulator REST requests: no ADC, Admin initializer, Auth or callable client.
export class LocalFirestoreTransport implements ReadTransport {
  private readonly base:string;
  constructor(env:NodeJS.ProcessEnv, private readonly send:typeof fetch=fetch) {
    this.base=`${localConfig(env).origin}/v1/projects/demo-resqme/databases/(default)/documents`;
  }
  private pageSize(value:number) { if(!Number.isInteger(value)||value<1||value>100) throw new InventoryError('invalid_page_size'); }
  private async post(method:string,body:unknown,signal:AbortSignal):Promise<any> {
    try {
      // Firestore emulator's fixed admin marker; not a hosted OAuth credential.
      const response=await this.send(`${this.base}:${method}`,{method:'POST',headers:{'Content-Type':'application/json',Authorization:'Bearer owner'},body:JSON.stringify(body),signal,redirect:'error'});
      if(!response.ok) throw new InventoryError(response.status===403?'permission_denied':'request_failed');
      const reader=response.body?.getReader();if(!reader) throw new InventoryError('invalid_response');
      const chunks:Uint8Array[]=[];let size=0;
      try {while(true){const {done,value}=await reader.read();if(done) break;size+=value.length;if(size>1048576) throw new InventoryError('response_too_large');chunks.push(value);}} finally {await reader.cancel().catch(()=>{});reader.releaseLock();}
      return JSON.parse(Buffer.concat(chunks).toString('utf8'));
    } catch(error) {if(error instanceof InventoryError) throw error;throw new InventoryError(signal.aborted?'cancelled':'request_failed');}
  }
  async collections(token:string|undefined,pageSize:number,signal:AbortSignal) {
    this.pageSize(pageSize);
    const data=await this.post('listCollectionIds',{pageSize,...(token?{pageToken:token}:{})},signal);
    if(!data||typeof data!=='object'||Array.isArray(data)||Object.keys(data).some(key=>!['collectionIds','nextPageToken'].includes(key))||!Array.isArray(data.collectionIds??[])||(data.collectionIds??[]).some((id:unknown)=>typeof id!=='string'||!id||id.includes('/')||Buffer.byteLength(id)>1500)||(data.nextPageToken!==undefined&&(typeof data.nextPageToken!=='string'||data.nextPageToken.length>8192))) throw new InventoryError('invalid_collection_page');
    return {ids:data.collectionIds??[],...(data.nextPageToken?{next:data.nextPageToken}:{})};
  }
  async query(id:ScopeId,after:string|undefined,pageSize:number,signal:AbortSignal):Promise<ProjectedDocument[]> {
    const scope=scopeFor(id);this.pageSize(pageSize);if(after) validName(id,after);
    const data=await this.post('runQuery',{structuredQuery:{from:[{collectionId:scope.collection,...(scope.group?{allDescendants:true}:{})}],select:{fields:(scope.fields.length?scope.fields:['__name__']).map(fieldPath=>({fieldPath}))},orderBy:[{field:{fieldPath:'__name__'},direction:'ASCENDING'}],limit:pageSize,...(after?{startAt:{values:[{referenceValue:after}],before:false}}:{})}},signal);
    if(!Array.isArray(data)) throw new InventoryError('invalid_query_page');
    const documents:ProjectedDocument[]=[];
    for(const row of data) {
      if(!row || typeof row!=='object'||row.error) throw new InventoryError('invalid_query_page');
      if(!row.document) {
        if(typeof row.readTime!=='string'||Object.keys(row).some(key=>!['readTime','transaction','skippedResults','done'].includes(key)))throw new InventoryError('invalid_query_page');
        continue;
      }
      const document=row.document;validName(id,document.name);
      const fields=document.fields??{};
      if(!fields||typeof fields!=='object'||Array.isArray(fields)||Object.keys(fields).some(key=>!scope.fields.includes(key))) throw new InventoryError('projection_violation');
      for(const time of [document.createTime,document.updateTime]) if(time!==undefined&&(typeof time!=='string'||!/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d{1,9})?Z$/.test(time))) throw new InventoryError('invalid_metadata');
      documents.push({name:document.name,fields,...(document.createTime?{createTime:document.createTime}:{}),...(document.updateTime?{updateTime:document.updateTime}:{})});
    }
    if(documents.length>pageSize) throw new InventoryError('invalid_query_page');
    return documents;
  }
}
