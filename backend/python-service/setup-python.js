const { spawnSync } = require('child_process');
const path = require('path');
const fs = require('fs');

console.log("🚀 Setting up Python Services for MyTelUV2...\n");

const services = ['face_recognition', 'plate_recognition'];

function runCmd(cmd, args, cwd) {
    const isWindows = process.platform === 'win32';
    // Use shell on Windows to allow things like `python -m venv` to work properly
    const result = spawnSync(cmd, args, { cwd, stdio: 'inherit', shell: isWindows });
    if (result.error) {
        console.error(`❌ Error executing ${cmd} ${args.join(' ')} in ${cwd}`);
        console.error(result.error);
        return false;
    }
    if (result.status !== 0) {
        console.error(`❌ Command failed with status ${result.status}`);
        return false;
    }
    return true;
}

// 1. Check Python installation
console.log("Checking Python installation...");
const checkPython = spawnSync('python', ['--version']);
if (checkPython.error || checkPython.status !== 0) {
    console.error("❌ Python is not installed or not in PATH. Please install Python 3.8 or higher.");
    process.exit(1);
}
console.log(`✓ Found ${checkPython.stdout ? checkPython.stdout.toString().trim() : checkPython.stderr.toString().trim()}\n`);

// 2. Setup each service
for (const service of services) {
    console.log(`Setting up ${service}...`);
    const serviceDir = path.join(__dirname, service);
    
    if (!fs.existsSync(serviceDir)) {
        console.error(`❌ Directory ${serviceDir} does not exist!`);
        continue;
    }

    console.log("  Creating virtual environment...");
    if (!runCmd('python', ['-m', 'venv', 'venv'], serviceDir)) continue;

    console.log("  Installing dependencies...");
    const isWindows = process.platform === 'win32';
    const pythonExec = isWindows ? path.join(serviceDir, 'venv', 'Scripts', 'python') : path.join(serviceDir, 'venv', 'bin', 'python');
    const pipPath = isWindows ? path.join(serviceDir, 'venv', 'Scripts', 'pip') : path.join(serviceDir, 'venv', 'bin', 'pip');
    
    // Upgrade pip (use python -m pip to avoid Windows access denied errors)
    runCmd(pythonExec, ['-m', 'pip', 'install', '--upgrade', 'pip'], serviceDir);
    
    // Install requirements
    if (runCmd(pipPath, ['install', '-r', 'requirements.txt'], serviceDir)) {
        console.log(`✓ ${service} setup complete!\n`);
    } else {
        console.log(`⚠ Some dependencies failed to install for ${service}\n`);
    }
}

console.log("========================================");
console.log("✨ Setup Complete!");
console.log("========================================");
console.log("\nNote: InsightFace models will auto-download (~300MB) on first run for face_recognition.");
