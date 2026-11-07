import {InventoryError, localConfig, type ReadTransport, type ProjectedDocument, type ScopeId} from './contract';
import {collectionBody,decodeCollections,queryBody,decodeQuery} from './query_codec';

// Explicit emulator REST requests: no ADC, Admin initializer, Auth or callable client.
export class LocalFirestoreTransport implements ReadTransport {
  private readonly base:string;
  constructor(env:NodeJS.ProcessEnv, private readonly send:typeof fetch=fetch) {
    this.base=`${localConfig(env).origin}/v1/projects/demo-resqme/databases/(default)/documents`;
  }
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
    return decodeCollections(await this.post('listCollectionIds',collectionBody(token,pageSize),signal));
  }
  async query(id:ScopeId,after:string|undefined,pageSize:number,signal:AbortSignal):Promise<ProjectedDocument[]> {
    return decodeQuery(id,await this.post('runQuery',queryBody(id,after,pageSize),signal),pageSize);
  }
}
