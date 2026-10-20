import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import deployment from './vercel.json' with { type: 'json' };

const isolation = {
  'Cross-Origin-Opener-Policy': 'same-origin',
  'Cross-Origin-Embedder-Policy': 'require-corp',
};
const productionHeaders = Object.fromEntries(deployment.headers[0].headers.map(header => [header.key, header.value]));
export default defineConfig({ plugins: [react()], server: { headers: isolation }, preview: { headers: productionHeaders } });
