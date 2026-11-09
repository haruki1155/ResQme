import {FieldValue} from 'firebase-admin/firestore';
import {HttpsError,onCall} from 'firebase-functions/v2/https';
import {onboardingDatabase,resqmeRuntimeOptions} from '../onboarding/authorization';
import {requireRecentAuth,requireTier2Eligible,validateDeviceEnrollment} from './tier2_challenge';

export const enrollTier2Device=onCall(resqmeRuntimeOptions,async request=>{
  const uid=request.auth?.uid,db=onboardingDatabase(uid);
  requireRecentAuth(request.auth?.token.auth_time);
  const input=validateDeviceEnrollment(request.data);
  const [profile,medical]=await Promise.all([db.doc(`studentProfiles/${uid}`).get(),db.doc(`studentMedicalRecords/${uid}`).get()]);
  requireTier2Eligible(profile.data(),medical.data());
  const device=db.doc(`tier2Devices/${uid}`);
  await db.runTransaction(async tx=>{
    const old=await tx.get(device);
    tx.set(device,{deviceId:input.deviceId,publicKey:input.publicKey,status:'active',keyVersion:Number(old.get('keyVersion')||0)+1,enrolledAt:FieldValue.serverTimestamp()});
  });
  return {deviceId:input.deviceId,status:'active'};
});
