#!/usr/bin/env node

const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');

const projectDir = path.resolve(__dirname, '..');
const hvigorwPath = path.join(projectDir, 'node_modules', '@ohos', 'hvigor', 'bin', 'hvigor.js');

if (fs.existsSync(hvigorwPath)) {
  const args = process.argv.slice(2);
  const child = spawn('node', [hvigorwPath, ...args], {
    cwd: projectDir,
    stdio: 'inherit'
  });
  child.on('exit', (code) => {
    process.exit(code);
  });
} else {
  console.error('hvigor not found. Please run "npm install" first.');
  process.exit(1);
}
