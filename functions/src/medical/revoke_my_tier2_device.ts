import {randomBytes} from 'node:crypto';
import {FieldValue} from 'firebase-admin/firestore';
import {HttpsError,onCall} from 'firebase-functions/v2/https';
import {isStudentAccountDisabled,onboardingDatabase,resqmeRuntimeOptions} from '../onboarding/authorization';
import {requireRecentAuth} from './tier2_challenge';
import {keys,object} from './medical_contract';

export const revokeMyTier2Device=onCall(resqmeRuntimeOptions,async request=>{
  const uid=request.auth?.uid,db=onboardingDatabase(uid);
  requireRecentAuth(request.auth?.token.auth_time,Math.floor(Date.now()/1000),120);
  const data=object(request.data ?? {});
  keys(data,['deviceId']);
  const requestedDeviceId=data.deviceId;
  if(requestedDeviceId!==undefined&&requestedDeviceId!==null&&(typeof requestedDeviceId!=='string'||!/^[A-Za-z0-9_-]{20,80}$/.test(requestedDeviceId))) {
    throw new HttpsError('invalid-argument','Invalid device identifier.');
  }
  const profile=db.doc(`studentProfiles/${uid}`);
  const device=db.doc(`tier2Devices/${uid}`);
  await db.runTransaction(async tx=>{
    const [profileSnap,current]=await Promise.all([tx.get(profile),tx.get(device)]);
    const pData=profileSnap.data();
    if(isStudentAccountDisabled(pData)) throw new HttpsError('permission-denied','Student account is disabled.');
    if(current.exists&&current.get('status')==='active') {
      const enrolledDeviceId=current.get('deviceId');
      if(typeof enrolledDeviceId==='string'&&enrolledDeviceId.length>0&&requestedDeviceId!==enrolledDeviceId) {
        throw new HttpsError(
          'permission-denied',
          'Only the enrolled personal device or school-verified recovery can disable biometric device binding.',
        );
      }
      const priorTokenHash=current.get('activePresentationTokenHash');
      if(typeof priorTokenHash==='string'&&priorTokenHash.length===64) {
        tx.set(
          db.doc(`studentTier2PresentationTokens/${priorTokenHash}`),
          {status:'revoked',revokedAt:FieldValue.serverTimestamp()},
          {merge:true},
        );
      }
      tx.update(device,{
        status:'revoked',
        activePresentationTokenHash:null,
        revokedAt:FieldValue.serverTimestamp(),
      });
      if(pData?.schoolAssignmentStatus==='assigned'&&typeof pData.schoolId==='string'&&pData.schoolId.length>=2) {
        tx.create(db.doc(`staffManagementAudits/${randomBytes(16).toString('hex')}`),{
          actorUid:uid,
          actorRole:'student',
          schoolId:pData.schoolId,
          action:'revoke_student_trusted_device',
          targetUid:uid,
          outcome:'allowed',
          createdAt:FieldValue.serverTimestamp(),
        });
      }
    }
  });
  return {status:'revoked'};
});
