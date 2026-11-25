import {createHash,randomBytes} from 'node:crypto';
import {FieldValue,Timestamp} from 'firebase-admin/firestore';
import {HttpsError,onCall} from 'firebase-functions/v2/https';
import {onboardingDatabase,resqmeRuntimeOptions} from '../onboarding/authorization';
import {
  STUDENT_ENROLLMENT_PROOF_VERSION,
  requireRecentAuth,
  requireTier2Eligible,
  studentEnrollmentSignedMessage,
  validateDeviceEnrollment,
  verifyTier2Signature,
} from './tier2_challenge';

export function hashTrustedDeviceTransferCode(code:string):string {
  return createHash('sha256').update(`transfer:${code.trim().toUpperCase()}`,'utf8').digest('hex');
}

export const enrollTier2Device=onCall(resqmeRuntimeOptions,async request=>{
  const uid=request.auth?.uid,db=onboardingDatabase(uid);
  requireRecentAuth(request.auth?.token.auth_time,undefined,120);
  const input=validateDeviceEnrollment(request.data);
  const device=db.doc(`tier2Devices/${uid}`);
  const challengeRef=db.doc(`tier2EnrollmentChallenges/${input.challengeId}`);
  const grantRef=input.transferCode
    ? db.doc(`studentDeviceTransferGrants/${hashTrustedDeviceTransferCode(input.transferCode)}`)
    : null;
  const keyVersion=await db.runTransaction(async tx=>{
    const [profile,medical,guardian,old,challengeSnap,grantSnap]=await Promise.all([
      tx.get(db.doc(`studentProfiles/${uid}`)),
      tx.get(db.doc(`studentMedicalRecords/${uid}`)),
      tx.get(db.doc(`studentGuardianAuthorizations/${uid}`)),
      tx.get(device),
      tx.get(challengeRef),
      grantRef ? tx.get(grantRef) : Promise.resolve(null),
    ]);
    requireTier2Eligible(profile.data(),medical.data(),{uid:uid!,guardianAuthorization:guardian.data()});

    const oldActiveDeviceId=old.exists&&old.get('status')==='active'&&typeof old.get('deviceId')==='string'
      ? (old.get('deviceId') as string)
      : null;
    const isReplacingDifferentActiveDevice=Boolean(oldActiveDeviceId&&oldActiveDeviceId!==input.deviceId);
    if(isReplacingDifferentActiveDevice) {
      if(!grantRef||!grantSnap?.exists) {
        throw new HttpsError(
          'failed-precondition',
          'Another personal device is already enrolled for biometric Tier 2 access. Approve replacement from your existing trusted device or request school-verified recovery.',
        );
      }
      const grant=grantSnap.data();
      const grantExpires=grant?.expiresAt;
      const grantExpiresMs=grantExpires instanceof Timestamp
        ? grantExpires.toMillis()
        : grantExpires instanceof Date
          ? grantExpires.getTime()
          : 0;
      if(
        !grant||
        grant.uid!==uid||
        grant.fromDeviceId!==oldActiveDeviceId||
        grant.consumedAt!=null||
        grantExpiresMs<=Date.now()
      ) {
        throw new HttpsError(
          'permission-denied',
          'Trusted-device replacement approval is invalid or expired.',
        );
      }
    }

    const challenge=challengeSnap.data();
    const expiresAt=challenge?.expiresAt;
    const expiresMs=expiresAt instanceof Timestamp
      ? expiresAt.toMillis()
      : expiresAt instanceof Date
        ? expiresAt.getTime()
        : 0;
    if(!challengeSnap.exists||!challenge||challenge.uid!==uid||challenge.consumedAt!=null||typeof challenge.nonce!=='string'||expiresMs<=Date.now()) {
      throw new HttpsError('permission-denied','Biometric enrollment challenge is invalid or expired.');
    }
    const expectedMessage=studentEnrollmentSignedMessage({
      uid:uid!,
      deviceId:input.deviceId,
      challengeId:input.challengeId,
      nonce:challenge.nonce,
    });
    if(!verifyTier2Signature(input.publicKey,expectedMessage,input.signature)) {
      throw new HttpsError('permission-denied','Biometric enrollment proof could not be verified.');
    }
    const nextVersion=Number(old.get('keyVersion')||0)+1;
    tx.update(challengeRef,{consumedAt:FieldValue.serverTimestamp()});
    if(isReplacingDifferentActiveDevice&&grantRef) {
      tx.update(grantRef,{
        consumedAt:FieldValue.serverTimestamp(),
        replacedByDeviceId:input.deviceId,
      });
    }
    const priorTokenHash=old.exists?old.get('activePresentationTokenHash'):null;
    if(typeof priorTokenHash==='string'&&priorTokenHash.length===64) {
      tx.set(
        db.doc(`studentTier2PresentationTokens/${priorTokenHash}`),
        {status:'revoked',revokedAt:FieldValue.serverTimestamp()},
        {merge:true},
      );
    }
    tx.set(device,{
      deviceId:input.deviceId,
      publicKey:input.publicKey,
      status:'active',
      enrollmentProofVersion:STUDENT_ENROLLMENT_PROOF_VERSION,
      keyVersion:nextVersion,
      activePresentationTokenHash:null,
      ...(isReplacingDifferentActiveDevice?{replacedPreviousDeviceId:oldActiveDeviceId}:{}),
      enrolledAt:FieldValue.serverTimestamp(),
    });
    const pData=profile.data();
    if(pData?.schoolAssignmentStatus==='assigned'&&typeof pData.schoolId==='string'&&pData.schoolId.length>=2) {
      tx.create(db.doc(`staffManagementAudits/${randomBytes(16).toString('hex')}`),{
        actorUid:uid,
        actorRole:'student',
        schoolId:pData.schoolId,
        action:isReplacingDifferentActiveDevice?'replace_student_trusted_device':'enroll_student_trusted_device',
        targetUid:uid,
        outcome:'allowed',
        createdAt:FieldValue.serverTimestamp(),
      });
    }
    return nextVersion;
  });
  return {
    deviceId:input.deviceId,
    status:'active',
    keyVersion,
    enrollmentProofVersion:STUDENT_ENROLLMENT_PROOF_VERSION,
  };
});
