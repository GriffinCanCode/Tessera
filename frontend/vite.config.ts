import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';
import path from 'path';

// https://vite.dev/config/
export default defineConfig({
  plugins: [
    react(), 
    tailwindcss(),
    // Plugin to handle GLSL shader files
    {
      name: 'glsl-loader',
      transform(code, id) {
        if (id.endsWith('.glsl') || id.endsWith('.vert') || id.endsWith('.frag')) {
          return `export default ${JSON.stringify(code)};`;
        }
      }
    }
  ],
  resolve: {
    alias: {
      '@': path.resolve(import.meta.dirname, './src'),
      '@styles': path.resolve(import.meta.dirname, './src/styles'),
      '@components': path.resolve(import.meta.dirname, './src/components'),
      '@utils': path.resolve(import.meta.dirname, './src/utils'),
      '@hooks': path.resolve(import.meta.dirname, './src/hooks'),
      '@types': path.resolve(import.meta.dirname, './src/types'),
      '@services': path.resolve(import.meta.dirname, './src/services'),
    },
  },
  server: {
    port: 5173,
    host: true,
    open: false, // Don't auto-open browser when running with concurrently
    hmr: {
      overlay: true, // Show build errors in overlay
    },
    proxy: {
      // Ingestion endpoints go to Python service on port 8003
      '/ingest': {
        target: 'http://localhost:8003',
        changeOrigin: true,
      },
      // All other API endpoints go to Perl service on port 3000
      '/api': {
        target: 'http://localhost:3000',
        changeOrigin: true,
        rewrite: path => path.replace(/^\/api/, ''),
      },
    },
  },
  build: {
    // Modern build optimizations for 2025
    target: 'esnext',
    minify: 'esbuild',
    cssMinify: 'lightningcss',
    rollupOptions: {
      output: {
        manualChunks: {
          vendor: ['react', 'react-dom'],
          query: ['@tanstack/react-query'],
          ui: ['lucide-react'],
        },
      },
    },
  },
  css: {
    // Enable CSS features for better performance
    devSourcemap: true,
  },
  define: {
    'process.env.VITE_API_BASE_URL': JSON.stringify('/api'),
  },
  envDir: '.',
});
