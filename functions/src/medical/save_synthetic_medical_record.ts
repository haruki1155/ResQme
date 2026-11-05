import {createHash} from 'node:crypto';
import {FieldValue} from 'firebase-admin/firestore';
import {HttpsError,onCall,CallableRequest} from 'firebase-functions/v2/https';
import {contact,keys,object,revisionRequest,validateMedicalSave} from './medical_contract';
import {onboardingDatabase,requirePending} from '../onboarding/authorization';

async function mutate(request:CallableRequest,clear:boolean) {
  const uid=request.auth?.uid;
  const db=onboardingDatabase(uid);
  const input=clear ? (()=>{const data=object(request.data);keys(data,['expectedRevision','requestId']);return revisionRequest(data);})() : validateMedicalSave(request.data);
  const digest=createHash('sha256').update(JSON.stringify({clear,input})).digest('hex');
  const profile=db.doc(`studentProfiles/${uid}`),record=db.doc(`studentMedicalRecords/${uid}`),receipt=record.collection('requests').doc(input.requestId);
  return db.runTransaction(async tx=>{
    const [profileSnapshot,recordSnapshot,replay,qa]=await Promise.all([tx.get(profile),tx.get(record),tx.get(receipt),tx.get(db.doc(`qaTesters/${uid}`))]);
    if(qa.get('enabled')!==true||qa.get('syntheticOnly')!==true) throw new HttpsError('permission-denied','Test record saving is not enabled for this account.');
    const owner=requirePending(profileSnapshot.data());
    if(replay.exists){if(replay.get('digest')!==digest) throw new HttpsError('already-exists','Request ID already used.');return {revision:replay.get('revision'),medicalStatus:replay.get('medicalStatus')};}
    const revision=recordSnapshot.exists?recordSnapshot.get('revision'):0;
    if(revision!==input.expectedRevision) throw new HttpsError('failed-precondition','Record changed. Reload before saving.');
    let save:ReturnType<typeof validateMedicalSave>|undefined;
    if(!clear){
      save=input as ReturnType<typeof validateMedicalSave>;
      if(owner.ageYearsAtRegistration<18&&!save.acknowledgment.minorNoticeAcknowledged) throw new HttpsError('invalid-argument','Acknowledge that guardian authorization is not verified.');
      if(save.emergencyContact){
        const current=contact(owner.emergencyContacts?.primary??{});
        if(JSON.stringify(current)!==JSON.stringify(save.expectedContact)) throw new HttpsError('failed-precondition','Emergency contact changed. Reload before saving.');
        tx.update(profile,{'emergencyContacts.primary':save.emergencyContact,updatedAt:FieldValue.serverTimestamp()});
      }
    }
    const medicalStatus=clear?'not_started':'completed_synthetic';
    tx.set(record,{schemaVersion:1,syntheticOnly:true,medicalStatus,guardianAuthorizationStatus:'not_verified',revision:revision+1,updatedAt:FieldValue.serverTimestamp(),...(save?{conditions:save.conditions,allergies:save.allergies}:{})});
    tx.create(receipt,{digest,revision:revision+1,medicalStatus,recordedAt:FieldValue.serverTimestamp()});
    tx.create(record.collection('acknowledgments').doc(input.requestId),{version:'synthetic-medical-v1',action:clear?'clear':'save',actorUid:uid,syntheticDataConfirmed:!clear,minorNoticeAcknowledged:save?.acknowledgment.minorNoticeAcknowledged??false,guardianAuthorizationStatus:'not_verified',recordedAt:FieldValue.serverTimestamp()});
    return {revision:revision+1,medicalStatus};
  });
}
export const saveMySyntheticMedicalRecord=onCall(request=>mutate(request,false));
export const clearMySyntheticMedicalRecord=onCall(request=>mutate(request,true));
