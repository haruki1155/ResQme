import {win32} from 'node:path';
import {InventoryError} from '../contract';
import {canonicalManifest,sha256,type ValidatedApproval} from './approval';
import type {runInventory} from '../inventory';
type Facts={platform:string;filesystem:string;fixed:boolean;canonical:string;ownerSid:string;safePath:boolean;outsideGit:boolean;protected:boolean;aces:{sid:string;allow:boolean;simple:boolean;rights:string}[]};
export interface EvidenceIO {inspect:(path:string,signal:AbortSignal)=>Promise<Facts>;gitRoots:()=>Promise<string[]>;reserve:(path:string,signal:AbortSignal)=>Promise<void>;write:(path:string,data:string,signal:AbortSignal)=>Promise<void>;commit:(path:string,data:string,signal:AbortSignal)=>void;}
export interface EvidenceWriter {finish:(result:Awaited<ReturnType<typeof runInventory>>,metadata:unknown)=>Promise<void>;publish:(status:string,now:()=>number,deadline:number)=>Promise<void>;fail:(status:string)=>Promise<void>;}
const same=(a:string,b:string)=>win32.normalize(a).toLowerCase()===win32.normalize(b).toLowerCase();
const under=(a:string,b:string)=>same(a,b)||win32.normalize(a).toLowerCase().startsWith(win32.normalize(b).toLowerCase().replace(/\\$/,'')+'\\');
export async function prepareEvidence(approval:ValidatedApproval,io:EvidenceIO,signal:AbortSignal):Promise<EvidenceWriter>{
 const e=approval.manifest.evidence;const run=win32.join(e.path,approval.manifest.runId);
 const check=async(path:string,protectedRequired:boolean)=>{
  if(signal.aborted)throw new Error();const f=await io.inspect(path,signal);if(signal.aborted)throw new Error();
  if(f.platform!=='win32'||f.filesystem!=='NTFS'||!f.fixed||!same(f.canonical,path)||!f.safePath||f.outsideGit!==true||(protectedRequired&&!f.protected)||f.ownerSid!==e.ownerSid||!Array.isArray(f.aces)||!f.aces.length||f.aces.some(a=>!a.allow||!a.simple||!e.readerSids.includes(a.sid)))throw new Error();
 };
 try{
  for(const root of await io.gitRoots())if(under(e.path,root))throw new Error();
  await check(e.path,true);await io.reserve(run,signal);await check(run,false);
  const encode=(value:unknown)=>canonicalManifest(JSON.parse(JSON.stringify(value)));
  const write=async(name:string,value:unknown)=>{await check(e.path,true);await check(run,false);await io.write(win32.join(run,name),encode(value),signal);if(signal.aborted)throw new Error();};
  let provisionalDigest:string|undefined;
  // Reservation marker survives any later failure; no cleanup/deletion hides a used run ID.
  await write('run-reserved.json',{runId:approval.manifest.runId,digest:approval.digest,status:'RESERVED',retentionDeadline:e.retentionDeadline,disposalMethod:e.disposalMethod,responsibleOperator:e.responsibleOperator});
  return {
   finish:async(result,metadata)=>{try{
    await write('private-metadata.json',{metadata,rootCollections:result.privateEvidence.rootCollections,records:result.privateEvidence.records});await write('private-aliases.json',result.privateEvidence.aliases);
    const provisional={...result.report,status:'INCOMPLETE',inventoryStatus:result.report.status,publication:'PROVISIONAL',adapterReadOnly:true,operatorIamPermissions:'NOT_ASSESSED'};
    await write('sanitized-report.json',provisional);provisionalDigest=sha256(encode(provisional));
   }catch{throw new InventoryError('evidence_write_failed');}},
   publish:async(status,now,deadline)=>{try{
    await check(e.path,true);await check(run,false);if(!provisionalDigest||signal.aborted||now()>=deadline||!['COMPLETE','INCOMPLETE','FAILED'].includes(status))throw new Error();
    // Final authority is an exclusive synchronous receipt, never an in-flight async report.
    const receipt={status,manifestDigest:approval.digest,reportSha256:provisionalDigest,completedAt:new Date(now()).toISOString(),deadline:new Date(deadline).toISOString(),clearance:'NOT_GRANTED',g2Complete:false};
    const returned=io.commit(win32.join(run,'run-complete.json'),encode(receipt),signal);if(returned!==undefined)throw new Error();
    if(signal.aborted||now()>=deadline){io.commit(win32.join(run,'run-failed.json'),encode({status:'INCOMPLETE',reason:'finalization_deadline',clearance:'NOT_GRANTED',g2Complete:false}),signal);throw new Error();}
   }catch{throw new InventoryError('evidence_publication_failed');}},
   fail:async(status)=>{try{await write('run-failed.json',{status:status==='INCOMPLETE'?'INCOMPLETE':'FAILED',clearance:'NOT_GRANTED',g2Complete:false});}catch{throw new InventoryError('evidence_write_failed');}},
  };
 }catch{throw new InventoryError('evidence_preparation_rejected');}
}
