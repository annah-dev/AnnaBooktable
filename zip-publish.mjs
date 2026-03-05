// Zips a publish directory with forward-slash paths (safe for Linux/Azure)
// Usage: node zip-publish.mjs <source-dir> <output-zip>
import archiver from 'archiver';
import fs from 'fs';

const [,, sourceDir, outputPath] = process.argv;
if (!sourceDir || !outputPath) {
  console.error('Usage: node zip-publish.mjs <source-dir> <output-zip>');
  process.exit(1);
}

const output = fs.createWriteStream(outputPath);
const archive = archiver('zip', { zlib: { level: 6 } });
archive.pipe(output);
archive.directory(sourceDir + '/', false);
output.on('close', () => console.log(`${outputPath}: ${(archive.pointer() / 1024 / 1024).toFixed(1)} MB`));
archive.finalize();
