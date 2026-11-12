#!/usr/bin/env python3
"""Social-banners van Pairr (algemene promotie, app + website), NL en EN.

    python3 tools/social/build.py            # schrijft HTML naar web/_social/ (tijdelijk, voor de render)
    node tools/social/render.js <map>        # rendert naar social/pairr-<datum>/<nl|en>/

De telefoon is dezelfde HTML-weergave van de app als op de website (tools/web/build.py).
"""
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "web"))
import build as B  # noqa: E402

FORMATS = {
    "instagram-post-1080x1080": (1080, 1080, "sq"),
    "instagram-post-1080x1350": (1080, 1350, "pt"),
    "story-1080x1920": (1080, 1920, "st"),
    "facebook-cover-1640x624": (1640, 624, "fb"),
    "linkedin-cover-1584x396": (1584, 396, "li"),
}

CSS = """
html,body{margin:0;overflow:hidden}
body{background:#091828;color:#C9D6E3;position:relative;font-family:Inter,system-ui,sans-serif}
.glow1,.glow2{position:absolute;border-radius:50%;pointer-events:none}
.glow1{background:radial-gradient(closest-side,rgba(56,200,255,.32),transparent 70%)}
.glow2{background:radial-gradient(closest-side,rgba(46,211,163,.24),transparent 70%)}
.brand{display:flex;align-items:center;gap:.4em;font:800 1em/1 Jakarta;color:#fff}
.brand img{width:1.8em;height:1.8em;border-radius:.42em}
h1{color:#fff;margin:0;letter-spacing:-.035em;line-height:1.02}
h1 .grad{background:linear-gradient(100deg,#38C8FF 10%,#2ED3A3 90%);-webkit-background-clip:text;background-clip:text;color:transparent}
.sub{color:#AFC2D6;margin:0;line-height:1.35}
.chips{margin:0;gap:10px}
.chip{background:#0F2438;border-color:#1d3550;color:#fff}
.cta{display:flex;align-items:center;gap:18px;margin:0}
.url{font:800 1em/1 Jakarta;color:#fff}
.store.soon{background:#fff;color:#000} .store.soon svg{fill:#000}
.row{opacity:1;transform:none;animation:none} .watch,.badge-float{animation:none}
.stage{position:relative}
/* vierkant en staand */
.v{position:absolute;inset:0;display:flex;flex-direction:column;padding:var(--pad) var(--pad) 0}
.v .brand{font-size:44px;margin-bottom:var(--g1)}
.v h1{font-size:var(--h1)} .v .sub{font-size:var(--sub);margin-top:var(--g2)}
.v .chips{margin-top:var(--g2)} .v .chip{font-size:22px;padding:8px 16px 8px 9px} .v .chip i{width:28px;height:28px} .v .chip i svg{width:17px;height:17px}
.v .cta{margin-top:var(--g2)} .v .url{font-size:32px}
.v .stage{flex:1;margin-top:var(--g3);height:auto}
.v .phone{transform:translateX(-50%) scale(var(--ps));transform-origin:top center;left:var(--px)}
.v .watch{right:var(--wx);bottom:auto;top:var(--wy);transform:scale(var(--ws));transform-origin:top right}
.v .bf1{left:var(--bx);top:var(--by);transform:scale(1.4);transform-origin:left top}
.v .bf2{left:auto;right:var(--b2x);bottom:auto;top:var(--b2y);transform:scale(1.4);transform-origin:right top}
.sq{--pad:72px;--h1:76px;--sub:30px;--g1:34px;--g2:22px;--g3:20px;--ps:1.05;--px:58%;--wx:2%;--wy:120px;--ws:1.25;--bx:2%;--by:40px;--b2x:-10px;--b2y:420px}
.sq .chips{display:none}
.pt{--pad:80px;--h1:84px;--sub:32px;--g1:40px;--g2:26px;--g3:30px;--ps:1.15;--px:58%;--wx:5%;--wy:150px;--ws:1.35;--bx:2%;--by:60px;--b2x:-10px;--b2y:470px}
.st{--pad:96px;--h1:104px;--sub:40px;--g1:44px;--g2:34px;--g3:50px;--ps:1.45;--px:46%;--wx:-1%;--wy:330px;--ws:1.35;--bx:-1%;--by:90px;--b2x:-20px;--b2y:760px}
.st .bf2{display:none}
.st .v{padding-top:290px}
.st .chip{font-size:26px} .st .url{font-size:38px}
.st .store{transform:scale(1.45);transform-origin:left center;margin-right:62px}
/* covers */
.h{position:absolute;inset:0;display:grid;align-items:center}
.h .brand{font-size:34px;margin-bottom:22px}
.fb .h{grid-template-columns:1fr 520px;padding:0 250px}
.fb h1{font-size:64px} .fb .sub{font-size:24px;margin-top:16px} .fb .cta{margin-top:24px} .fb .url{font-size:26px}
.fb .stage{height:624px} .fb .phone{transform:translateX(-50%) scale(.82);transform-origin:center 32%;top:30px}
.fb .watch{right:20px;bottom:110px;transform:scale(.9)} .fb .badge-float{display:none}
.li .h{grid-template-columns:1fr 470px;padding:0 120px 0 420px}
.li .brand{display:none}
.li h1{font-size:50px} .li .sub{font-size:21px;margin-top:12px} .li .cta{margin-top:18px} .li .url{font-size:22px}
.li .stage{height:396px} .li .phone{transform:translateX(-50%) scale(.7);transform-origin:top center;top:36px}
.li .watch{right:10px;bottom:30px;transform:scale(.7);transform-origin:bottom right} .li .badge-float{display:none}
.li .store,.fb .store{transform:scale(.95);transform-origin:left center}
"""

TEXT = {
    "nl": dict(h1='Nooit meer een <span class="grad">koppelcode</span> kwijt.',
               sub="HomeKit, Matter, Zigbee, Hue en Z-Wave veilig op één plek. Gratis, versleuteld in iCloud."),
    "en": dict(h1='Never lose a <span class="grad">setup code</span> again.',
               sub="HomeKit, Matter, Zigbee, Hue and Z-Wave safe in one place. Free, encrypted in iCloud."),
}


def page(lang: str, key: str) -> str:
    w, h, cls = FORMATS[key]
    p = B.Page(lang)
    t = TEXT[lang]
    chips = "".join(f'<span class="chip"><i style="background:{c[1]}">{B.ic(c[2])}</i>{c[3] if lang == "nl" else c[4]}</span>'
                    for c in B.CODE_TYPES[:5])
    cta = f'<div class="cta">{B.store_badge(p)}<span class="url">pairr.lrvdlinden.app</span></div>'
    brand = '<div class="brand"><img src="/assets/img/icon-192.png" alt="">Pairr</div>'
    g = max(w, h)
    glows = (f'<span class="glow1" style="width:{g}px;height:{g}px;right:-{g//4}px;top:-{g//3}px"></span>'
             f'<span class="glow2" style="width:{int(g*.8)}px;height:{int(g*.8)}px;left:-{g//3}px;bottom:-{g//3}px"></span>')
    if cls in ("sq", "pt", "st"):
        body = f'<div class="v">{brand}<h1>{t["h1"]}</h1><p class="sub">{t["sub"]}</p><div class="chips">{chips}</div>{cta}{B.phone(p)}</div>'
    else:
        body = f'<div class="h"><div>{brand}<h1>{t["h1"]}</h1><p class="sub">{t["sub"]}</p>{cta}</div>{B.phone(p)}</div>'
    return (f'<!doctype html><html lang="{lang}"><head><meta charset="utf-8"><link rel="stylesheet" href="/assets/style.css">'
            f'<style>html,body{{width:{w}px;height:{h}px}}{CSS}</style></head><body class="{cls}">{glows}{body}</body></html>')


if __name__ == "__main__":
    out = B.OUT / "_social"
    for lang in ("nl", "en"):
        for key in FORMATS:
            f = out / lang / f"{key}.html"
            f.parent.mkdir(parents=True, exist_ok=True)
            f.write_text(page(lang, key))
    print(out)
