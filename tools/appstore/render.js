// node tools/appstore/render.js <AppStore-map>   (web/ geserveerd op http://localhost:8822; daarna tools/appstore/finish.py)
const { chromium } = require("playwright");
const fs = require("fs"), path = require("path");
const out = process.argv[2];
(async () => {
  const jobs = JSON.parse(fs.readFileSync(process.argv[3], "utf8"));
  const b = await chromium.launch();
  for (const j of jobs) {
    const p = await b.newPage({ viewport: { width: j.w, height: j.h }, deviceScaleFactor: j.s, reducedMotion: "reduce" });
    await p.goto("http://localhost:8822/_appstore/" + j.html);
    await p.waitForTimeout(250);
    const f = path.join(out, j.png);
    fs.mkdirSync(path.dirname(f), { recursive: true });
    await p.screenshot({ path: f });
    await p.close();
  }
  await b.close();
})();
