import {createInterface} from 'node:readline/promises';
import {stdin as input, stdout as output} from 'node:process';
import {initializeApp} from 'firebase-admin/app';
import {getAuth} from 'firebase-admin/auth';
import {getFirestore} from 'firebase-admin/firestore';
import {
  provisionExistingMasterAdmin,
  provisionMasterAdmin,
  type MasterAdminFirestoreAdapter,
} from '../src/staff/master_admin_provisioning';

const APPROVED_STAGING_PROJECT = 'resqme-943ee';

function makeFirestoreAdapter(firestore: FirebaseFirestore.Firestore): MasterAdminFirestoreAdapter {
  return {
    runTransaction: (fn) =>
      firestore.runTransaction(async (tx) =>
        fn({
          get: async (path) => {
            const snap = await tx.get(firestore.doc(path));
            return {exists: snap.exists, data: () => snap.data()};
          },
          create: (path, data) => {
            tx.create(firestore.doc(path), data);
          },
        }),
      ),
  };
}

async function main(): Promise<void> {
  const projectId =
    process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT || APPROVED_STAGING_PROJECT;
  if (projectId !== APPROVED_STAGING_PROJECT && projectId !== 'demo-resqme') {
    throw new Error(`Refusing to run against unapproved project "${projectId}".`);
  }
  if (!input.isTTY) {
    throw new Error('Interactive TTY confirmation is required to provision a Master Admin.');
  }

  const useExistingMode = process.argv.includes('--existing');
  const rl = createInterface({input, output});
  try {
    const app = initializeApp({projectId}, 'resqme-master-admin-provisioner');
    const adminAuth = getAuth(app);
    const firestore = getFirestore(app);
    const db = makeFirestoreAdapter(firestore);

    if (useExistingMode) {
      const email = (await rl.question('Existing Firebase Auth email: ')).trim().toLowerCase();
      const user = await adminAuth.getUserByEmail(email);
      console.log('');
      console.log('Resolved existing Firebase Auth user:');
      console.log(`  UID:            ${user.uid}`);
      console.log(`  Email:          ${user.email ?? email}`);
      console.log(`  Email Verified: ${user.emailVerified}`);
      console.log(`  Disabled:       ${user.disabled}`);
      console.log('');

      const expectedUid = (await rl.question('Re-type the exact Firebase UID to confirm: ')).trim();
      const schoolId = (await rl.question('Permanent trusted school ID (not qa*/synthetic*): ')).trim();
      const fullName =
        (await rl.question('Full name [Master Administrator]: ')).trim() || 'Master Administrator';
      const confirm = (
        await rl.question(
          `Type PROVISION EXISTING ${projectId} ${user.uid} to grant Master Admin for school "${schoolId}": `,
        )
      ).trim();
      if (confirm !== `PROVISION EXISTING ${projectId} ${user.uid}`) {
        console.log('Cancelled. No changes were made.');
        return;
      }

      const result = await provisionExistingMasterAdmin({
        auth: {
          getUserByEmail: async (e) => {
            const u = await adminAuth.getUserByEmail(e);
            return {
              uid: u.uid,
              email: u.email,
              emailVerified: u.emailVerified,
              disabled: u.disabled,
            };
          },
          revokeRefreshTokens: (uid) => adminAuth.revokeRefreshTokens(uid),
        },
        db,
        email,
        expectedUid,
        schoolId,
        fullName,
      });

      console.log('');
      console.log('Existing Firebase Auth account provisioned as Master Admin.');
      console.log(`  Project:        ${projectId}`);
      console.log(`  UID:            ${result.uid}`);
      console.log(`  Email:          ${result.email}`);
      console.log(`  School:         ${result.schoolId}`);
      console.log(`  Email Verified: ${result.emailVerified}`);
      console.log('');
      console.log('Pre-existing sessions have been invalidated. Sign in fresh on ResQMe Portal.');
      if (!result.emailVerified) {
        console.log('Email verification is required in ResQMe Portal before privileged actions unlock.');
      }
      return;
    }

    const email = (await rl.question('Designated Master Admin email: ')).trim();
    const schoolId = (await rl.question('Permanent trusted school ID: ')).trim();
    const fullName =
      (await rl.question('Full name [Master Administrator]: ')).trim() || 'Master Administrator';
    const confirm = (
      await rl.question(
        `Type PROVISION ${projectId} to create Master Admin "${email}" for school "${schoolId}": `,
      )
    ).trim();
    if (confirm !== `PROVISION ${projectId}`) {
      console.log('Cancelled. No changes were made.');
      return;
    }

    const result = await provisionMasterAdmin({
      auth: {
        createUser: (u) => adminAuth.createUser(u),
        deleteUser: (uid) => adminAuth.deleteUser(uid),
      },
      db,
      email,
      schoolId,
      fullName,
    });

    console.log('');
    console.log('Master Admin provisioned successfully.');
    console.log(`  Project:  ${projectId}`);
    console.log(`  UID:      ${result.uid}`);
    console.log(`  Email:    ${result.email}`);
    console.log(`  School:   ${result.schoolId}`);
    console.log(`  One-time initial password: ${result.initialPassword}`);
    console.log('');
    console.log('IMPORTANT: Record this initial password securely now. It is not stored anywhere.');
    console.log('The Master Admin must change this password and verify their email on first sign-in.');
  } finally {
    rl.close();
  }
}

main().catch((err) => {
  console.error('Master Admin provisioning failed:', err instanceof Error ? err.message : String(err));
  process.exit(1);
});
