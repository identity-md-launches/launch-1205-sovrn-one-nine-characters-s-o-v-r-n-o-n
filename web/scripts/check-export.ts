// Static checks on the production export (../dist). Run: npm run check (after npm run build).
// Exits 1 on any failure. No network, no browser: it reads the files only.
import { createHash } from "node:crypto";
import { existsSync, readFileSync, readdirSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const dist = resolve(dirname(fileURLToPath(import.meta.url)), "../../dist");
const failures: string[] = [];
const check = (ok: boolean, label: string): void => {
  console.log(`${ok ? "ok  " : "FAIL"} ${label}`);
  if (!ok) failures.push(label);
};
const sha256 = (path: string): string => createHash("sha256").update(readFileSync(path)).digest("hex");

// 1. The pinned assets, byte for byte, at the export root.
const pinned: Record<string, string> = {
  "banner.jpg": "0fcf599f13a05674b00d35ddba6ea23b472100b50557090a6be48746342a6908",
  "icon.png": "93baca85e42ecb14b984d0de901d33bfcb8ba1c63490944866a716fea764c766",
  "apple-icon.png": "41431a167e8e7f9a2ce57a35105492dea3c60e6c34d940a8153e9f7d8c43a558",
};
for (const [name, hash] of Object.entries(pinned)) {
  const path = join(dist, name);
  check(existsSync(path) && sha256(path) === hash, `${name} sha256 ${hash.slice(0, 12)}…`);
}

const html = readFileSync(join(dist, "index.html"), "utf8");
const attr = (tag: string, name: string): string | undefined =>
  new RegExp(`\\s${name}="([^"]*)"`).exec(tag)?.[1];

// 2. No JavaScript at all.
check(!/<script\b/i.test(html), "no <script> in index.html");
check(!readdirSync(join(dist, "assets")).some((f) => f.endsWith(".js")), "no .js files in the export");

// 3. Head: title, description, share tags, icons.
const meta = (key: string): string | undefined => {
  const tag = html.match(new RegExp(`<meta (?:name|property)="${key}"[^>]*>`))?.[0];
  return tag ? attr(tag, "content") : undefined;
};
const lede = "A fixed supply of one billion. Every trade pays Solomon, and stakers share what he doesn't use.";
check(/<title>SVO · Sovrn\.One<\/title>/.test(html), "title is 'SVO · Sovrn.One'");
check(meta("description") === `SVO: ${lede.charAt(0).toLowerCase()}${lede.slice(1)}`, "meta description");
check(meta("og:title") === "SVO · Sovrn.One", "og:title");
check(meta("og:description") === lede, "og:description");
check(meta("og:image") === "banner.jpg", "og:image is banner.jpg (relative)");
check(meta("twitter:card") === "summary_large_image", "twitter:card");
check(/<link rel="icon" href="icon\.png" type="image\/png">/.test(html), "favicon is icon.png");
check(/<link rel="apple-touch-icon" href="apple-icon\.png">/.test(html), "apple-touch-icon is apple-icon.png");

// 4. Every <a href>, in document order, with its target/rel.
const expected: Array<[text: string, href: string, newTab: boolean]> = [
  ["Sovrn.One", "https://sovrn.one/", false],
  ["Swap", "https://sovrn.one/swap", false],
  ["Stake", "https://sovrn.one/stake", false],
  ["Talk to Solomon", "https://sovrn.one/ai/coach", false],
  ["Stake", "https://sovrn.one/stake", false],
  ["Buy", "https://sovrn.one/swap", false],
  ["Talk to Solomon", "https://sovrn.one/ai/coach", false],
  ["sovrn.one", "https://sovrn.one/", false],
  ["X", "https://x.com/sovrnimd", true],
  ["Telegram", "https://t.me/+h2udv9ZKYOswOWQx", true],
];
const anchors = [...html.matchAll(/<a\b([^>]*)>([\s\S]*?)<\/a>/g)].map((m) => ({
  open: m[1],
  text: m[2].replace(/<[^>]+>/g, "").replace(/\s+/g, " ").trim(),
}));
check(anchors.length === expected.length, `exactly ${expected.length} links (found ${anchors.length})`);
expected.forEach(([text, href, newTab], i) => {
  const a = anchors[i];
  const ok =
    a !== undefined &&
    a.text === text &&
    attr(a.open, "href") === href &&
    (newTab
      ? attr(a.open, "target") === "_blank" && attr(a.open, "rel") === "noopener noreferrer"
      : attr(a.open, "target") === undefined);
  check(ok, `link ${i + 1}: "${text}" -> ${href}${newTab ? " (new tab, noopener noreferrer)" : ""}`);
});

// 5. Visible text in order: header, hero, footer, and nothing else.
const body = html.slice(html.indexOf("<body>"));
const words = body.replace(/<[^>]+>/g, " ").replace(/\s+/g, " ").trim();
check(
  words ===
    "Sovrn.One Swap Stake Talk to Solomon Stake SVO. Share in Solomon. SVO " +
      `${lede} Stake Buy Talk to Solomon Sovrn.One sovrn.one X Telegram`,
  "page text is exactly the approved copy, in order",
);
check(/<header class="header">[\s\S]*<main class="hero">[\s\S]*<footer class="footer">/.test(body), "header, hero, footer in order");

// 6. Non-link URLs are relative and resolve inside the export; nothing third party loads.
const cssFiles = readdirSync(join(dist, "assets")).filter((f) => f.endsWith(".css"));
const refs: Array<[from: string, url: string]> = [];
for (const m of html.matchAll(/<(?:link|img|source|meta)\b[^>]*>/g)) {
  for (const key of ["href", "src", "srcset"]) {
    const v = attr(m[0], key);
    if (v !== undefined) refs.push([".", v]);
  }
  if (/property="og:image"/.test(m[0])) refs.push([".", attr(m[0], "content") ?? ""]);
}
for (const m of html.matchAll(/url\(\s*['"]?([^'")]+)/g)) refs.push([".", m[1]]);
for (const f of cssFiles) {
  for (const m of readFileSync(join(dist, "assets", f), "utf8").matchAll(/url\(\s*['"]?([^'")]+)/g)) refs.push(["assets", m[1]]);
}
for (const [from, url] of refs) {
  const relative = !/^([a-z]+:|\/)/i.test(url);
  check(relative && existsSync(join(dist, from, url.split(/[?#]/)[0])), `relative asset resolves: ${from}/${url}`);
}
const thirdParty = [html, ...cssFiles.map((f) => readFileSync(join(dist, "assets", f), "utf8"))]
  .join("\n")
  .replace(/<a\b[^>]*>/g, "")
  .match(/(?:https?:)?\/\/[a-z0-9.-]+\.[a-z]{2,}/gi);
check(thirdParty === null, `no third-party URL outside the links${thirdParty ? ` (${thirdParty.join(", ")})` : ""}`);

console.log(failures.length === 0 ? "\nall export checks passed" : `\n${failures.length} export check(s) failed`);
process.exit(failures.length === 0 ? 0 : 1);
