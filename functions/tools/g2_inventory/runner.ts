import {mkdtemp,writeFile} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {localConfig} from './contract';
import {LocalFirestoreTransport} from './transport';
import {runInventory} from './inventory';

// Deliberately no hosted flags, credentials or remote metadata preflight.
export async function main(env:NodeJS.ProcessEnv=process.env,args:string[]=process.argv.slice(2)) {
  try {if(args.length)throw new Error();localConfig(env);} catch {console.error('inventory_local_configuration_rejected');return 2;}
  const abort=new AbortController();const cancel=()=>abort.abort();
  process.once('SIGINT',cancel);process.once('SIGTERM',cancel);
  try {
    const result=await runInventory(new LocalFirestoreTransport(env),{signal:abort.signal});
    const evidenceDirectory=await mkdtemp(join(tmpdir(),'resqme-g2a-synthetic-'));
    const policy={syntheticLocalOnly:true,hostedUseAllowed:false,access:'Local temporary directory; hosted ACL policy not established',retention:'Synthetic temporary evidence retained for operator review; disposal is manual. A hosted policy requires separate approval.'};
    await writeFile(join(evidenceDirectory,'private-synthetic-evidence.json'),JSON.stringify({policy,...result.privateEvidence},null,2),{mode:0o600,flag:'wx'});
    await writeFile(join(evidenceDirectory,'sanitized-report.json'),JSON.stringify(result.report,null,2),{mode:0o600,flag:'wx'});
    console.log(JSON.stringify({report:result.report,evidenceDirectory},null,2));
    return result.report.status==='COMPLETE'?0:1;
  } catch {console.error('inventory_local_execution_failed');return 1;}
  finally {process.removeListener('SIGINT',cancel);process.removeListener('SIGTERM',cancel);}
}

if(require.main===module) void main().then(code=>{process.exitCode=code;});
