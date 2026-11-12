#!/usr/bin/env python3
"""Maakt de og:image van pairr.lrvdlinden.app (1200×630, Engelse tekst) als HTML in web/og/_og.html.
Renderen: zie README in tools/web (Playwright, 1200×630), daarna web/og/_og.html weer weghalen."""
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).parent))
import build as B

p = B.Page("en")
chips = "".join(f'<span class="chip"><i style="background:{c[1]}">{B.ic(c[2])}</i>{c[4]}</span>' for c in B.CODE_TYPES[:4])
html = f"""<!doctype html><html lang="en"><head><meta charset="utf-8">
<link rel="stylesheet" href="/assets/style.css">
<style>
html,body{{width:1200px;height:630px;margin:0;overflow:hidden}}
body{{background:#091828;color:#C9D6E3;position:relative}}
body::before{{content:"";position:absolute;right:-180px;top:-220px;width:900px;height:900px;background:radial-gradient(closest-side,rgba(56,200,255,.30),transparent 70%)}}
body::after{{content:"";position:absolute;left:-260px;bottom:-360px;width:800px;height:800px;background:radial-gradient(closest-side,rgba(46,211,163,.22),transparent 70%)}}
.og{{position:relative;z-index:1;display:grid;grid-template-columns:620px 1fr;height:630px;padding:0 0 0 72px;align-items:center}}
.brand{{display:flex;align-items:center;gap:16px;font:800 40px/1 "Jakarta";color:#fff;margin-bottom:34px}}
.brand img{{width:72px;height:72px;border-radius:17px}}
h1{{color:#fff;font-size:68px;line-height:1.02;margin:0 0 22px}}
h1 .grad{{background:linear-gradient(100deg,#38C8FF 10%,#2ED3A3 90%);-webkit-background-clip:text;background-clip:text;color:transparent}}
.sub{{font-size:25px;line-height:1.35;color:#AFC2D6;margin:0 0 28px}}
.chips{{margin:0}} .chip{{background:#0F2438;border-color:#1d3550;color:#fff;font-size:17px;padding:7px 14px 7px 8px}}
.chip i{{width:24px;height:24px}} .chip i svg{{width:15px;height:15px}}
.stage{{height:630px;transform:scale(.93);transform-origin:center 55%}}
.phone{{top:46px}} .watch{{animation:none;right:-6px;bottom:70px}} .row{{opacity:1;transform:none;animation:none}}
.badge-float{{animation:none}} .badge-float{{display:none}}
</style></head><body><div class="og"><div>
<div class="brand"><img src="/assets/img/icon-192.png" alt="">Pairr</div>
<h1>Never lose a <span class="grad">setup code</span> again.</h1>
<p class="sub">All your smart home codes, safe in one place.<br>Free · encrypted in your iCloud.</p>
<div class="chips">{chips}</div>
</div>{B.phone(p)}</div></body></html>"""
out = B.OUT / "og" / "_og.html"
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(html)
print(out)
