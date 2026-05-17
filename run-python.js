const { execSync } = require('child_process');
const path = require('path');

const serviceDir = process.argv[2];
if (!serviceDir) {
    console.error('Usage: node run-python.js <service-directory>');
    process.exit(1);
}

const isWin = process.platform === 'win32';
const pythonBin = isWin
    ? path.join(__dirname, serviceDir, 'venv', 'Scripts', 'python.exe')
    : path.join(__dirname, serviceDir, 'venv', 'bin', 'python');
const appPath = path.join(__dirname, serviceDir, 'app.py');

console.log(`[run-python] Starting ${appPath} with ${pythonBin}`);
execSync(`"${pythonBin}" "${appPath}"`, { stdio: 'inherit', cwd: path.join(__dirname, serviceDir) });
