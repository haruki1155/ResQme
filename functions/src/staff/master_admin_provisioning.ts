import {randomBytes} from 'node:crypto';
import {FieldValue} from 'firebase-admin/firestore';

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const SCHOOL_ID_PATTERN = /^[a-z0-9][a-z0-9_-]{1,63}$/;

const UPPER = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
const LOWER = 'abcdefghijkmnopqrstuvwxyz';
const DIGITS = '23456789';
const SYMBOLS = '!@#$%^&*_-';
const ALL = UPPER + LOWER + DIGITS + SYMBOLS;

export interface MasterAdminAuthAdapter {
  createUser(input: {
    email: string;
    password: string;
    displayName?: string;
    emailVerified: boolean;
  }): Promise<{uid: string}>;
  deleteUser(uid: string): Promise<void>;
}

export interface MasterAdminFirestoreTx {
  get(path: string): Promise<{exists: boolean; data(): Record<string, unknown> | undefined}>;
  create(path: string, data: Record<string, unknown>): void;
}

export interface MasterAdminFirestoreAdapter {
  runTransaction<T>(fn: (tx: MasterAdminFirestoreTx) => Promise<T>): Promise<T>;
}

export interface ProvisionMasterAdminInput {
  auth: MasterAdminAuthAdapter;
  db: MasterAdminFirestoreAdapter;
  email: string;
  schoolId: string;
  fullName?: string;
}

export interface ProvisionMasterAdminResult {
  uid: string;
  email: string;
  schoolId: string;
  initialPassword: string;
}

function randomChar(charset: string): string {
  const limit = 256 - (256 % charset.length);
  while (true) {
    const b = randomBytes(1)[0];
    if (b < limit) return charset[b % charset.length];
  }
}

export function generateSecurePassword(length = 20): string {
  if (length < 16) throw new Error('Password length must be at least 16.');
  const chars = [
    randomChar(UPPER),
    randomChar(LOWER),
    randomChar(DIGITS),
    randomChar(SYMBOLS),
  ];
  while (chars.length < length) {
    chars.push(randomChar(ALL));
  }
  for (let i = chars.length - 1; i > 0; i--) {
    const j = randomBytes(1)[0] % (i + 1);
    const tmp = chars[i];
    chars[i] = chars[j];
    chars[j] = tmp;
  }
  return chars.join('');
}

export async function provisionMasterAdmin(
  input: ProvisionMasterAdminInput,
): Promise<ProvisionMasterAdminResult> {
  const email = input.email.trim().toLowerCase();
  const schoolId = input.schoolId.trim();
  const fullName = (input.fullName ?? 'Master Administrator').trim();

  if (!EMAIL_PATTERN.test(email) || email.length > 254) {
    throw new Error('Invalid email address for Master Admin provisioning.');
  }
  if (!SCHOOL_ID_PATTERN.test(schoolId)) {
    throw new Error('Invalid school identifier for Master Admin provisioning.');
  }
  if (fullName.length < 2 || fullName.length > 100) {
    throw new Error('Invalid full name for Master Admin provisioning.');
  }

  const initialPassword = generateSecurePassword(20);
  const created = await input.auth.createUser({
    email,
    password: initialPassword,
    displayName: fullName,
    emailVerified: false,
  });

  try {
    await input.db.runTransaction(async (tx) => {
      const lockPath = `masterAdminLocks/${schoolId}`;
      const existing = await tx.get(lockPath);
      if (existing.exists) {
        throw new Error(`A Master Admin already exists for school "${schoolId}".`);
      }
      tx.create(lockPath, {
        uid: created.uid,
        schoolId,
        createdAt: FieldValue.serverTimestamp(),
      });
      tx.create(`staffAccounts/${created.uid}`, {
        role: 'admin',
        isMasterAdmin: true,
        active: true,
        status: 'active',
        schoolId,
        fullName,
        position: 'Master Administrator',
        loginEmail: email,
        mustChangePassword: true,
        requiresEmailVerification: true,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      tx.create(`staffManagementAudits/${randomBytes(16).toString('hex')}`, {
        actorUid: 'operator-cli',
        actorRole: 'operator',
        schoolId,
        action: 'provision_master_admin',
        targetUid: created.uid,
        outcome: 'allowed',
        createdAt: FieldValue.serverTimestamp(),
      });
    });
  } catch (error) {
    try {
      await input.auth.deleteUser(created.uid);
    } catch {
      // Best-effort rollback of Auth user to avoid orphaned accounts.
    }
    throw error;
  }

  return {
    uid: created.uid,
    email,
    schoolId,
    initialPassword,
  };
}
