import { defineConfig } from 'vite';
import { svelte } from '@sveltejs/vite-plugin-svelte';
import tailwindcss from '@tailwindcss/vite';

export default defineConfig({
  // Tailwind v4 needs no config file -- the theme is declared in src/theme/tokens.css.
  plugins: [tailwindcss(), svelte()],
  // Relative asset paths -- NUI's Chromium loads the page from nui://, not a web root.
  base: './',
  // Item images live in web/images and are addressed through client.imagepath at
  // runtime, not bundled. Nothing here should be copied into the build.
  publicDir: false,
  server: {
    // PORT wins where it is set, because two chats previewing the same resource is two vite
    // servers wanting one port, and the second one loses. The preview manager assigns a free
    // port and hands it over this way; the constant is what `pnpm run dev` in a terminal gets.
    //
    // strictPort either way, so a busy port is an error rather than vite quietly binding a
    // different one and leaving whoever asked watching the wrong address.
    port: Number(process.env.PORT) || 3002,
    strictPort: true,
  },
  build: {
    // Must stay 'build': fxmanifest.lua:33 declares `ui_page 'web/build/index.html'`.
    outDir: 'build',
    target: 'esnext',
    emptyOutDir: true,
    rollupOptions: {
      output: {
        // Fixed names rather than hashed ones, carried over from the React config.
        // fxmanifest.lua:40-41 globs `web/build/assets/*.js` and `*.css`, which hashed
        // names would still match -- but a stable filename means the manifest can be
        // read and understood without running a build first. Safe only because there is
        // a single entry and no code splitting; two chunks sharing a name would collide.
        assetFileNames: 'assets/[name][extname]',
        entryFileNames: 'assets/[name].js',
        chunkFileNames: 'assets/[name].js',
      },
    },
  },
});
