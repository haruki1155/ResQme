import {FieldValue,Timestamp} from 'firebase-admin/firestore';
import {HttpsError,onCall} from 'firebase-functions/v2/https';
import {onboardingDatabase,resqmeRuntimeOptions} from '../onboarding/authorization';
import {
  STUDENT_ENROLLMENT_PROOF_VERSION,
  requireRecentAuth,
  requireTier2Eligible,
  tier2RevealIdentityOperation,
  tier2SignedMessage,
  validateProof,
  verifyTier2Signature,
} from './tier2_challenge';

function extractSurname(fullName: unknown): string {
  if (typeof fullName !== 'string') return '';
  const parts = fullName.trim().split(/\s+/).filter(Boolean);
  return parts.length > 0 ? parts[parts.length - 1] : '';
}

export const revealMyStudentIdentity=onCall(resqmeRuntimeOptions,async request=>{
  const uid=request.auth?.uid,db=onboardingDatabase(uid);
  requireRecentAuth(request.auth?.token.auth_time);
  const input=validateProof(request.data);
  const profile=db.doc(`studentProfiles/${uid}`),
    medical=db.doc(`studentMedicalRecords/${uid}`),
    guardian=db.doc(`studentGuardianAuthorizations/${uid}`),
    device=db.doc(`tier2Devices/${uid}`),
    challenge=db.doc(`tier2Challenges/${input.challengeId}`);
  return db.runTransaction(async tx=>{
    const [p,m,g,d,c]=await Promise.all([
      tx.get(profile),
      tx.get(medical),
      tx.get(guardian),
      tx.get(device),
      tx.get(challenge),
    ]);
    requireTier2Eligible(p.data(),m.data(),{uid:uid!,guardianAuthorization:g.data()});
    const challengeData=c.data();
    if(
      !d.exists||
      d.get('deviceId')!==input.deviceId||
      d.get('status')!=='active'||
      !challengeData||
      challengeData.uid!==uid||
      challengeData.deviceId!==input.deviceId||
      challengeData.operation!==tier2RevealIdentityOperation||
      challengeData.consumedAt!=null||
      !(challengeData.expiresAt instanceof Timestamp)||
      challengeData.expiresAt.toMillis()<=Date.now()
    ) {
      throw new HttpsError('permission-denied','Identity reveal is unavailable.');
    }
    if(d.get('enrollmentProofVersion')!==STUDENT_ENROLLMENT_PROOF_VERSION) {
      throw new HttpsError('failed-precondition','Biometric security setup is required.');
    }
    const message=tier2SignedMessage({
      uid:uid!,
      deviceId:input.deviceId,
      operation:tier2RevealIdentityOperation,
      challengeId:input.challengeId,
      nonce:challengeData.nonce as string,
    });
    if(!verifyTier2Signature(d.get('publicKey') as string,message,input.signature)) {
      throw new HttpsError('permission-denied','Identity reveal is unavailable.');
    }
    tx.update(challenge,{consumedAt:FieldValue.serverTimestamp()});
    const fullName=typeof p.get('fullName')==='string'?String(p.get('fullName')).trim():'';
    const lrn=typeof p.get('lrn')==='string'?String(p.get('lrn')).trim():'';
    return {
      fullName,
      surname: extractSurname(fullName),
      lrn,
    };
  });
});
