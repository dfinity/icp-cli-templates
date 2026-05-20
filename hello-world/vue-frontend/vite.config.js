import { defineConfig } from 'vite';
import vue from '@vitejs/plugin-vue';
import { icpBindgen } from '@icp-sdk/bindgen/plugins/vite';

// Change these values to match your local replica.
// The `icp network start` command will print the root key
// and the `icp deploy` command will print the backend canister id.
const IC_ROOT_KEY_HEX =
  "308182301d060d2b0601040182dc7c0503010201060c2b0601040182dc7c050302010361008b52b4994f94c7ce4be1c1542d7c81dc79fea17d49efe8fa42e8566373581d4b969c4a59e96a0ef51b711fe5027ec01601182519d0a788f4bfe388e593b97cd1d7e44904de79422430bca686ac8c21305b3397b5ba4d7037d17877312fb7ee34";
const BACKEND_CANISTER_ID = "txyno-ch777-77776-aaaaq-cai";

export default defineConfig({
  plugins: [
    vue(),
    icpBindgen({
      didFile: '../backend/backend.did',
      outDir: './src/bindings'
    }),
  ],
  server: {
    headers: {
      "Set-Cookie": `ic_env=${encodeURIComponent(
        `ic_root_key=${IC_ROOT_KEY_HEX}&PUBLIC_CANISTER_ID:backend=${BACKEND_CANISTER_ID}`
      )}; SameSite=Lax;`,
    },
    proxy: {
      '/api': {
        target: 'http://127.0.0.1:8000',
        changeOrigin: true,
      },
    },
  },
});
