import { defineConfig } from 'vite'
import { createVuePlugin } from 'vite-plugin-vue2'

export default defineConfig({
  root: './src',
  plugins: [createVuePlugin()],
  build: {
    outDir: '../dist',
    emptyOutDir: true,
    rollupOptions: {
      input: './src/index.html'
    }
  }
})
