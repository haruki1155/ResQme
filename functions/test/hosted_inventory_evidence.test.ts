import assert from 'node:assert/strict';import test from 'node:test';
import {prepareEvidence,type EvidenceIO} from '../tools/g2_inventory/hosted/evidence';
import {approved,fakeEvidence} from './hosted_inventory_fixtures';
import {runInventory} from '../tools/g2_inventory/inventory';
test('narrow local NTFS writer separates evidence and never changes permissions',async()=>{const f=fakeEvidence();const w=await prepareEvidence(approved(),f.io,new AbortController().signal);const result=await runInventory({collections:async()=>({ids:[]}),query:async()=>[]});await w.finish(result,{adapterReadOnly:true});assert.equal(Object.keys(f.files).length,4);assert.ok(!Object.values(f.files).find(s=>s.includes('SYNTHETIC_TOKEN')));});
test('unsupported, broad, redirected, Git-contained or ambiguous directories fail closed',async()=>{
 for(const change of [{platform:'linux'},{filesystem:'FAT32'},{fixed:false},{canonical:'C:\\other'},{safePath:false},{protected:false},{ownerSid:'S-1-5-21-999'},{aces:[{sid:'S-1-1-0',allow:true,simple:true,rights:'Read'}]},{aces:[{sid:'S-1-5-21-100',allow:false,simple:true,rights:'FullControl'}]},{aces:[{sid:'S-1-5-21-100',allow:true,simple:false,rights:'FullControl'}]}]){const f=fakeEvidence();f.io.inspect=async()=>({...f.facts,...change});await assert.rejects(prepareEvidence(approved(),f.io,new AbortController().signal));}
 const f=fakeEvidence();f.io.gitRoots=async()=>['C:\\private'];await assert.rejects(prepareEvidence(approved(),f.io,new AbortController().signal));
});
test('run replay, unsafe content and failed evidence writes never fall back elsewhere',async()=>{
 const f=fakeEvidence();f.io.reserve=async()=>{throw new Error('PRIVATE_PATH')};await assert.rejects(prepareEvidence(approved(),f.io,new AbortController().signal),e=>!String(e).includes('PRIVATE_PATH'));
 const g=fakeEvidence();const w=await prepareEvidence(approved(),g.io,new AbortController().signal);g.io.write=async()=>{throw new Error('SECRET')};await assert.rejects(w.fail('FAILED'),e=>!String(e).includes('SECRET'));
});
test('a different Git repository outside the current worktree list is rejected before reservation',async()=>{
 const f=fakeEvidence();let reserves=0;f.io.reserve=async()=>{reserves++;};f.io.inspect=async(path)=>({...f.facts,canonical:path,outsideGit:false});
 await assert.rejects(prepareEvidence(approved(),f.io,new AbortController().signal));assert.equal(reserves,0);
});
