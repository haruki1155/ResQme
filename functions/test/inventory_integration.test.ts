import assert from 'node:assert/strict';
import test from 'node:test';
import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
import {resolve} from 'node:path';
import {readFile} from 'node:fs/promises';
import {initializeTestEnvironment,type RulesTestEnvironment} from '@firebase/rules-unit-testing';
import {deleteDoc,doc,setDoc} from 'firebase/firestore';
import {localConfig,scopes} from '../tools/g2_inventory/contract';
import {LocalFirestoreTransport} from '../tools/g2_inventory/transport';
import {runInventory} from '../tools/g2_inventory/inventory';

const sentinel='FORBIDDEN_SYNTHETIC_NAME_CONTACT_MEDICAL_QR_TOKEN';
let environment:RulesTestEnvironment;
const fixtures=[
 ['studentProfiles/g2a-private-owner',{schemaVersion:1,status:'pending_review',fullName:sentinel,email:sentinel,ageYearsAtRegistration:18}],
 ['qaTesters/g2a-private-owner',{enabled:true,syntheticOnly:true,secret:sentinel}],
 ['studentQrCredentials/g2a-private-owner',{verificationStatus:'unverified',payload:sentinel}],
 ['studentMedicalRecords/g2a-private-owner',{schemaVersion:1,syntheticOnly:true,medicalStatus:'completed_synthetic',guardianAuthorizationStatus:'not_verified',revision:1,conditions:sentinel,allergies:sentinel}],
 ['studentProfiles/g2a-absent-parent/acknowledgments/g2a-notice',{fullName:sentinel}],
 ['studentMedicalRecords/g2a-private-owner/requests/g2a-request',{digest:sentinel}],
 ['g2aUnknown/g2a-document',{secret:sentinel}],
] as const;

test.before(async()=>{
 localConfig(process.env);
 environment=await initializeTestEnvironment({projectId:'demo-resqme',firestore:{host:'127.0.0.1',port:8080}});
 await environment.withSecurityRulesDisabled(async c=>{for(const [path,data] of fixtures)await setDoc(doc(c.firestore(),path),data);});
});
test.after(async()=>{
 if(environment){await environment.withSecurityRulesDisabled(async c=>{for(const [path] of fixtures)await deleteDoc(doc(c.firestore(),path));await deleteDoc(doc(c.firestore(),'g2aUnknown/g2a-document/acknowledgments/g2a-unexpected'));});await environment.cleanup();}
});

test('emulator applies every field projection and reference-only select before retrieval',{timeout:15000},async()=>{
 const transport=new LocalFirestoreTransport(process.env);
 for(const scope of scopes){const rows=await transport.query(scope.id,undefined,100,new AbortController().signal);assert.ok(!JSON.stringify(rows).includes(sentinel));if(scope.group)assert.ok(rows.every(r=>Object.keys(r.fields).length===0));}
 const result=await runInventory(transport,{limits:{pageSize:2}});
 assert.equal(result.report.status,'COMPLETE');
 assert.ok(result.privateEvidence.records.some(r=>r.path==='studentProfiles/g2a-absent-parent/acknowledgments/g2a-notice'));
 assert.ok(!JSON.stringify(result).includes(sentinel));assert.ok(!JSON.stringify(result.report).includes('g2a-private-owner'));
 assert.equal(result.report.g2Complete,false);
});

test('local CLI emits sanitized report and writes only synthetic temporary private evidence',{timeout:20000},async()=>{
 const {stdout,stderr}=await promisify(execFile)(process.execPath,[resolve(__dirname,'../tools/g2_inventory/runner.js')],{env:process.env,timeout:15000});
 assert.equal(stderr,'');assert.ok(!stdout.includes(sentinel));assert.ok(!stdout.includes('g2a-private-owner'));
 const output=JSON.parse(stdout);assert.equal(output.report.status,'COMPLETE');assert.equal(output.report.clearance,'NOT_GRANTED');
 assert.ok(!resolve(output.evidenceDirectory).startsWith(resolve(__dirname,'../../..')));
 const privateData=await readFile(resolve(output.evidenceDirectory,'private-synthetic-evidence.json'),'utf8');
 assert.ok(!privateData.includes(sentinel));assert.ok(privateData.includes('g2a-private-owner'));
});

test('unexpected collection-group paths stop inventory without retrieving content',{timeout:15000},async()=>{
 await environment.withSecurityRulesDisabled(c=>setDoc(doc(c.firestore(),'g2aUnknown/g2a-document/acknowledgments/g2a-unexpected'),{secret:sentinel}));
 const result=await runInventory(new LocalFirestoreTransport(process.env));
 assert.equal(result.report.status,'INCOMPLETE');assert.ok(result.report.reasons.includes('unexpected_document_path'));
 assert.ok(!JSON.stringify(result).includes(sentinel));
});
