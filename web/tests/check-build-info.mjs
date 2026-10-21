import assert from 'node:assert/strict';
import { mkdtemp, mkdir, copyFile, writeFile, readFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, dirname, resolve } from 'node:path';
import { execFileSync } from 'node:child_process';
const root = await mkdtemp(join(tmpdir(), 'jmv2gg-build-identity-'));
try {
  for (const path of ['web/tools','web/dist','web/public/r-packages','.vercel']) await mkdir(join(root,path),{recursive:true});
  await copyFile(new URL('../tools/write-build-info.mjs',import.meta.url),join(root,'web/tools/write-build-info.mjs'));
  await writeFile(join(root,'DESCRIPTION'),'Version: 0.1.0\n');
  await writeFile(join(root,'web/package.json'),JSON.stringify({version:'0.1.0',dependencies:{webr:'0.6.0'}}));
  await writeFile(join(root,'web/public/r-packages/build-manifest.json'),JSON.stringify({sha256:'test-checksum'}));
  await writeFile(join(root,'.vercel/project.json'),'{}');
  await writeFile(join(root,'.gitignore'),'web/dist/\n');
  const git = args => execFileSync('git',args,{cwd:root,encoding:'utf8',stdio:['ignore','pipe','pipe']}).trim();
  git(['init','--quiet']); git(['add','.']);
  git(['-c','user.name=Build test','-c','user.email=build@example.invalid','commit','-qm','Synthetic fixture']);
  const revision = git(['rev-parse','HEAD']);
  const run = async provider => {
    const env={...process.env}; delete env.VERCEL_GIT_COMMIT_SHA;
    if(provider) env.VERCEL_GIT_COMMIT_SHA=provider;
    execFileSync(process.execPath,['web/tools/write-build-info.mjs'],{cwd:root,env,stdio:'pipe'});
    return JSON.parse(await readFile(join(root,'web/dist/build-info.json'),'utf8'));
  };
  assert.equal((await run()).sourceTreeDirty,false);
  await writeFile(join(root,'.vercel/project.json'),'{"hosting":"generated"}');
  await writeFile(join(root,'vercel.json'),'{}');
  assert.equal((await run()).sourceTreeDirty,true,'Local changes cannot be exempted as provider metadata.');
  const hosted=await run(revision);
  assert.equal(hosted.workingTreeDirty,true,'Raw Git status must stay truthful.');
  assert.equal(hosted.sourceTreeDirty,false);
  assert.equal(hosted.providerManagedChanges.length,2);
  await writeFile(join(root,'unexpected.txt'),'changed source');
  assert.equal((await run(revision)).sourceTreeDirty,true,'Unknown source changes must still fail.');
  await assert.rejects(run('invalid-revision'));
  console.log('Build identity: clean, local dirty, hosted metadata, unexpected source and malformed revision checks PASS.');
} finally {
  assert.equal(resolve(dirname(root)),resolve(tmpdir()),'Cleanup target must remain directly inside the OS temporary directory.');
  await rm(root,{recursive:true,force:true});
}
