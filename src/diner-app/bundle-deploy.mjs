import archiver from 'archiver';
import fs from 'fs';
import { execSync } from 'child_process';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// 1. Install production deps into a temp folder
const tmpDir = path.join(__dirname, '_deploy_modules');
if (fs.existsSync(tmpDir)) fs.rmSync(tmpDir, { recursive: true });
fs.mkdirSync(tmpDir);
fs.writeFileSync(path.join(tmpDir, 'package.json'), JSON.stringify({
  name: "anna-booktable-frontend",
  version: "1.0.0",
  dependencies: { express: "^4.21.0" },
  scripts: { start: "node server.cjs" }
}, null, 2));
execSync('npm install --omit=dev', { cwd: tmpDir, stdio: 'inherit' });

// 2. Create zip with forward-slash paths
const output = fs.createWriteStream('D:/Dev/AnnaBooktable/frontend-deploy.zip');
const archive = archiver('zip', { zlib: { level: 6 } });

archive.pipe(output);
archive.directory('dist/', 'dist');
archive.directory(path.join(tmpDir, 'node_modules'), 'node_modules');
archive.file('server.cjs', { name: 'server.cjs' });
archive.file(path.join(tmpDir, 'package.json'), { name: 'package.json' });

output.on('close', () => {
  console.log('Zip: ' + (archive.pointer() / 1024).toFixed(0) + ' KB');
  // Cleanup
  fs.rmSync(tmpDir, { recursive: true });
});
archive.finalize();
