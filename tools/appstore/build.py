#!/usr/bin/env python3
"""App Store-beelden van Pairr: schermafbeeldingen (iPhone, iPad, Mac, Apple Watch) en productpagina-beelden, NL en EN.

    python3 tools/appstore/build.py      # HTML naar web/_appstore/ (tijdelijk)
    node tools/appstore/render.js        # PNG's naar AppStore/screenshots en AppStore/marketing (web/ op localhost:8822)

De schermen zijn nagemaakt in HTML op basis van de SwiftUI-code (screens.py), geen simulatorcaptures.
"""
import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import screens as S  # noqa: E402

B = S.B
OUT = B.OUT / "_appstore"

HEAD = {
    "list": (("Al je koppelcodes op één plek", "Per apparaat, kamer en soort code"),
             ("All your setup codes in one place", "By device, room and code type")),
    "scan": (("Scan gewoon de sticker", "QR, cijfers, een foto of NFC"),
             ("Just scan the sticker", "QR, printed digits, a photo or NFC")),
    "detail": (("Merk en model vanzelf ingevuld", "En gecontroleerd op typfouten"),
               ("Brand and model filled in", "And checked for typos")),
    "code": (("Later weer scannen als QR", "Voor Woning, Matter-apps en je hub"),
             ("Scan it again as a QR", "For Home, Matter apps and your hub")),
    "settings": (("Versleuteld in je eigen iCloud", "Face ID, geen account, blijft bewaard"),
                 ("Encrypted in your own iCloud", "Face ID, no account, never lost")),
}

BASE_CSS = """
html,body{margin:0;overflow:hidden}
body{background:#091828;position:relative;font-family:Inter,sans-serif}
.g1,.g2{position:absolute;border-radius:50%;pointer-events:none}
.g1{background:radial-gradient(closest-side,rgba(56,200,255,.34),transparent 70%)}
.g2{background:radial-gradient(closest-side,rgba(46,211,163,.26),transparent 70%)}
.hd{position:absolute;left:0;right:0;text-align:center;color:#fff;padding:0 6%}
.hd h1{font:800 1em/1.05 Jakarta,Inter,sans-serif;letter-spacing:-.03em;margin:0;color:#fff}
.hd p{margin:.45em 0 0;color:#AFC2D6;font-size:.5em;line-height:1.3}
.frame{position:absolute;background:#0b0d10;box-shadow:0 40px 80px -30px rgba(0,0,0,.7),inset 0 0 0 2px #2a2f36}
.scr{position:absolute;overflow:hidden;background:#F2F2F7}
.scr>.in{position:absolute;left:0;top:0;transform-origin:0 0}
""" + S.CSS


def glows(w, h):
    g = max(w, h)
    return (f'<span class="g1" style="width:{g}px;height:{g}px;right:-{g//3}px;top:-{g//3}px"></span>'
            f'<span class="g2" style="width:{int(g*.9)}px;height:{int(g*.9)}px;left:-{g//2}px;bottom:-{g//3}px"></span>')


def page(w, h, body, extra_css=""):
    return (f'<!doctype html><html><head><meta charset="utf-8"><link rel="stylesheet" href="/assets/style.css">'
            f'<style>html,body{{width:{w}px;height:{h}px}}{BASE_CSS}{extra_css}</style></head><body>{glows(w, h)}{body}</body></html>')


def headline(lang, key, top, size):
    h1, sub = HEAD[key][0 if lang == "nl" else 1]
    return f'<div class="hd" style="top:{top}px;font-size:{size}px"><h1>{h1}</h1><p>{sub}</p></div>'


# ---- iPhone (scherm 393×852 pt) ----
def iphone_inner(lang, key):
    if key == "list":
        body = S.screen_list(lang)
    elif key == "scan":
        return f'<div class="ios dark">{S.screen_scan(lang)}<div class="home"></div></div>'
    elif key == "detail":
        body = S.screen_detail(lang)
    elif key == "code":
        body = f'<div style="position:absolute;inset:0;background:#000"></div>{S.screen_code(lang)}'
        return f'<div class="ios dark">{body}<div class="home" style="background:#000"></div></div>'
    else:
        body = S.screen_settings(lang)
    return f'<div class="ios">{body}<div class="home"></div></div>'


def iphone_page(lang, key, w, h):
    sw = w * 0.80
    scale = (sw - 24) / 393
    fh = 852 * scale + 24
    top = h * 0.215
    frame = (f'<div class="frame" style="left:{(w-sw)/2}px;top:{top}px;width:{sw}px;height:{fh}px;border-radius:{62*scale+12}px">'
             f'<div class="scr" style="left:12px;top:12px;width:{sw-24}px;height:{fh-24}px;border-radius:{55*scale}px">'
             f'<div class="in" style="width:393px;height:852px;transform:scale({scale})">{iphone_inner(lang, key)}</div></div></div>')
    return page(w, h, headline(lang, key, h * 0.055, w * 0.085) + frame)


# ---- iPad (scherm 1032×1376 pt, staand) en Mac (venster 1440×900) ----
def split_inner(lang, key, mac=False):
    t = lambda nl, en: S.T(lang, nl, en)  # noqa: E731
    W, H = (1440, 900) if mac else (1032, 1376)
    side_w = 230 if mac else 0
    list_w = 340 if mac else 380
    detail = S.screen_detail(lang, status=False, back=False)
    side = (f'<div style="position:absolute;left:0;top:0;bottom:0;width:{side_w}px;background:#E9E9EE;padding:46px 10px 0;color:#000">{S.sidebar(lang, True)}</div>' if mac else "")
    lst = (f'<div class="ios" style="left:{side_w}px;width:{list_w}px;right:auto;border-right:.5px solid #C6C6C8;'
           f'padding-top:{24 if mac else 54}px">{S.screen_list(lang, chevron=False, selected=t("Stekker tv", "TV plug"), status=False)}</div>')
    det = f'<div class="ios" style="left:{side_w+list_w}px;{"padding-top:24px" if mac else "padding-top:54px"}">{detail}</div>'
    over = ""
    if key in ("code", "settings"):
        inner = (S.screen_code(lang, status=False) if key == "code" else
                 f'<div class="ios" style="border-radius:12px">{S.screen_settings(lang).replace(S.statusbar(), "")}</div>')
        mw, mh = (540, 720) if not mac else (500, 680)
        over = (f'<div style="position:absolute;inset:0;background:rgba(0,0,0,.35)"></div>'
                f'<div style="position:absolute;left:{(W-mw)/2}px;top:{(H-mh)/2}px;width:{mw}px;height:{mh}px;border-radius:14px;overflow:hidden;background:#fff;box-shadow:0 30px 60px rgba(0,0,0,.35)">'
                f'<div class="ios" style="background:{"#fff" if key == "code" else "#F2F2F7"}">{inner if key == "settings" else inner.replace("inset:10px 0 0", "inset:0")}</div></div>')
    bar = ""
    if mac:
        bar = ('<div style="position:absolute;left:0;right:0;top:0;height:46px;display:flex;gap:8px;align-items:center;padding:0 18px;z-index:3">'
               '<i style="width:12px;height:12px;border-radius:50%;background:#FF5F57"></i><i style="width:12px;height:12px;border-radius:50%;background:#FEBC2E"></i>'
               '<i style="width:12px;height:12px;border-radius:50%;background:#28C840"></i></div>')
    sb = "" if mac else f'<div style="position:absolute;left:0;right:0;top:0;z-index:4">{S.statusbar()}</div>'
    return f'<div style="position:absolute;inset:0;background:#F2F2F7">{side}{lst}{det}{over}{bar}{sb}</div>'


def ipad_page(lang, key, w, h):
    sw = w * 0.84
    scale = (sw - 36) / 1032
    fh = 1376 * scale + 36
    frame = (f'<div class="frame" style="left:{(w-sw)/2}px;top:{h*0.2}px;width:{sw}px;height:{fh}px;border-radius:{40*scale+18}px">'
             f'<div class="scr" style="left:18px;top:18px;width:{sw-36}px;height:{fh-36}px;border-radius:{24*scale}px">'
             f'<div class="in" style="width:1032px;height:1376px;transform:scale({scale})">{split_inner(lang, key)}</div></div></div>')
    return page(w, h, headline(lang, key, h * 0.05, w * 0.06) + frame)


def mac_page(lang, key, w, h):
    sw = w * 0.72
    scale = (sw - 2 * 14) / 1440
    sh = 900 * scale + 28
    top = h * 0.19
    lid = (f'<div class="frame" style="left:{(w-sw)/2}px;top:{top}px;width:{sw}px;height:{sh}px;border-radius:{18*scale+6}px">'
           f'<div class="scr" style="left:14px;top:14px;width:{sw-28}px;height:{sh-28}px;border-radius:{8*scale}px;background:linear-gradient(135deg,#0F3350,#14A884)">'
           f'<div class="in" style="width:1440px;height:900px;transform:scale({scale})">'
           f'<div style="position:absolute;inset:0;border-radius:12px;overflow:hidden">{split_inner(lang, key, mac=True)}</div></div></div></div>')
    base = (f'<div style="position:absolute;left:{w*0.06}px;width:{w*0.88}px;top:{top+sh-2}px;height:{w*0.016}px;'
            f'background:linear-gradient(#cfd3d8,#9aa0a7);border-radius:0 0 {w*0.02}px {w*0.02}px"></div>')
    return page(w, h, headline(lang, key, h * 0.045, w * 0.042) + lid + base)


# ---- Apple Watch: alleen het scherm ----
def watch_page(lang, key, w, h):
    s = w / 208
    inner = S.watch_list(lang) if key == "list" else S.watch_screen(lang)
    return (f'<!doctype html><html><head><meta charset="utf-8"><link rel="stylesheet" href="/assets/style.css"><style>html,body{{margin:0;width:{w}px;height:{h}px;overflow:hidden;background:#000}}</style></head>'
            f'<body><div style="position:absolute;left:0;top:0;width:208px;height:{h/s}px;transform:scale({s});transform-origin:0 0">{inner}</div></body></html>')


# ---- productpagina-beelden ----
def marketing_page(lang, w, h):
    p = B.Page(lang)
    t = B.Page(lang).t
    h1 = t('Nooit meer een <span class="grad">koppelcode</span> kwijt.', 'Never lose a <span class="grad">setup code</span> again.')
    sub = t("Al je HomeKit-, Matter-, Zigbee-, Hue- en Z-Wave-codes veilig op één plek. Gratis.",
            "All your HomeKit, Matter, Zigbee, Hue and Z-Wave codes safe in one place. Free.")
    u = h / 100  # eenheid
    css = (f".mk{{position:absolute;inset:0;display:grid;grid-template-columns:1.1fr .9fr;align-items:center;padding:0 {7*u*w/h/1.78}px}}"
           f".mk h1{{font:800 {11*u}px/1.02 Jakarta;color:#fff;letter-spacing:-.035em;margin:0}}"
           f".mk h1 .grad{{background:linear-gradient(100deg,#38C8FF 10%,#2ED3A3 90%);-webkit-background-clip:text;background-clip:text;color:transparent}}"
           f".mk p{{font-size:{3.6*u}px;color:#AFC2D6;margin:{2.4*u}px 0 0;line-height:1.35;max-width:22em}}"
           f".mk .brand{{display:flex;align-items:center;gap:{1.6*u}px;font:800 {5.2*u}px/1 Jakarta;color:#fff;margin-bottom:{4*u}px}}"
           f".mk .brand img{{width:{9*u}px;height:{9*u}px;border-radius:{2.1*u}px}}"
           f".mk .st{{position:relative;height:{100*u}px}}"
           f".mk .stage{{position:absolute;left:50%;top:50%;width:460px;height:640px;transform:translate(-50%,-50%) scale({h/720});}}"
           f".row{{opacity:1;transform:none;animation:none}}.watch,.badge-float{{animation:none}}")
    if w / h < 1.6:  # 3:2 en 1920×1280: iets grotere tekst
        css += f".mk{{grid-template-columns:1fr 1fr}}.mk h1{{font-size:{9.5*u}px}}"
    if w / h > 2.2:  # breed: 3840×1646
        css += f".mk{{grid-template-columns:1.25fr .75fr}}.mk h1{{font-size:{12*u}px}}"
    body = (f'<div class="mk"><div><div class="brand"><img src="/assets/img/icon-512.png" alt="">Pairr</div><h1>{h1}</h1><p>{sub}</p></div>'
            f'<div class="st">{B.phone(p).replace(">Apparaten<", ">Alle apparaten<").replace(">Devices<", ">All devices<").replace("⌕ Zoeken", "⌕ Zoek apparaten").replace("⌕ Search", "⌕ Search devices")}</div></div>')
    return page(w, h, body, css)


SETS = {
    # map: (functie, breedte in css-px, hoogte, schaal, schermen)
    "iphone-6.3": (iphone_page, 402, 874, 3, ["list", "scan", "detail", "code", "settings"]),
    "iphone-6.1": (iphone_page, 393, 852, 3, ["list", "scan", "detail", "code", "settings"]),
    "ipad-13": (ipad_page, 1032, 1376, 2, ["list", "code", "settings"]),
    "ipad-12.9": (ipad_page, 1024, 1366, 2, ["list", "code", "settings"]),
    "mac-2880x1800": (mac_page, 1440, 900, 2, ["list", "code", "settings"]),
    "mac-2560x1600": (mac_page, 1280, 800, 2, ["list", "code", "settings"]),
    "mac-1440x900": (mac_page, 1440, 900, 1, ["list", "code", "settings"]),
    "mac-1280x800": (mac_page, 1280, 800, 1, ["list", "code", "settings"]),
    "watch-416x496": (watch_page, 208, 248, 2, ["code", "list"]),
    "watch-422x514": (watch_page, 211, 257, 2, ["code", "list"]),
}
MARKETING = {"header_5244x2950": (1311, 737.5, 4), "header_3840x1646": (1280, 548.67, 3),
             "search_5244x2950": (1311, 737.5, 4), "search_3840x2560": (1280, 853.33, 3), "search_1920x1280": (960, 640, 2)}

if __name__ == "__main__":
    jobs = []
    for lang in ("nl", "en"):
        loc = "nl-NL" if lang == "nl" else "en-US"
        for folder, (fn, w, h, s, keys) in SETS.items():
            for i, key in enumerate(keys, 1):
                name = f"{i:02d}_{key}_{w*s}x{h*s}"
                f = OUT / loc / folder / f"{name}.html"
                f.parent.mkdir(parents=True, exist_ok=True)
                f.write_text(fn(lang, key, w, h))
                jobs.append({"html": f"{loc}/{folder}/{name}.html", "png": f"screenshots/{loc}/{folder}/{name}.png", "w": w, "h": h, "s": s})
        for name, (w, h, s) in MARKETING.items():
            f = OUT / loc / "marketing" / f"{name}.html"
            f.parent.mkdir(parents=True, exist_ok=True)
            W, H = (int(x) for x in name.split("_")[1].split("x"))
            f.write_text(marketing_page(lang, round(w), round(h)))
            jobs.append({"html": f"{loc}/marketing/{name}.html", "png": f"marketing/{loc}/{name}.png", "w": round(w), "h": round(h), "s": s, "W": W, "H": H})
    (OUT / "jobs.json").write_text(json.dumps(jobs))
    print(len(jobs), "beelden")
