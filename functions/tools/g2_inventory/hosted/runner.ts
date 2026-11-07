import {readFile,mkdir,writeFile,lstat,realpath} from 'node:fs/promises';
import {writeFileSync} from 'node:fs';
import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
import {resolve,join,win32} from 'node:path';
import {createInterface} from 'node:readline/promises';
import {artifactFiles,validateApproval,confirmApproval,sha256,type ValidatedApproval} from './approval';
import {prepareEvidence,type EvidenceIO,type EvidenceWriter} from './evidence';
import {openVerifiedSession,verifyG1,type SessionDependencies} from './session';
import {HostedFirestoreTransport} from './transport';
import {runInventory} from '../inventory';

export interface HostedDependencies {
 manifest:unknown;artifacts:{hashes:Record<string,string>;nodeVersion:string};env:NodeJS.ProcessEnv;now:()=>number;
 confirmation:Parameters<typeof confirmApproval>[1];onValidated?:(approval:ValidatedApproval)=>void;
 readAdc:(path:string)=>Promise<Buffer>;evidence:EvidenceIO;session:Omit<SessionDependencies,'adcBytes'|'deadline'|'now'>;signal?:AbortSignal;
}
export async function runHostedInventory(deps:HostedDependencies):Promise<{status:string;exitCode:number}>{
 const start=deps.now();const controller=new AbortController();const cancel=()=>controller.abort();let writer:EvidenceWriter|undefined;let result:Awaited<ReturnType<typeof runInventory>>|undefined;
 let timer:ReturnType<typeof setTimeout>|undefined;let stage='approval';
 try{
  if(deps.signal?.aborted)throw new Error();deps.signal?.addEventListener('abort',cancel,{once:true});
  if(Object.keys(deps.env).some(k=>/EMULATOR|ENDPOINT|GOOGLE_APPLICATION_CREDENTIALS|GOOGLE_API_USE/.test(k)&&deps.env[k])||['GCLOUD_PROJECT','GOOGLE_CLOUD_PROJECT'].some(k=>deps.env[k]&&deps.env[k]!=='resqme-943ee'))throw new Error();
  const approval=validateApproval(deps.manifest,deps.artifacts,start);deps.onValidated?.(approval);
  const m=approval.manifest;const deadline=Math.min(start+m.limits.overallMs,Date.parse(m.validUntil));
  const expiry=new Promise<never>((_,reject)=>{timer=setTimeout(()=>{cancel();reject(new Error());},Math.max(0,deadline-deps.now()));});
  const cancelled=new Promise<never>((_,reject)=>controller.signal.addEventListener('abort',()=>reject(new Error()),{once:true}));
  const work=async()=>{
   await confirmApproval(approval,deps.confirmation);if(controller.signal.aborted||deps.now()>=deadline)throw new Error();
   writer=await prepareEvidence(approval,deps.evidence,controller.signal);
   if(controller.signal.aborted||deps.now()>=deadline)throw new Error();
   stage='session';const adcBytes=await deps.readAdc(m.operator.adcPath);if(controller.signal.aborted)throw new Error();
   const session=await openVerifiedSession(approval,{...deps.session,adcBytes,deadline,now:deps.now},controller.signal);
   const reserve=Math.min(30000,Math.floor(m.limits.overallMs/4));const remaining=deadline-deps.now()-reserve;if(remaining<1)throw new Error();
   result=await runInventory(new HostedFirestoreTransport(session),{namespace:'staging',limits:{...m.limits,overallMs:remaining},signal:controller.signal,now:deps.now});
   try{await verifyG1(session,approval,controller.signal);}catch{result.report.status='INCOMPLETE';result.report.reasons.push('final_g1_verification_failed');}
   await writer.finish(result,{runId:m.runId,manifestDigest:approval.digest,identity:{email:m.operator.email,subject:m.operator.subject},g1:m.g1,adapterReadOnly:true,operatorIamPermissions:'NOT_ASSESSED',startedAt:new Date(start).toISOString(),finishedAt:new Date(deps.now()).toISOString()});
   if(controller.signal.aborted||deps.now()>=deadline)throw new Error();
   await writer.publish(result.report.status,deps.now,deadline);
   return {status:result.report.status,exitCode:result.report.status==='COMPLETE'?0:1};
  };
  return await Promise.race([work(),expiry,cancelled]);
 }catch{
  if(writer&&!controller.signal.aborted)await writer.fail(result?'INCOMPLETE':'FAILED').catch(()=>{});controller.abort();
  return {status:result?'INCOMPLETE':'FAILED',exitCode:stage==='approval'?2:1};
 }finally{if(timer)clearTimeout(timer);deps.signal?.removeEventListener('abort',cancel);controller.abort();}
}

// Only invoked by a future explicitly authorized operator; imports do no I/O.
export function validateManifestLocation(path:string,facts:{canonical:string;isLink:boolean;isFile:boolean;insideGit:boolean}){
 if(!/^[A-Za-z]:\\/.test(path)||facts.isLink||!facts.isFile||facts.insideGit||win32.normalize(path).toLowerCase()!==win32.normalize(facts.canonical).toLowerCase())throw new Error('manifest_location_rejected');
}
export async function main(args=process.argv.slice(2)):Promise<number>{
 let lines:ReturnType<typeof createInterface>|undefined;
 try{
  if(process.platform!=='win32'||args.length!==2||args[0]!=='--manifest'||!win32.isAbsolute(args[1])||!process.stdin.isTTY||!process.stdout.isTTY)throw new Error();
  const repo=resolve(__dirname,'../../../../..');
  const invoke=promisify(execFile);
  const stat=await lstat(args[1]);let insideGit=true;
  try{await invoke('git',['-C',win32.dirname(args[1]),'rev-parse','--git-dir'],{windowsHide:true,timeout:10000,env:{...process.env,LC_ALL:'C',GIT_DIR:undefined,GIT_WORK_TREE:undefined,GIT_COMMON_DIR:undefined,GIT_CEILING_DIRECTORIES:undefined}});}catch(error:any){if(error.code===128&&String(error.stderr).includes('not a git repository'))insideGit=false;else throw new Error();}
  validateManifestLocation(args[1],{canonical:await realpath(args[1]),isLink:stat.isSymbolicLink(),isFile:stat.isFile(),insideGit});
  if(stat.size>131072)throw new Error();
  const text=await readFile(args[1]);if(text.length>131072)throw new Error();const manifest=JSON.parse(text.toString());
  const hashes:Record<string,string>={};for(const file of artifactFiles){const bytes=await readFile(join(repo,file));hashes[file]=sha256(bytes);}
  const helper=join(repo,'functions/tools/g2_inventory/hosted/windows_evidence.ps1');
  const io:EvidenceIO={
   inspect:async(path,signal)=>{const r=await invoke('powershell.exe',['-NoProfile','-NonInteractive','-File',helper,'-LiteralDirectory',path],{windowsHide:true,signal,timeout:30000,maxBuffer:65536});return JSON.parse(r.stdout);},
   gitRoots:async()=>{const r=await invoke('git',['worktree','list','--porcelain'],{cwd:repo,windowsHide:true,timeout:10000});return r.stdout.split(/\r?\n/).filter(l=>l.startsWith('worktree ')).map(l=>l.slice(9));},
   reserve:async(path)=>{await mkdir(path);},
   write:async(path,data,signal)=>{await writeFile(path,data,{flag:'wx',signal});},
   commit:(path,data,signal)=>{if(signal.aborted)throw new Error();writeFileSync(path,data,{flag:'wx'});},
  };
  lines=createInterface({input:process.stdin,output:process.stdout});
  const input=lines;const abort=new AbortController();const stop=()=>abort.abort();process.once('SIGINT',stop);process.once('SIGTERM',stop);
  try{
   const result=await runHostedInventory({manifest,artifacts:{hashes,nodeVersion:process.version},env:process.env,now:Date.now,confirmation:{isTTY:true,readLine:async kind=>input.question(kind==='confirmation'?'Enter owner-approved digest confirmation: ':'Enter external approval reference: ')},readAdc:async(path)=>{const s=await lstat(path);if(s.isSymbolicLink()||s.size>65536||win32.normalize(await realpath(path)).toLowerCase()!==win32.normalize(path).toLowerCase())throw new Error();return readFile(path);},evidence:io,session:{send:fetch},signal:abort.signal});
   console.log(JSON.stringify({status:result.status,clearance:'NOT_GRANTED',g2Complete:false,adapterReadOnly:true,operatorIamPermissions:'NOT_ASSESSED'}));return result.exitCode;
  }finally{process.removeListener('SIGINT',stop);process.removeListener('SIGTERM',stop);}
 }catch{console.error('hosted_inventory_configuration_rejected');return 2;}
 finally{lines?.close();}
}
if(require.main===module)void main().then(code=>{process.exitCode=code;});
