#!/usr/bin/env node
/**
 * WikiCrawler Backend Startup Script
 * Starts all required services: Python RAG services + Perl API server
 */

const { spawn, exec } = require('child_process');
const path = require('path');
const fs = require('fs');

// ANSI colors for console output
const colors = {
    green: '\x1b[32m',
    red: '\x1b[31m',
    yellow: '\x1b[33m',
    blue: '\x1b[34m',
    magenta: '\x1b[35m',
    cyan: '\x1b[36m',
    reset: '\x1b[0m'
};

const log = (color, prefix, message) => {
    console.log(`${colors[color]}[${prefix}]${colors.reset} ${message}`);
};

class BackendManager {
    constructor() {
        this.processes = {};
        this.startupChecks = [];
        this.isShuttingDown = false;
        
        // Handle process cleanup on exit
        process.on('SIGINT', () => this.cleanup());
        process.on('SIGTERM', () => this.cleanup());
        process.on('exit', () => this.cleanup());
    }

    async checkPrerequisites() {
        log('blue', 'SETUP', 'Checking prerequisites...');
        
        // Check if knowledge_bot directory exists
        const knowledgeBotPath = path.join(__dirname, '..', 'backend', 'knowledge_bot');
        if (!fs.existsSync(knowledgeBotPath)) {
            log('red', 'ERROR', 'backend/knowledge_bot directory not found');
            process.exit(1);
        }

        // Check if virtual environment exists
        const venvPath = path.join(knowledgeBotPath, 'venv');
        if (!fs.existsSync(venvPath)) {
            log('yellow', 'WARN', 'Virtual environment not found, running setup...');
            await this.runSetup();
        }

        // Check if API key is set
        if (!process.env.GEMINI_API_KEY) {
            const envFile = path.join(knowledgeBotPath, '.env');
            if (!fs.existsSync(envFile)) {
                log('yellow', 'WARN', 'GEMINI_API_KEY not found in environment or .env file');
                log('yellow', 'WARN', 'Some features may not work without the API key');
            } else {
                log('green', 'INFO', 'Found .env file for API key');
            }
        }

        // Check Perl script
        const perlScript = path.join(__dirname, '..', 'backend', 'script', 'api_server.pl');
        if (!fs.existsSync(perlScript)) {
            log('red', 'ERROR', 'Perl API server script not found');
            process.exit(1);
        }

        log('green', 'SETUP', 'Prerequisites check completed');
    }

    async runSetup() {
        return new Promise((resolve, reject) => {
            const setupScript = path.join(__dirname, '..', 'backend', 'knowledge_bot', 'setup.py');
            log('blue', 'SETUP', 'Running Python setup...');
            
            const setup = spawn('python3', [setupScript], {
                cwd: path.join(__dirname, '..', 'backend', 'knowledge_bot'),
                stdio: 'inherit'
            });

            setup.on('close', (code) => {
                if (code === 0) {
                    log('green', 'SETUP', 'Python setup completed successfully');
                    resolve();
                } else {
                    log('red', 'SETUP', 'Python setup failed');
                    reject(new Error('Setup failed'));
                }
            });
        });
    }

    async startEmbeddingService() {
        return new Promise((resolve) => {
            const knowledgeBotPath = path.join(__dirname, '..', 'backend', 'knowledge_bot');
            
            log('blue', 'EMBED', 'Starting Embedding Service on port 8002...');
            
            const embeddingService = spawn('venv/bin/python', ['embedding_service.py'], {
                cwd: knowledgeBotPath,
                stdio: 'pipe',
                env: { ...process.env, GEMINI_API_KEY: process.env.GEMINI_API_KEY || '' }
            });

            this.processes.embedding = embeddingService;

            embeddingService.stdout.on('data', (data) => {
                const output = data.toString().trim();
                if (output) log('cyan', 'EMBED', output);
            });

            embeddingService.stderr.on('data', (data) => {
                const output = data.toString().trim();
                if (output && !output.includes('WARNING')) {
                    log('yellow', 'EMBED', output);
                }
            });

            embeddingService.on('close', (code) => {
                if (!this.isShuttingDown) {
                    log('red', 'EMBED', `Service exited with code ${code}`);
                }
            });

            // Wait a moment for service to start
            setTimeout(() => {
                log('green', 'EMBED', 'Embedding service started');
                resolve();
            }, 2000);
        });
    }

    async startGeminiService() {
        return new Promise((resolve) => {
            const knowledgeBotPath = path.join(__dirname, '..', 'backend', 'knowledge_bot');
            
            log('blue', 'GEMINI', 'Starting Gemini Service on port 8001...');
            
            const geminiService = spawn('venv/bin/python', ['gemini_service.py'], {
                cwd: knowledgeBotPath,
                stdio: 'pipe',
                env: { ...process.env, GEMINI_API_KEY: process.env.GEMINI_API_KEY || '' }
            });

            this.processes.gemini = geminiService;

            geminiService.stdout.on('data', (data) => {
                const output = data.toString().trim();
                if (output) log('magenta', 'GEMINI', output);
            });

            geminiService.stderr.on('data', (data) => {
                const output = data.toString().trim();
                if (output && !output.includes('WARNING')) {
                    log('yellow', 'GEMINI', output);
                }
            });

            geminiService.on('close', (code) => {
                if (!this.isShuttingDown) {
                    log('red', 'GEMINI', `Service exited with code ${code}`);
                }
            });

            // Wait a moment for service to start
            setTimeout(() => {
                log('green', 'GEMINI', 'Gemini service started');
                resolve();
            }, 3000);
        });
    }

    async startPerlAPIServer() {
        return new Promise((resolve) => {
            const backendPath = path.join(__dirname, '..', 'backend');
            
            log('blue', 'PERL', 'Starting Perl API Server on port 3000...');
            
            const perlServer = spawn('perl', ['script/api_server.pl'], {
                cwd: backendPath,
                stdio: 'pipe'
            });

            this.processes.perl = perlServer;

            perlServer.stdout.on('data', (data) => {
                const output = data.toString().trim();
                if (output) log('green', 'PERL', output);
            });

            perlServer.stderr.on('data', (data) => {
                const output = data.toString().trim();
                if (output && !output.includes('WARNING')) {
                    log('yellow', 'PERL', output);
                }
            });

            perlServer.on('close', (code) => {
                if (!this.isShuttingDown) {
                    log('red', 'PERL', `Server exited with code ${code}`);
                }
            });

            // Wait longer for server to fully start
            setTimeout(() => {
                log('green', 'PERL', 'Perl API server started');
                resolve();
            }, 4000);
        });
    }

    async checkServices() {
        log('blue', 'CHECK', 'Verifying services are running...');
        
        const services = [
            { name: 'Embedding Service', url: 'http://127.0.0.1:8002/health', color: 'cyan' },
            { name: 'Gemini Service', url: 'http://127.0.0.1:8001/health', color: 'magenta' },
            { name: 'Perl API Server', url: 'http://127.0.0.1:3000/health', color: 'green' }
        ];

        for (const service of services) {
            try {
                await this.curlCheck(service.url);
                log(service.color, 'CHECK', `✅ ${service.name}: Running`);
            } catch (error) {
                log('red', 'CHECK', `❌ ${service.name}: Not responding`);
            }
        }
        
        log('green', 'READY', '🚀 All services started! Backend is ready.');
        this.showUsageInfo();
    }

    curlCheck(url) {
        return new Promise((resolve, reject) => {
            exec(`curl -s -f ${url}`, (error, stdout, stderr) => {
                if (error) {
                    reject(error);
                } else {
                    resolve(stdout);
                }
            });
        });
    }

    showUsageInfo() {
        console.log(`
${colors.blue}📚 WikiCrawler Backend Services${colors.reset}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
${colors.cyan}🔗 Service URLs:${colors.reset}
  • Perl API Server:    http://127.0.0.1:3000
  • Gemini Service:     http://127.0.0.1:8001 (+ /docs for API)
  • Embedding Service:  http://127.0.0.1:8002 (+ /docs for API)

${colors.green}✨ Ready for frontend connection!${colors.reset}
${colors.yellow}💡 Press Ctrl+C to stop all services${colors.reset}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        `);
    }

    cleanup() {
        if (this.isShuttingDown) return;
        this.isShuttingDown = true;
        
        log('yellow', 'STOP', 'Shutting down services...');
        
        Object.entries(this.processes).forEach(([name, process]) => {
            if (process && !process.killed) {
                log('yellow', 'STOP', `Stopping ${name} service...`);
                process.kill('SIGTERM');
                
                // Force kill after 5 seconds
                setTimeout(() => {
                    if (!process.killed) {
                        process.kill('SIGKILL');
                    }
                }, 5000);
            }
        });

        setTimeout(() => {
            log('green', 'STOP', 'All services stopped');
            process.exit(0);
        }, 1000);
    }

    async start() {
        try {
            log('blue', 'START', '🚀 Starting WikiCrawler Backend Services...');
            
            await this.checkPrerequisites();
            
            // Start services in order
            await this.startEmbeddingService();
            await this.startGeminiService();
            await this.startPerlAPIServer();
            
            // Wait a bit more for all services to stabilize
            await new Promise(resolve => setTimeout(resolve, 3000));
            
            await this.checkServices();
            
            // Keep the process alive
            process.stdin.resume();
            
        } catch (error) {
            log('red', 'ERROR', `Failed to start backend: ${error.message}`);
            process.exit(1);
        }
    }
}

// Start the backend
const backend = new BackendManager();
backend.start();
