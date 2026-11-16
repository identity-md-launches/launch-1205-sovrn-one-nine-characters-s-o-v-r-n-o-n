import { defineConfig } from "vite";
import { fileURLToPath } from "node:url";
import type { Plugin } from "vite";

// Vite marks its emitted stylesheet crossorigin; it is same-origin, so drop the attribute and
// the page also opens straight from disk (file://) with its fonts.
const plainStylesheetLink = (): Plugin => ({
  name: "plain-stylesheet-link",
  enforce: "post",
  transformIndexHtml: (html) => html.replace(/<link rel="stylesheet" crossorigin href=/g, '<link rel="stylesheet" href='),
});

// One static page, no JavaScript. base "./" keeps every URL relative so the export works
// from an IPFS gateway subpath as well as a domain root. public/ holds banner.jpg, icon.png
// and apple-icon.png, copied byte for byte to the export root under their own names.
export default defineConfig({
  base: "./",
  plugins: [plainStylesheetLink()],
  build: {
    outDir: fileURLToPath(new URL("../dist", import.meta.url)),
    emptyOutDir: true,
    assetsInlineLimit: 0,
    modulePreload: false,
    // Keep the approved inline <style> exactly as written (no minify, no syntax lowering).
    cssMinify: false,
  },
});
