import {readFileSync} from 'node:fs';
import {resolve,dirname} from 'node:path';
import * as grpc from '@grpc/grpc-js';
import {fromJSON} from '@grpc/proto-loader';
import {metadataDocuments} from './protocol';

export interface RpcBoundary {
 invoke(method:'listDocuments'|'listCollectionIds',request:Record<string,unknown>,timeoutMs:number,signal:AbortSignal):Promise<any>;
 close():void;
}
const root='projects/demo-resqme/databases/(default)/documents';
function reject():never {throw Error('baseline_rpc_rejected');}
function local(env:NodeJS.ProcessEnv){if(env.GCLOUD_PROJECT!=='demo-resqme'||env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:8080')reject();}
function path(parent:string){if(parent!==root&&(!parent.startsWith(root+'/')||parent.slice(root.length+1).split('/').length%2))reject();if(parent.split('/').some(p=>!p||p==='.'||p==='..'||/[\x00-\x1f%]/.test(p)))reject();}

/** No GoogleAuth/GAX/ADC. Only explicitly insecure loopback channel and emulator owner marker. */
export function loopbackRpc(env:NodeJS.ProcessEnv):RpcBoundary & {codec:any} {
 local(env);
 const file=resolve(dirname(require.resolve('@google-cloud/firestore')),'../protos/v1.json');
 const definition=fromJSON(JSON.parse(readFileSync(file,'utf8')),{longs:String,enums:String,defaults:false,oneofs:false});
 const pkg=grpc.loadPackageDefinition(definition) as any;
 const service=pkg.google.firestore.v1.Firestore;
 const client=new service('127.0.0.1:8080',grpc.credentials.createInsecure(),{
  'grpc.enable_retries':0,'grpc.max_receive_message_length':1048576,
 });
 return {codec:service.service,close:()=>client.close(),invoke:(method,request,timeoutMs,signal)=>new Promise((resolveCall,rejectCall)=>{
  if(signal.aborted){rejectCall(Error('baseline_rpc_cancelled'));return;}
  const metadata=new grpc.Metadata();metadata.set('authorization','Bearer owner');
  const call=client[method](request,metadata,{deadline:Date.now()+timeoutMs},(error:any,response:any)=>{
   signal.removeEventListener('abort',abort);if(error)rejectCall(Error('baseline_rpc_request_failed'));else resolveCall(response);
  });
  const abort=()=>{call.cancel();rejectCall(Error('baseline_rpc_cancelled'));};signal.addEventListener('abort',abort,{once:true});if(signal.aborted)abort();
 })};
}

export class MetadataRpcTransport {
 private used=0;private stopped=false;private deadline:number;
 private cap:number;private requestMs:number;
 constructor(env:NodeJS.ProcessEnv,private rpc:RpcBoundary,limits:{requests?:number;requestMs?:number;overallMs?:number}={}){
  local(env);this.cap=limits.requests??200;this.requestMs=limits.requestMs??30000;const overall=limits.overallMs??600000;
  for(const [value,max] of [[this.cap,200],[this.requestMs,30000],[overall,600000]])if(!Number.isInteger(value)||value<1||value>max)reject();
  this.deadline=Date.now()+overall;
 }
 private async call(method:'listDocuments'|'listCollectionIds',request:Record<string,unknown>,signal:AbortSignal){
  if(this.stopped||signal.aborted||++this.used>this.cap||Date.now()>=this.deadline){this.stopped=true;reject();}
  const inner=new AbortController();const ms=Math.min(this.requestMs,this.deadline-Date.now());
  let timer:ReturnType<typeof setTimeout>|undefined;let cancel=()=>{};
  try {
   const stop=new Promise<never>((_,fail)=>{cancel=()=>{inner.abort();fail(Error('baseline_rpc_cancelled'));};signal.addEventListener('abort',cancel,{once:true});timer=setTimeout(cancel,ms);});
   const result=await Promise.race([this.rpc.invoke(method,request,ms,inner.signal),stop]);
   if(inner.signal.aborted||signal.aborted||Date.now()>=this.deadline)reject();
   if(!result||typeof result!=='object'||Array.isArray(result))reject();
   return result;
  }catch{this.stopped=true;reject();}finally{if(timer)clearTimeout(timer);signal.removeEventListener('abort',cancel);inner.abort();}
 }
 async documents(parent:string,collectionId:string,pageSize:number,token:string|undefined,signal:AbortSignal){
  path(parent);if(!collectionId||collectionId.length>1500||/[\/\x00-\x1f%]/.test(collectionId)||collectionId==='.'||collectionId==='..'||!Number.isInteger(pageSize)||pageSize<1||pageSize>100||token!==undefined&&(typeof token!=='string'||!token||token.length>8192))reject();
  try{
   const raw=await this.call('listDocuments',{parent,collectionId,showMissing:true,mask:{fieldPaths:[]},pageSize,...(token===undefined?{}:{pageToken:token})},signal);
   // Validate raw protobuf object before timestamp normalization; never strip fields.
   if(Object.keys(raw).some(k=>!['documents','nextPageToken'].includes(k))||raw.documents!==undefined&&!Array.isArray(raw.documents))reject();
   const docs=raw.documents??[];if(docs.length>pageSize)reject();
   const converted=docs.map((d:any)=>{
    if(!d||typeof d!=='object'||Array.isArray(d)||Object.keys(d).some(k=>!['name','createTime','updateTime'].includes(k)))reject();
    const result={...d};
    for(const key of ['createTime','updateTime'])if(Object.hasOwn(d,key)){
     const t=d[key];if(!t||typeof t!=='object'||Object.keys(t).some(k=>!['seconds','nanos'].includes(k))||!/^\d+$/.test(String(t.seconds??''))||!Number.isInteger(t.nanos??0)||(t.nanos??0)<0||(t.nanos??0)>999999999)reject();
     const ms=Number(t.seconds)*1000+Math.floor((t.nanos??0)/1000000);if(!Number.isSafeInteger(ms))reject();result[key]=new Date(ms).toISOString();
    }
    return result;
   });
   const documents=metadataDocuments({...raw,...(raw.documents===undefined?{}:{documents:converted})},'demo');
   const prefix=parent+'/'+collectionId+'/';if(documents.some(d=>!d.name.startsWith(prefix)||d.name.slice(prefix.length).includes('/')))reject();
   return {documents,nextPageToken:raw.nextPageToken as string|undefined};
  }catch{this.stopped=true;reject();}
 }
 async collections(parent:string,pageSize:number,token:string|undefined,signal:AbortSignal){
  path(parent);if(!Number.isInteger(pageSize)||pageSize<1||pageSize>100||token!==undefined&&(typeof token!=='string'||!token||token.length>8192))reject();
  try{
   const raw=await this.call('listCollectionIds',{parent,pageSize,...(token===undefined?{}:{pageToken:token})},signal);
   if(Object.keys(raw).some(k=>!['collectionIds','nextPageToken'].includes(k))||raw.collectionIds!==undefined&&!Array.isArray(raw.collectionIds)||raw.nextPageToken!==undefined&&(typeof raw.nextPageToken!=='string'||!raw.nextPageToken||raw.nextPageToken.length>8192))reject();
   const ids=raw.collectionIds??[];if(ids.length>pageSize||new Set(ids).size!==ids.length||ids.some((id:any)=>typeof id!=='string'||!id||id.length>1500||/[\/\x00-\x1f%]/.test(id)||id==='.'||id==='..'))reject();
   return {collectionIds:ids as string[],nextPageToken:raw.nextPageToken as string|undefined};
  }catch{this.stopped=true;reject();}
 }
 close(){this.stopped=true;this.rpc.close();}
}
