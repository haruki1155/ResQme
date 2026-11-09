export const projectId = 'demo-resqme';
export function emulatorConfig(env: NodeJS.ProcessEnv) {
  if (env.GCLOUD_PROJECT !== projectId) throw new Error('Expected demo-resqme project');
  const endpoint = (name: string) => {
    const value = env[name];
    const match = /^(127\.0\.0\.1|localhost):(\d{1,5})$/.exec(value ?? '');
    const port = Number(match?.[2]);
    if (!match || port < 1024 || port > 65535) throw new Error(`Expected loopback ${name} with a valid port`);
    return {host: match[1], port};
  };
  const config = {
    auth: endpoint('FIREBASE_AUTH_EMULATOR_HOST'),
    firestore: endpoint('FIRESTORE_EMULATOR_HOST'),
    functions: endpoint('FUNCTIONS_EMULATOR_HOST'),
  };
  if (new Set(Object.values(config).map(({port}) => port)).size !== 3) {
    throw new Error('Emulator ports must be unique.');
  }
  return config;
}
