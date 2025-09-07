#!/usr/bin/env node
/**
 * Tessera Bundle Preparation Script
 * Prepares backend services and dependencies for Tauri bundling
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const colors = {
    green: '\x1b[32m',
    red: '\x1b[31m',
    yellow: '\x1b[33m',
    blue: '\x1b[34m',
    reset: '\x1b[0m'
};

const log = (color, prefix, message) => {
    console.log(`${colors[color]}[${prefix}]${colors.reset} ${message}`);
};

class BundlePreparation {
    constructor() {
        this.projectRoot = path.join(__dirname, '..');
        this.backendPath = path.join(this.projectRoot, 'backend');
        this.bundleDir = path.join(this.projectRoot, 'bundle-temp');
    }

    async prepare() {
        try {
            log('blue', 'BUNDLE', '🚀 Preparing Tessera for bundling...');
            
            // Create bundle directory
            this.createBundleDirectory();
            
            // Check prerequisites
            await this.checkPrerequisites();
            
            // Prepare Python environment
            await this.preparePythonEnvironment();
            
            // Prepare Perl environment
            await this.preparePerlEnvironment();
            
            // Prepare R environment
            await this.prepareREnvironment();
            
            // Copy configuration files
            this.copyConfigFiles();
            
            // Create runtime detection script
            this.createRuntimeDetection();
            
            log('green', 'BUNDLE', '✅ Bundle preparation complete!');
            log('yellow', 'BUNDLE', '💡 Run "npm run tauri:build" to create the desktop app');
            
        } catch (error) {
            log('red', 'ERROR', `Bundle preparation failed: ${error.message}`);
            process.exit(1);
        }
    }

    createBundleDirectory() {
        if (fs.existsSync(this.bundleDir)) {
            fs.rmSync(this.bundleDir, { recursive: true, force: true });
        }
        fs.mkdirSync(this.bundleDir, { recursive: true });
        log('blue', 'BUNDLE', 'Created bundle directory');
    }

    async checkPrerequisites() {
        log('blue', 'CHECK', 'Checking prerequisites...');
        
        // Check if backend directories exist
        const requiredPaths = [
            path.join(this.backendPath, 'python-backend'),
            path.join(this.backendPath, 'perl-backend'),
            path.join(this.backendPath, 'r-backend')
        ];
        
        for (const reqPath of requiredPaths) {
            if (!fs.existsSync(reqPath)) {
                throw new Error(`Required path not found: ${reqPath}`);
            }
        }
        
        log('green', 'CHECK', 'Prerequisites verified');
    }

    async preparePythonEnvironment() {
        log('blue', 'PYTHON', 'Preparing Python environment...');
        
        const pythonBackend = path.join(this.backendPath, 'python-backend');
        const venvPath = path.join(pythonBackend, 'venv');
        
        if (!fs.existsSync(venvPath)) {
            log('yellow', 'PYTHON', 'Virtual environment not found, creating...');
            execSync('python3 -m venv venv', { cwd: pythonBackend, stdio: 'inherit' });
            execSync('venv/bin/pip install -r requirements.txt', { cwd: pythonBackend, stdio: 'inherit' });
        }
        
        // Create a requirements freeze for bundling
        try {
            const frozenReqs = execSync('venv/bin/pip freeze', { cwd: pythonBackend, encoding: 'utf8' });
            fs.writeFileSync(path.join(pythonBackend, 'requirements-frozen.txt'), frozenReqs);
        } catch (error) {
            log('yellow', 'PYTHON', 'Could not freeze requirements');
        }
        
        log('green', 'PYTHON', 'Python environment prepared');
    }

    async preparePerlEnvironment() {
        log('blue', 'PERL', 'Preparing Perl environment...');
        
        const perlBackend = path.join(this.backendPath, 'perl-backend');
        
        // Check if cpanfile exists and install dependencies
        if (fs.existsSync(path.join(perlBackend, 'cpanfile'))) {
            try {
                execSync('cpanm --installdeps .', { cwd: perlBackend, stdio: 'inherit' });
                log('green', 'PERL', 'Perl dependencies installed');
            } catch (error) {
                log('yellow', 'PERL', 'Could not install Perl dependencies automatically');
            }
        }
        
        log('green', 'PERL', 'Perl environment prepared');
    }

    async prepareREnvironment() {
        log('blue', 'R', 'Preparing R environment...');
        
        const rBackend = path.join(this.backendPath, 'r-backend');
        
        // Check if R is available
        try {
            execSync('which R', { stdio: 'ignore' });
            log('green', 'R', 'R runtime detected');
        } catch (error) {
            log('yellow', 'R', 'R runtime not found - R features may not work');
        }
        
        log('green', 'R', 'R environment prepared');
    }

    copyConfigFiles() {
        log('blue', 'CONFIG', 'Copying configuration files...');
        
        const configSrc = path.join(this.backendPath, 'config');
        const configDest = path.join(this.bundleDir, 'config');
        
        if (fs.existsSync(configSrc)) {
            fs.cpSync(configSrc, configDest, { recursive: true });
        }
        
        log('green', 'CONFIG', 'Configuration files copied');
    }

    createRuntimeDetection() {
        log('blue', 'RUNTIME', 'Creating runtime detection script...');
        
        const detectionScript = `#!/usr/bin/env node
/**
 * Runtime Detection for Tessera
 * Detects available runtimes and starts appropriate services
 */

const { spawn, execSync } = require('child_process');
const path = require('path');
const fs = require('fs');

class RuntimeDetector {
    constructor() {
        this.availableRuntimes = {
            perl: false,
            python: false,
            r: false
        };
    }

    detect() {
        // Check Perl
        try {
            execSync('perl --version', { stdio: 'ignore' });
            this.availableRuntimes.perl = true;
        } catch (e) {}

        // Check Python
        try {
            execSync('python3 --version', { stdio: 'ignore' });
            this.availableRuntimes.python = true;
        } catch (e) {}

        // Check R
        try {
            execSync('R --version', { stdio: 'ignore' });
            this.availableRuntimes.r = true;
        } catch (e) {}

        return this.availableRuntimes;
    }

    startAvailableServices() {
        const runtimes = this.detect();
        console.log('Available runtimes:', runtimes);
        
        // Start services based on available runtimes
        if (runtimes.python) {
            this.startPythonServices();
        }
        
        if (runtimes.perl) {
            this.startPerlService();
        }
        
        return runtimes;
    }

    startPythonServices() {
        // Implementation will be added by Tauri backend
        console.log('Starting Python services...');
    }

    startPerlService() {
        // Implementation will be added by Tauri backend
        console.log('Starting Perl service...');
    }
}

module.exports = RuntimeDetector;

if (require.main === module) {
    const detector = new RuntimeDetector();
    detector.startAvailableServices();
}
`;

        fs.writeFileSync(path.join(this.bundleDir, 'runtime-detector.js'), detectionScript);
        log('green', 'RUNTIME', 'Runtime detection script created');
    }
}

// Run the preparation
const bundlePrep = new BundlePreparation();
bundlePrep.prepare();
