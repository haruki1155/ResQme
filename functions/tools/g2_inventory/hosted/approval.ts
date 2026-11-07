import {createHash} from 'node:crypto';
import {win32} from 'node:path';
import {boundedLimits,InventoryError,scopes,type Limits} from '../contract';

export const baseline=Object.freeze({release:'projects/resqme-943ee/releases/cloud.firestore',ruleset:'projects/resqme-943ee/rulesets/aa4be7e8-ce25-44d1-afd8-c10654658bab',sha256:'7bff2de50c73415a3b12a6783f42ff621b1b04803ffc4e2634e6ba68e5d655f9'});
export const artifactFiles=Object.freeze(['functions/package-lock.json','firestore.containment.rules',...['contract','query_codec','transport','inventory','runner','hosted/approval','hosted/transport','hosted/session','hosted/evidence','hosted/runner'].map(p=>`functions/lib/tools/g2_inventory/${p}.js`),'functions/tools/g2_inventory/hosted/windows_evidence.ps1'].sort());
export interface HostedManifest {
 schemaVersion:1;runId:string;approvalReference:string;validFrom:string;validUntil:string;artifacts:Record<string,string>;nodeVersion:string;
 operator:{email:string;subject:string;adcPath:string;adcSha256:string};
 target:{project:string;projectNumber:string;database:string;location:string};g1:typeof baseline;scopes:unknown;limits:Limits;
 evidence:{path:string;ownerSid:string;readerSids:string[];retentionDeadline:string;disposalMethod:string;responsibleOperator:string;unsyncedAttested:true};
}
export interface ValidatedApproval {readonly manifest:Readonly<HostedManifest>;readonly digest:string;}
function fail():never {throw new InventoryError('approval_rejected');}
export function canonicalManifest(value:unknown):string {
 if(value===null||typeof value==='boolean'||typeof value==='string')return JSON.stringify(value);
 if(typeof value==='number'){if(!Number.isSafeInteger(value))fail();return JSON.stringify(value);}
 if(Array.isArray(value)){if(Object.keys(value).length!==value.length)fail();return '['+value.map(canonicalManifest).join(',')+']';}
 if(value&&typeof value==='object'&&Object.getPrototypeOf(value)===Object.prototype)return '{'+Object.keys(value).sort().map(k=>JSON.stringify(k)+':'+canonicalManifest((value as Record<string,unknown>)[k])).join(',')+'}';
 return fail();
}
export const sha256=(bytes:string|Buffer)=>createHash('sha256').update(bytes).digest('hex');
function keys(value:any,names:string[]) {if(!value||typeof value!=='object'||Array.isArray(value)||Object.keys(value).sort().join('|')!==[...names].sort().join('|'))fail();}
function text(v:unknown,max=512):v is string {return typeof v==='string'&&v.trim().length>0&&v.length<=max&&!/[\x00-\x1f]/.test(v);}
function absolute(v:unknown) {return text(v,2048)&&/^[A-Za-z]:\\/.test(v)&&win32.normalize(v)===v&&!v.includes('..')&&!v.includes(':',2);}
function freeze<T>(value:T):T {if(value&&typeof value==='object'){Object.values(value).forEach(freeze);Object.freeze(value);}return value;}
export function validateApproval(value:unknown,artifacts:{hashes:Record<string,string>;nodeVersion:string},now:number):ValidatedApproval {
 try {
  canonicalManifest(value);const m=value as HostedManifest;
  keys(m,['schemaVersion','runId','approvalReference','validFrom','validUntil','artifacts','nodeVersion','operator','target','g1','scopes','limits','evidence']);
  keys(m.operator,['email','subject','adcPath','adcSha256']);keys(m.target,['project','projectNumber','database','location']);keys(m.g1,['release','ruleset','sha256']);keys(m.evidence,['path','ownerSid','readerSids','retentionDeadline','disposalMethod','responsibleOperator','unsyncedAttested']);keys(m.limits,['pageSize','perQuery','total','collections','requestMs','overallMs']);
  if(m.schemaVersion!==1||!text(m.runId,80)||!/^[A-Za-z0-9_-]+$/.test(m.runId)||!text(m.approvalReference)||m.nodeVersion!==artifacts.nodeVersion||!/^v\d+\.\d+\.\d+$/.test(m.nodeVersion))fail();
  if(canonicalManifest(m.target)!==canonicalManifest({project:'resqme-943ee',projectNumber:'519076598217',database:'(default)',location:'nam5'})||canonicalManifest(m.g1)!==canonicalManifest(baseline)||canonicalManifest(m.scopes)!==canonicalManifest(scopes))fail();
  if(!Number.isFinite(now)||!Number.isFinite(Date.parse(m.validFrom))||!Number.isFinite(Date.parse(m.validUntil))||Date.parse(m.validFrom)>now||Date.parse(m.validUntil)<=now)fail();
  boundedLimits(m.limits);
  if(!text(m.operator.email)||!/^\S+@\S+\.\S+$/.test(m.operator.email)||!text(m.operator.subject)||!absolute(m.operator.adcPath)||!/^[a-f0-9]{64}$/.test(m.operator.adcSha256))fail();
  const broadSids=['S-1-1-0','S-1-5-11','S-1-5-32-545','S-1-5-32-546','S-1-5-7','S-1-5-4','S-1-5-2','S-1-2-0'];
  if(!absolute(m.evidence.path)||!/^S-1-\d+(?:-\d+)+$/.test(m.evidence.ownerSid)||!Array.isArray(m.evidence.readerSids)||!m.evidence.readerSids.length||m.evidence.readerSids.some(s=>!/^S-1-\d+(?:-\d+)+$/.test(s)||broadSids.includes(s))||new Set(m.evidence.readerSids).size!==m.evidence.readerSids.length||!m.evidence.readerSids.includes(m.evidence.ownerSid)||!text(m.evidence.disposalMethod)||!text(m.evidence.responsibleOperator)||m.evidence.unsyncedAttested!==true||!Number.isFinite(Date.parse(m.evidence.retentionDeadline))||Date.parse(m.evidence.retentionDeadline)<=Date.parse(m.validUntil))fail();
  if(Object.keys(m.artifacts).sort().join('|')!==artifactFiles.join('|')||Object.keys(artifacts.hashes).sort().join('|')!==artifactFiles.join('|'))fail();
  for(const file of artifactFiles)if(!/^[a-f0-9]{64}$/.test(m.artifacts[file])||m.artifacts[file]!==artifacts.hashes[file])fail();
  if(m.artifacts['firestore.containment.rules']!==baseline.sha256)fail();
  const copy=JSON.parse(canonicalManifest(m));return freeze({manifest:copy,digest:sha256(canonicalManifest(copy))});
 }catch {return fail();}
}
export async function confirmApproval(approval:ValidatedApproval,input:{isTTY:boolean;readLine:(prompt:'confirmation'|'reference')=>Promise<string|null>}) {
 if(!input.isTTY||await input.readLine('confirmation')!==`APPROVE READ-ONLY INVENTORY ${approval.digest}`||await input.readLine('reference')!==approval.manifest.approvalReference)fail();
}
