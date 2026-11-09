import {createHash} from 'node:crypto';
import {FieldValue} from 'firebase-admin/firestore';
import {HttpsError,onCall} from 'firebase-functions/v2/https';
import {onboardingDatabase,requirePending,resqmeRuntimeOptions} from '../onboarding/authorization';
import {validateMedicalCompletion} from './medical_contract';

export const completeMyMedicalRecord=onCall(resqmeRuntimeOptions,async request=>{
  const uid=request.auth?.uid;
  const db=onboardingDatabase(uid);
  const input=validateMedicalCompletion(request.data);
  const digest=createHash('sha256').update(JSON.stringify(input)).digest('hex');
  const profile=db.doc(`studentProfiles/${uid}`);
  const record=db.doc(`studentMedicalRecords/${uid}`);
  const receipt=record.collection('productionRequests').doc(input.requestId);
  const result=await db.runTransaction(async tx=>{
    const [profileSnapshot,recordSnapshot,replay]=await Promise.all([
      tx.get(profile),tx.get(record),tx.get(receipt),
    ]);
    const owner=requirePending(profileSnapshot.data());
    if(recordSnapshot.get('syntheticOnly')===true) throw new HttpsError('failed-precondition','Medical information needs to be completed through the approved form.');
    if(replay.exists){
      if(replay.get('digest')!==digest) throw new HttpsError('already-exists','Request ID already used.');
      return {revision:replay.get('revision') as number};
    }
    if(['approved','revoked'].includes(owner.schoolApprovalStatus)) throw new HttpsError('failed-precondition','Contact your school to update medical information.');
    const current=Number.isSafeInteger(owner.medicalRevision)?owner.medicalRevision:0;
    if(recordSnapshot.exists&&recordSnapshot.get('syntheticOnly')!==true&&recordSnapshot.get('revision')!==current) {
      throw new HttpsError('failed-precondition','Medical information changed. Reload before saving.');
    }
    if(current!==input.expectedRevision) throw new HttpsError('failed-precondition','Medical information changed. Reload before saving.');
    const revision=current+1;
    tx.set(record,{
      schemaVersion:1,medicalStatus:'complete',selfReported:true,
      conditions:input.conditions,allergies:input.allergies,
      primaryContact:input.primaryContact,
      revision,updatedAt:FieldValue.serverTimestamp(),
    });
    tx.update(profile,{
      medicalStatus:'complete',updatedAt:FieldValue.serverTimestamp(),
      medicalRevision:revision,
    });
    tx.create(receipt.collection('acknowledgments').doc('self-report-v1'),{
      version:'self-report-v1',actorUid:uid,confirmed:true,recordedAt:FieldValue.serverTimestamp(),
    });
    tx.create(receipt,{digest,revision,recordedAt:FieldValue.serverTimestamp()});
    return {revision};
  });
  return {medicalStatus:'complete',revision:result.revision};
});
