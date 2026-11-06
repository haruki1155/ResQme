import {boundedLimits, documentPrefix, InventoryError, scopes, validName, type Limits, type ProjectedDocument, type ReadTransport, type ScopeId} from './contract';

export type Classification='TRUSTED'|'UNTRUSTED'|'UNRESOLVED';
export interface ProvenanceEvidence {source:'independent-review';authorizedCreation:boolean;changesCovered:boolean;unauthorizedChange:boolean;conflicting:boolean;reference:string;}
export function classifyEvidence(evidence?:ProvenanceEvidence):Classification {
  if(!evidence||evidence.source!=='independent-review'||!evidence.reference?.trim()||evidence.conflicting) return 'UNRESOLVED';
  if(evidence.unauthorizedChange) return 'UNTRUSTED';
  return evidence.authorizedCreation&&evidence.changesCovered?'TRUSTED':'UNRESOLVED';
}
type SafeRecord={record:string;account:string;scope:ScopeId;classification:Classification;concerns:string[]};
type PrivateRecord={path:string;scope:ScopeId;fields:Record<string,string|number|boolean>;createTime?:string;updateTime?:string};
const safeCodes=new Set(['request_timeout','overall_deadline','cancelled','permission_denied','request_failed','response_too_large','invalid_response','invalid_collection_page','invalid_query_page','projection_violation','unexpected_document_path','invalid_metadata','pagination_error','collection_limit','per_query_limit','total_limit','unsafe_projected_value']);
const enumValues:Record<string,readonly string[]>={status:['pending_guardian','pending_review'],verificationStatus:['unverified'],medicalStatus:['not_started','completed_synthetic'],guardianAuthorizationStatus:['not_verified']};
function validateFields(document:ProjectedDocument,scopeId:ScopeId) {
  const scope=scopes.find(s=>s.id===scopeId)!;
  const fields:Record<string,string|number|boolean>={};const concerns:string[]=[];
  if(Object.keys(document.fields).some(key=>!scope.fields.includes(key))) throw new InventoryError('projection_violation');
  for(const field of scope.fields) {
    const value=document.fields[field];
    if(value===undefined){concerns.push('missing_'+field);continue;}
    if(!value||typeof value!=='object'||Array.isArray(value)||Object.keys(value).length!==1) throw new InventoryError('unsafe_projected_value');
    if(enumValues[field]) {
      if(typeof value.stringValue!=='string'||!enumValues[field].includes(value.stringValue)) throw new InventoryError('unsafe_projected_value');
      fields[field]=value.stringValue;
    } else if(['enabled','syntheticOnly'].includes(field)) {
      if(typeof value.booleanValue!=='boolean') throw new InventoryError('unsafe_projected_value');
      fields[field]=value.booleanValue;
      if(field==='syntheticOnly'&&!value.booleanValue) concerns.push('not_synthetic');
    } else {
      if(typeof value.integerValue!=='string'||!/^\d{1,16}$/.test(value.integerValue)||!Number.isSafeInteger(Number(value.integerValue))) throw new InventoryError('unsafe_projected_value');
      fields[field]=Number(value.integerValue);
      if(field==='schemaVersion'&&fields[field]!==1) concerns.push('unexpected_schema_version');
    }
  }
  if(scopeId==='qa'&&fields.enabled===true)concerns.push('enabled_qa_requires_independent_review');
  return {fields,concerns};
}

export async function runInventory(transport:ReadTransport,options:{limits?:Partial<Limits>;signal?:AbortSignal;now?:()=>number}={}) {
  const cap=boundedLimits(options.limits);const now=options.now??Date.now;const start=now();
  const records:SafeRecord[]=[];const privateRecords:PrivateRecord[]=[];const aliases:Record<string,string>=Object.create(null);
  const rootCollections:string[]=[];const counts:Record<string,number>=Object.fromEntries(scopes.map(s=>[s.id,0]));
  const reasons:string[]=[];let examined=0;let unexpectedRecords=0;
  const alias=(uid:string)=>aliases[uid]??(aliases[uid]=`account-${String(Object.keys(aliases).length+1).padStart(3,'0')}`);
  const within=async<T>(operation:(signal:AbortSignal)=>Promise<T>):Promise<T>=>{
    if(options.signal?.aborted) throw new InventoryError('cancelled');
    const remaining=cap.overallMs-(now()-start);if(remaining<=0)throw new InventoryError('overall_deadline');
    const abort=new AbortController();let timer:ReturnType<typeof setTimeout>|undefined;let rejectAbort:(error:Error)=>void=()=>{};
    const cancel=()=>{abort.abort();rejectAbort(new InventoryError('cancelled'));};
    const cancelled=new Promise<never>((_,reject)=>{rejectAbort=reject;options.signal?.addEventListener('abort',cancel,{once:true});});
    const timeout=new Promise<never>((_,reject)=>{timer=setTimeout(()=>{abort.abort();reject(new InventoryError(remaining<=cap.requestMs?'overall_deadline':'request_timeout'));},Math.min(remaining,cap.requestMs));});
    try {const result=await Promise.race([Promise.resolve().then(()=>operation(abort.signal)),timeout,cancelled]);if(now()-start>=cap.overallMs)throw new InventoryError('overall_deadline');return result;}
    finally {if(timer)clearTimeout(timer);options.signal?.removeEventListener('abort',cancel);abort.abort();}
  };
  try {
    let token:string|undefined;const seenTokens=new Set<string>();const seenIds=new Set<string>();
    do {
      const size=Math.min(cap.pageSize,cap.collections-rootCollections.length);
      const page=await within(signal=>transport.collections(token,size,signal));
      if(page.ids.length>size||(!page.ids.length&&page.next))throw new InventoryError('pagination_error');
      for(const id of page.ids){if(typeof id!=='string'||!id||id.includes('/')||Buffer.byteLength(id)>1500||seenIds.has(id))throw new InventoryError('pagination_error');seenIds.add(id);rootCollections.push(id);}
      if(rootCollections.length>=cap.collections)throw new InventoryError('collection_limit');
      token=page.next;if(token){if(seenTokens.has(token))throw new InventoryError('pagination_error');seenTokens.add(token);}
    }while(token);
    for(const scope of scopes) {
      let cursor:string|undefined;let read=0;
      while(true){
        const size=Math.min(cap.pageSize,cap.perQuery-read,cap.total-examined);
        const page=await within(signal=>transport.query(scope.id,cursor,size,signal));
        if(page.length>size)throw new InventoryError('pagination_error');
        for(const document of page){
          const uid=validName(scope.id,document.name);
          if(cursor&&Buffer.compare(Buffer.from(document.name),Buffer.from(cursor))<=0)throw new InventoryError('pagination_error');
          cursor=document.name;read++;examined++;counts[scope.id]++;
          const summary:SafeRecord={record:`record-${String(examined).padStart(4,'0')}`,account:alias(uid),scope:scope.id,classification:classifyEvidence(),concerns:[]};records.push(summary);
          try {
            const validated=validateFields(document,scope.id);summary.concerns=validated.concerns;
            if(validated.concerns.some(c=>c.startsWith('missing_')||c==='unexpected_schema_version'))unexpectedRecords++;
            privateRecords.push({path:document.name.slice(documentPrefix.length),scope:scope.id,fields:validated.fields,...(document.createTime?{createTime:document.createTime}:{}),...(document.updateTime?{updateTime:document.updateTime}:{})});
          }catch(error){unexpectedRecords++;summary.concerns=['unsafe_projected_field_suppressed'];throw error;}
        }
        if(examined>=cap.total)throw new InventoryError('total_limit');
        if(read>=cap.perQuery)throw new InventoryError('per_query_limit');
        if(page.length<size)break;
      }
    }
  }catch(error){reasons.push(error instanceof InventoryError&&safeCodes.has(error.code)?error.code:'request_failed');}
  const profiles=new Set(privateRecords.filter(r=>r.scope==='profiles').map(r=>r.path.split('/')[1]));
  const consistency: {account:string;scope:ScopeId;issue:string}[]=[];
  for(const record of privateRecords){const uid=record.path.split('/')[1];if(record.scope!=='profiles'&&!profiles.has(uid))consistency.push({account:alias(uid),scope:record.scope,issue:'missing_profile'});}
  const finished=now();
  const report={status:reasons.length?(examined||rootCollections.length?'INCOMPLETE':'FAILED'):'COMPLETE',startedAt:new Date(start).toISOString(),finishedAt:new Date(finished).toISOString(),examined,counts,unresolved:records.filter(r=>r.classification==='UNRESOLVED').length,unexpectedRecords,consistency,unknownRootCollections:rootCollections.filter(id=>!scopes.some(s=>!s.group&&s.collection===id)).length,reasons,limits:cap,records,coverage:['Only approved root projections and acknowledgment/request collection groups were queried.','Unknown nested collections are not discovered; root discovery is not exhaustive nested discovery.','Multi-query reads are not an atomic snapshot.','Missing provenance remains unresolved; completeness is not authorization clearance.'],recommendedNextSteps:['Independent operator provenance review requires separate authorization.','Approve exact G2-B remediation separately; G3 and G4 remain blocked.'],clearance:'NOT_GRANTED',g2Complete:false,g2BRemediationPerformed:false};
  return {report,privateEvidence:{rootCollections,records:privateRecords,aliases}};
}
