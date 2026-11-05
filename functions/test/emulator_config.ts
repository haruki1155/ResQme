export const projectId = 'demo-resqme';
export function emulatorConfig(env: NodeJS.ProcessEnv) {
  if (env.GCLOUD_PROJECT !== projectId) throw new Error('Expected demo-resqme project');
  const endpoint = (name: string, port: number) => {
    const value = env[name];
    if (value !== `127.0.0.1:${port}` && value !== `localhost:${port}`) throw new Error(`Expected loopback ${name}:${port}`);
    return {host: value.split(':')[0], port};
  };
  return {auth: endpoint('FIREBASE_AUTH_EMULATOR_HOST', 9099), firestore: endpoint('FIRESTORE_EMULATOR_HOST', 8080), functions: endpoint('FUNCTIONS_EMULATOR_HOST', 5001)};
}
