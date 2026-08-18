import { cp, mkdir, readdir, rm } from 'node:fs/promises';
import { join } from 'node:path';

const root = new URL('../', import.meta.url);
const output = new URL('../www/', import.meta.url);
const rootFiles = [
  'index.html','login.html','cadastro.html','redefinir-senha.html','app.html','admin.html',
  'termos.html','privacidade.html','styles.css','manifest.json','service-worker.js'
];
const folders = ['assets','config','css','js'];

await rm(output, { recursive: true, force: true });
await mkdir(output, { recursive: true });
for (const file of rootFiles) await cp(new URL(`../${file}`, import.meta.url), new URL(`../www/${file}`, import.meta.url));
for (const folder of folders) await cp(new URL(`../${folder}`, import.meta.url), new URL(`../www/${folder}`, import.meta.url), { recursive: true });

const copied = await readdir(output);
console.log(`Aura 67 mobile: ${copied.length} entradas preparadas em ${join(root.pathname, 'www')}`);
