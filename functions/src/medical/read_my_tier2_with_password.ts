import {HttpsError,onCall} from 'firebase-functions/v2/https';
import {FieldValue,Timestamp} from 'firebase-admin/firestore';
import {onboardingDatabase,resqmeRuntimeOptions} from '../onboarding/authorization';
import {requireRecentAuth,requireTier2Eligible,sanitizeTier2Record} from './tier2_challenge';
import {keys,object} from './medical_contract';

export const readMyTier2WithPassword=onCall(resqmeRuntimeOptions,async request=>{
  const uid=request.auth?.uid,db=onboardingDatabase(uid);
  requireRecentAuth(request.auth?.token.auth_time,Math.floor(Date.now()/1000),120);
  keys(object(request.data),[]);
  const rate=db.doc(`tier2PasswordRateLimits/${uid}`),now=Date.now(),windowMs=10*60_000;
  await db.runTransaction(async tx=>{
    const snapshot=await tx.get(rate);
    const started=snapshot.get('windowStartedAt');
    const attempts=snapshot.get('attempts');
    const sameWindow=started instanceof Timestamp&&now-started.toMillis()<windowMs;
    const count=sameWindow&&Number.isSafeInteger(attempts)?Number(attempts):0;
    if(count>=5) throw new HttpsError('resource-exhausted','Try Tier 2 again later.');
    tx.set(rate,{windowStartedAt:sameWindow?started:Timestamp.fromMillis(now),attempts:count+1,updatedAt:FieldValue.serverTimestamp()});
  });
  const [profile,medical]=await Promise.all([db.doc(`studentProfiles/${uid}`).get(),db.doc(`studentMedicalRecords/${uid}`).get()]);
  requireTier2Eligible(profile.data(),medical.data());
  if(!medical.exists) throw new HttpsError('permission-denied','Tier 2 access is unavailable.');
  return sanitizeTier2Record(medical.data());
});
