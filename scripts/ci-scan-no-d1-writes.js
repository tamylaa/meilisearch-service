// CI safety scan: detect likely D1 write usage while avoiding vendor files and false positives
const fs = require('fs');
const path = require('path');

const repoRoot = path.resolve(__dirname, '..');

// DB operation patterns we care about
const dbOps = [
  '.prepare(',
  'db.prepare',
  'db.exec',
  'database.prepare',
  'database.exec',
  'd1.prepare',
  'd1.exec',
  'insert into',
  'INSERT INTO',
];

const typePattern = 'D1Database';

function walk(dir) {
  const results = [];
  const list = fs.readdirSync(dir);
  list.forEach(file => {
    const full = path.join(dir, file);
    const stat = fs.statSync(full);
    if (stat && stat.isDirectory()) {
      results.push(...walk(full));
    } else {
      results.push(full);
    }
  });
  return results;
}

// Exclude vendor and tooling folders to avoid false positives
function isIgnored(filePath) {
  const p = filePath.replace(/\\/g, '/');
  if (p.includes('/node_modules/') || p.includes('/.git/') || p.includes('/.github/')) return true;
  // Skip TypeScript declaration files - they contain ambient types like D1Database
  if (p.endsWith('.d.ts')) return true;
  // Skip this scripts folder to avoid self-matches
  if (p.includes('/scripts/')) return true;
  return false;
}

function stripComments(src) {
  // Remove block comments and line comments (basic but effective for our use-case)
  return src.replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/.*$/gm, '');
}

const files = walk(repoRoot).filter(f => (f.endsWith('.ts') || f.endsWith('.js')) && !isIgnored(f));
let problems = [];
for (const file of files) {
  const content = fs.readFileSync(file, 'utf8');
  const cleaned = stripComments(content);

  // If any DB op pattern exists in cleaned content, flag the file
  const foundDbOp = dbOps.find(p => cleaned.includes(p));
  if (foundDbOp) {
    problems.push({ file, pattern: foundDbOp });
    continue;
  }

  // Only flag D1Database mentions when accompanied by DB operations (likely a write binding)
  if (cleaned.includes(typePattern)) {
    // if the file also contains db op patterns (already checked above) we would have flagged.
    // If not, this is likely only a type annotation or comment and can be ignored.
    // No-op here.
  }
}

if (problems.length > 0) {
  console.error('CI safety scan failed - potential D1 write/database patterns found:');
  problems.forEach(p => console.error('-', p.file, 'contains', p.pattern));
  process.exit(2);
}

console.log('CI safety scan passed: no obvious D1 write patterns found.');
process.exit(0);
