export class InventoryError extends Error {
  constructor(public readonly code: string) { super(code); this.name='InventoryError'; }
}
export const limits = Object.freeze({pageSize:100, perQuery:500, total:2000, collections:100, requestMs:30000, overallMs:600000});
export type Limits = {[K in keyof typeof limits]: number};
export function boundedLimits(overrides: Partial<Limits> = {}): Limits {
  const result={...limits,...overrides};
  for (const key of Object.keys(result) as (keyof Limits)[]) {
    if (!(key in limits) || !Number.isInteger(result[key]) || result[key]<1 || result[key]>limits[key]) throw new InventoryError('invalid_limits');
  }
  return result;
}
export function localConfig(env: NodeJS.ProcessEnv) {
  if (env.GCLOUD_PROJECT!=='demo-resqme' || (env.GOOGLE_CLOUD_PROJECT && env.GOOGLE_CLOUD_PROJECT!=='demo-resqme') || !['127.0.0.1:8080','localhost:8080'].includes(env.FIRESTORE_EMULATOR_HOST??'')) throw new InventoryError('unsafe_local_configuration');
  if (env.FIREBASE_CONFIG) {
    try {if(JSON.parse(env.FIREBASE_CONFIG).projectId!=='demo-resqme') throw new Error();} catch {throw new InventoryError('unsafe_local_configuration');}
  }
  return Object.freeze({project:'demo-resqme',origin:'http://127.0.0.1:8080'});
}
export const scopes = Object.freeze([
  {id:'profiles',collection:'studentProfiles',group:false,fields:Object.freeze(['schemaVersion','status'])},
  {id:'qa',collection:'qaTesters',group:false,fields:Object.freeze(['enabled','syntheticOnly'])},
  {id:'qr',collection:'studentQrCredentials',group:false,fields:Object.freeze(['verificationStatus'])},
  {id:'medical',collection:'studentMedicalRecords',group:false,fields:Object.freeze(['schemaVersion','syntheticOnly','medicalStatus','guardianAuthorizationStatus','revision'])},
  {id:'acknowledgments',collection:'acknowledgments',group:true,fields:Object.freeze([] as string[])},
  {id:'requests',collection:'requests',group:true,fields:Object.freeze([] as string[])},
].map(scope=>Object.freeze(scope)));
export type ScopeId = typeof scopes[number]['id'];
export function scopeFor(id: ScopeId) {
  const scope=scopes.find(s=>s.id===id);
  if(!scope) throw new InventoryError('invalid_scope');
  return scope;
}
export const documentPrefix='projects/demo-resqme/databases/(default)/documents/';
export type WireValue = {stringValue?:unknown;integerValue?:unknown;booleanValue?:unknown;[key:string]:unknown};
export interface ProjectedDocument {name:string; fields:Record<string,WireValue>;createTime?:string;updateTime?:string;}
export interface ReadTransport {
  collections(token:string|undefined,pageSize:number,signal:AbortSignal): Promise<{ids:string[];next?:string}>;
  query(scope:ScopeId,after:string|undefined,pageSize:number,signal:AbortSignal): Promise<ProjectedDocument[]>;
}
export function validName(scopeId:ScopeId,name:string): string {
  if(typeof name!=='string'||!name.startsWith(documentPrefix)||Buffer.byteLength(name)>6144) throw new InventoryError('unexpected_document_path');
  const parts=name.slice(documentPrefix.length).split('/');
  if(parts.some(p=>!p||Buffer.byteLength(p)>1500)) throw new InventoryError('unexpected_document_path');
  const scope=scopeFor(scopeId);
  const valid=!scope.group ? parts.length===2&&parts[0]===scope.collection : parts.length===4&&parts[2]===scope.collection&&(scopeId==='requests'?parts[0]==='studentMedicalRecords':['studentProfiles','studentMedicalRecords'].includes(parts[0]));
  if(!valid) throw new InventoryError('unexpected_document_path');
  return parts[1];
}
