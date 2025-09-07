#!/usr/bin/env node
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
            r: false,
            zig: false
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

        // Check Zig
        try {
            execSync('zig version', { stdio: 'ignore' });
            this.availableRuntimes.zig = true;
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
        
        if (runtimes.zig) {
            this.buildZigLibraries();
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

    buildZigLibraries() {
        console.log('Building Zig performance libraries...');
        try {
            execSync('zig build', { 
                cwd: path.join(__dirname, 'backend', 'zig-backend'),
                stdio: 'inherit' 
            });
            console.log('✅ Zig libraries built successfully');
        } catch (e) {
            console.log('❌ Failed to build Zig libraries:', e.message);
        }
    }
}

module.exports = RuntimeDetector;

if (require.main === module) {
    const detector = new RuntimeDetector();
    detector.startAvailableServices();
}
