import {UserRefreshClient} from 'google-auth-library';
import {InventoryError} from '../contract';
import {sha256,type ValidatedApproval} from './approval';
import {type QuerySession} from './transport';
import {assertReadBody} from '../query_codec';

type Auth={token:()=>Promise<string>;info:(token:string)=>Promise<any>};
export interface SessionDependencies {adcBytes:Buffer;send:typeof fetch;now:()=>number;deadline:number;authFactory?:(adc:any,request:(url:string,init:RequestInit)=>Promise<any>)=>Auth;}
const root='https://firestore.googleapis.com/v1/projects/resqme-943ee/databases/(default)';
const urls={project:'https://firebase.googleapis.com/v1beta1/projects/resqme-943ee',database:root,release:'https://firebaserules.googleapis.com/v1/projects/resqme-943ee/releases/cloud.firestore',ruleset:'https://firebaserules.googleapis.com/v1/projects/resqme-943ee/rulesets/aa4be7e8-ce25-44d1-afd8-c10654658bab'};
export interface VerifiedSession extends QuerySession {readonly adapterReadOnly:true;readonly operatorIamPermissions:'NOT_ASSESSED';metadata:(kind:keyof typeof urls,signal:AbortSignal)=>Promise<any>;}
async function bounded<T>(operation:(signal:AbortSignal)=>Promise<T>,signal:AbortSignal,ms:number):Promise<T>{
 if(signal.aborted||ms<=0)throw new InventoryError('session_cancelled_or_expired');
 const child=new AbortController();let timer:ReturnType<typeof setTimeout>;let cancel:()=>void=()=>{};
 const stop=new Promise<never>((_,reject)=>{cancel=()=>{child.abort();reject(new InventoryError('session_cancelled_or_expired'));};signal.addEventListener('abort',cancel,{once:true});timer=setTimeout(cancel,ms);});
 try{return await Promise.race([operation(child.signal),stop]);}finally{clearTimeout(timer!);signal.removeEventListener('abort',cancel);child.abort();}
}
async function json(send:typeof fetch,url:string,init:RequestInit,signal:AbortSignal,ms:number){
 return bounded(async inner=>{
  try{
   const response=await send(url,{...init,signal:inner,redirect:'error'});if(!response.ok)throw new Error();
   const reader=response.body?.getReader();if(!reader)throw new Error();const chunks:Uint8Array[]=[];let size=0;
   try{while(true){const v=await reader.read();if(v.done)break;size+=v.value.length;if(size>1048576)throw new Error();chunks.push(v.value);}}finally{await reader.cancel().catch(()=>{});reader.releaseLock();}
   const data=JSON.parse(Buffer.concat(chunks).toString());if(data===null||data.error)throw new Error();return data;
  }catch{throw new InventoryError('hosted_request_failed');}
 },signal,ms);
}
function libraryAuth(adc:any,request:(url:string,init:RequestInit)=>Promise<any>):Auth {
 const client=new UserRefreshClient({clientId:adc.client_id,clientSecret:adc.client_secret,refreshToken:adc.refresh_token});
 // Replace the complete Gaxios transport; no retry/default network fallback is retained.
 client.transporter={request:async(options:any)=>{const headers=new Headers(options.headers);headers.set('Content-Type','application/x-www-form-urlencoded;charset=UTF-8');return {data:await request(String(options.url),{method:'POST',headers,body:options.data?.toString()})};}} as any;
 return {token:async()=>{const result=await client.getAccessToken();if(!result.token)throw new Error();return result.token;},info:token=>client.getTokenInfo(token)};
}
export async function openVerifiedSession(approval:ValidatedApproval,deps:SessionDependencies,signal:AbortSignal):Promise<VerifiedSession>{
 try{
  const {manifest:m}=approval;
  if(sha256(deps.adcBytes)!==m.operator.adcSha256)throw new Error();
  const adc=JSON.parse(deps.adcBytes.toString());if(adc.type!=='authorized_user'||Object.keys(adc).some(k=>!['type','client_id','client_secret','refresh_token','quota_project_id','universe_domain','account'].includes(k))||[adc.client_id,adc.client_secret,adc.refresh_token].some(v=>typeof v!=='string'||!v)||(adc.universe_domain&&adc.universe_domain!=='googleapis.com'))throw new Error();
  const ms=()=>Math.min(m.limits.requestMs,deps.deadline-deps.now(),Date.parse(m.validUntil)-deps.now());
  const authRequest=async(url:string,init:RequestInit)=>{if(!['https://oauth2.googleapis.com/token','https://oauth2.googleapis.com/tokeninfo'].includes(url)||init.method!=='POST')throw new InventoryError('auth_endpoint_rejected');return json(deps.send,url,init,signal,ms());};
  const auth=(deps.authFactory??libraryAuth)(adc,authRequest);
  const token=await bounded(()=>auth.token(),signal,ms());const info=await bounded(()=>auth.info(token),signal,ms());
  const subject=info.sub??info.user_id;
  if(typeof token!=='string'||!token||typeof subject!=='string'||subject!==m.operator.subject||info.email!==m.operator.email||info.email_verified!==true||(info.sub!==undefined&&info.user_id!==undefined&&info.sub!==info.user_id)||!Number.isFinite(info.expiry_date)||info.expiry_date<deps.deadline+60000)throw new Error();
  const request=async(url:string,method:'GET'|'POST',body:unknown,s:AbortSignal)=>{
   if(deps.now()>=info.expiry_date||deps.now()>=Date.parse(m.validUntil)||deps.now()>=deps.deadline)throw new InventoryError('session_expired');
   return json(deps.send,url,{method,headers:{Authorization:`Bearer ${token}`,'Content-Type':'application/json'},...(body===undefined?{}:{body:JSON.stringify(body)})},s,ms());
  };
  const session:VerifiedSession={adapterReadOnly:true,operatorIamPermissions:'NOT_ASSESSED',metadata:(kind,s)=>{if(!Object.hasOwn(urls,kind))throw new InventoryError('endpoint_rejected');return request(urls[kind],'GET',undefined,s);},query:async(method,body,s)=>{if(!['runQuery','listCollectionIds'].includes(method))throw new InventoryError('endpoint_rejected');assertReadBody(method,body,m.limits.pageSize);return request(`${root}/documents:${method}`,'POST',body,s);}};
  const project=await session.metadata('project',signal);if(project.projectId!==m.target.project||project.projectNumber!==m.target.projectNumber||project.state!=='ACTIVE')throw new Error();
  const database=await session.metadata('database',signal);if(database.name!=='projects/resqme-943ee/databases/(default)'||database.type!=='FIRESTORE_NATIVE'||database.locationId!=='nam5')throw new Error();
  await verifyG1(session,approval,signal);return session;
 }catch{throw new InventoryError('hosted_session_rejected');}
}
export async function verifyG1(session:VerifiedSession,approval:ValidatedApproval,signal:AbortSignal){
 try{
  const release=await session.metadata('release',signal);const b=approval.manifest.g1;
  if(release.name!==b.release||release.rulesetName!==b.ruleset)throw new Error();
  const rules=await session.metadata('ruleset',signal);const files=rules.source?.files;
  if(rules.name!==b.ruleset||!Array.isArray(files)||files.length!==1||files[0].name!=='firestore.containment.rules'||typeof files[0].content!=='string'||sha256(files[0].content)!==b.sha256)throw new Error();
  return {release:b.release,ruleset:b.ruleset,sha256:b.sha256};
 }catch{throw new InventoryError('g1_baseline_rejected');}
}
