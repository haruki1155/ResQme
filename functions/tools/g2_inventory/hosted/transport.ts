import {type ReadTransport,type ScopeId} from '../contract';
import {collectionBody,decodeCollections,queryBody,decodeQuery} from '../query_codec';
export interface QuerySession {query(method:'listCollectionIds'|'runQuery',body:unknown,signal:AbortSignal):Promise<unknown>;}
export class HostedFirestoreTransport implements ReadTransport {
 constructor(private readonly session:QuerySession){}
 async collections(token:string|undefined,size:number,signal:AbortSignal){return decodeCollections(await this.session.query('listCollectionIds',collectionBody(token,size),signal));}
 async query(scope:ScopeId,after:string|undefined,size:number,signal:AbortSignal){return decodeQuery(scope,await this.session.query('runQuery',queryBody(scope,after,size,'staging'),signal),size,'staging');}
}
