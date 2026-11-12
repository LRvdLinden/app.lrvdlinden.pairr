// node tools/social/render.js <uitvoermap>  (web/ moet geserveerd worden op http://localhost:8822)
const { chromium } = require("playwright");
const fs = require("fs"), path = require("path");
const out = process.argv[2];
const sizes = { "instagram-post-1080x1080": [1080, 1080], "instagram-post-1080x1350": [1080, 1350], "story-1080x1920": [1080, 1920],
  "facebook-cover-1640x624": [1640, 624], "linkedin-cover-1584x396": [1584, 396] };
(async () => {
  const b = await chromium.launch();
  for (const lang of ["nl", "en"]) {
    fs.mkdirSync(path.join(out, lang), { recursive: true });
    for (const [k, [w, h]] of Object.entries(sizes)) {
      const p = await b.newPage({ viewport: { width: w, height: h }, deviceScaleFactor: 1, reducedMotion: "reduce" });
      await p.goto(`http://localhost:8822/_social/${lang}/${k}.html`);
      await p.waitForTimeout(500);
      await p.screenshot({ path: path.join(out, lang, `${k}.png`) });
      await p.close();
    }
  }
  await b.close();
})();
