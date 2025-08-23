// Simple CI scan: fail if any files in the meilisearch repo import or call D1 write methods
// We scan for common D1 patterns like "DB.prepare(" or ".exec(" on DB or calls to "D1Database"

const fs = require('fs');
const path = require('path');

const repoRoot = path.resolve(__dirname, '..');
const patterns = [
  "DB.",
  "D1Database",
  ".prepare(",
  "insert into",
  "INSERT INTO",
  "db.prepare",
  "db.exec",
  "database.prepare",
  "database.exec",
  "d1.prepare",
  "d1.exec",
];

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

const files = walk(repoRoot).filter(f => f.endsWith('.ts') || f.endsWith('.js'));
let problems = [];
for (const file of files) {
  const content = fs.readFileSync(file, 'utf8');
  for (const p of patterns) {
    if (content.includes(p)) {
      problems.push({ file, pattern: p });
      break;
    }
  }
}

if (problems.length > 0) {
  console.error('CI safety scan failed - potential D1 write/database patterns found:');
  problems.forEach(p => console.error('-', p.file, 'contains', p.pattern));
  process.exit(2);
}

console.log('CI safety scan passed: no obvious D1 write patterns found.');
process.exit(0);
