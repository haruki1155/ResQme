import {createInterface} from 'node:readline/promises';
import {stdin as input, stdout as output} from 'node:process';
import {initializeApp} from 'firebase-admin/app';
import {getAuth} from 'firebase-admin/auth';
import {getFirestore} from 'firebase-admin/firestore';
import {provisionMasterAdmin} from '../src/staff/master_admin_provisioning';

const APPROVED_STAGING_PROJECT = 'resqme-943ee';

async function main(): Promise<void> {
  const projectId = process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT || APPROVED_STAGING_PROJECT;
  if (projectId !== APPROVED_STAGING_PROJECT && projectId !== 'demo-resqme') {
    throw new Error(`Refusing to run against unapproved project "${projectId}".`);
  }
  if (!input.isTTY) {
    throw new Error('Interactive TTY confirmation is required to provision a Master Admin.');
  }

  const rl = createInterface({input, output});
  try {
    const email = (await rl.question('Designated Master Admin email: ')).trim();
    const schoolId = (await rl.question('Trusted school ID (e.g. school-alpha): ')).trim();
    const fullName = (await rl.question('Full name [Master Administrator]: ')).trim() || 'Master Administrator';
    const confirm = (
      await rl.question(
        `Type PROVISION ${projectId} to create Master Admin "${email}" for school "${schoolId}": `,
      )
    ).trim();
    if (confirm !== `PROVISION ${projectId}`) {
      console.log('Cancelled. No changes were made.');
      return;
    }

    const app = initializeApp({projectId}, 'resqme-master-admin-provisioner');
    const adminAuth = getAuth(app);
    const firestore = getFirestore(app);

    const result = await provisionMasterAdmin({
      auth: {
        createUser: (u) => adminAuth.createUser(u),
        deleteUser: (uid) => adminAuth.deleteUser(uid),
      },
      db: {
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
      },
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
