#!/usr/bin/env python3
"""Bouwt de website van Pairr (pairr.lrvdlinden.app) in web/.

Eén bron voor Nederlands (/) en Engels (/en/). Draai vanuit de root van de repo:

    python3 tools/web/build.py

Daarna staat de complete site in web/ (uploaden zoals hij is). Iconen: Lucide (ISC), in tools/web/src/icons.
"""
from __future__ import annotations

import html
import json
import re
import shutil
from datetime import date
from pathlib import Path

import qrcode

ROOT = Path(__file__).resolve().parents[2]
SRC = Path(__file__).resolve().parent / "src"
OUT = ROOT / "web"

DOMAIN = "https://pairr.lrvdlinden.app"
APP_STORE_URL = None  # bv. "https://apps.apple.com/app/pairr/id0000000000" zodra de app live is
APP_STORE_ID = None
TESTFLIGHT_URL = "https://testflight.apple.com/join/sSqpDw6n"  # bèta; alleen getoond zolang APP_STORE_URL leeg is
GITHUB = "https://github.com/LRvdLinden/app.lrvdlinden.pairr"
ISSUES = GITHUB + "/issues/new"
UPDATED = date(2026, 11, 12)
VERSION = "1.0.0"
QR_PAYLOAD = "MT:Y.K9042C00KA0648G00"

LANGS = ("nl", "en")
OG_ALT = ("Pairr on an iPhone and Apple Watch: a list of smart home devices with HomeKit, Matter, Zigbee and Hue codes, "
          "and a Matter QR code. Never lose a setup code again.")


# ---------------------------------------------------------------- helpers

def esc(s: str) -> str:
    return html.escape(s, quote=True)


_ICON_CACHE: dict[str, str] = {}


def ic(name: str, cls: str = "") -> str:
    if name not in _ICON_CACHE:
        raw = (SRC / "icons" / f"{name}.svg").read_text()
        raw = re.sub(r"<!--.*?-->", "", raw, flags=re.S)
        raw = re.sub(r'\s*class="[^"]*"', "", raw)
        raw = re.sub(r'\s*(width|height)="24"', "", raw)
        raw = re.sub(r"\s+", " ", raw).replace("> <", "><").strip()
        raw = raw.replace("<svg ", '<svg aria-hidden="true" focusable="false" ', 1)
        _ICON_CACHE[name] = raw
    s = _ICON_CACHE[name]
    if cls:
        s = s.replace("<svg ", f'<svg class="{cls}" ', 1)
    return s


APPLE = ('<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12.152 6.896c-.948 0-2.415-1.078-3.96-1.04-2.04.027-3.91 '
         '1.183-4.961 3.014-2.117 3.675-.546 9.103 1.519 12.09 1.013 1.454 2.208 3.09 3.792 3.039 1.52-.065 2.09-.987 3.935-.987 '
         '1.831 0 2.35.987 3.96.948 1.637-.026 2.676-1.48 3.676-2.948 1.156-1.688 1.636-3.325 1.662-3.415-.039-.013-3.182-1.221-3.22-4.857'
         '-.026-3.04 2.48-4.494 2.597-4.559-1.429-2.09-3.623-2.324-4.39-2.376-2-.156-3.675 1.09-4.61 1.09zM15.53 3.83c.843-1.012 '
         '1.4-2.427 1.245-3.83-1.207.052-2.662.805-3.532 1.818-.78.896-1.454 2.338-1.273 3.714 1.338.104 2.715-.688 3.559-1.701"/></svg>')


def qr_svg(payload: str, cls: str = "qr") -> str:
    q = qrcode.QRCode(border=0, error_correction=qrcode.constants.ERROR_CORRECT_M)
    q.add_data(payload)
    q.make(fit=True)
    m = q.get_matrix()
    n = len(m)
    d = "".join(f"M{x} {y}h1v1h-1z" for y, row in enumerate(m) for x, v in enumerate(row) if v)
    return (f'<svg class="{cls}" viewBox="0 0 {n} {n}" shape-rendering="crispEdges" role="img" aria-label="Matter QR">'
            f'<path fill="#0A1A2C" d="{d}"/></svg>')


# Codesoorten: id, kleur, icoon, naam nl/en
CODE_TYPES = [
    ("homekit", "var(--homekit)", "house", "HomeKit", "HomeKit"),
    ("matter", "var(--matter)", "hexagon", "Matter", "Matter"),
    ("zigbee", "var(--zigbee)", "zap", "Zigbee", "Zigbee"),
    ("hue", "var(--hue)", "lightbulb", "Philips Hue", "Philips Hue"),
    ("zwave", "var(--zwave)", "waves", "Z-Wave", "Z-Wave"),
    ("wifi", "var(--wifi)", "wifi", "Wifi", "Wi-Fi"),
    ("pin", "var(--pin)", "key-round", "Pincode", "PIN"),
]
CT = {c[0]: c for c in CODE_TYPES}


def tag(t: str) -> str:
    c = CT[t]
    return f'<i style="background:{c[1]}" title="{c[3]}">{ic(c[2])}</i>'


class Page:
    def __init__(self, lang: str):
        self.lang = lang

    def t(self, nl: str, en: str) -> str:
        return nl if self.lang == "nl" else en

    def url(self, path: str, lang: str | None = None) -> str:
        lang = lang or self.lang
        return ("/en" + path) if lang == "en" else path


# ---------------------------------------------------------------- layout

ROOT_LANG_JS = (
    "(function(){try{var p=location.pathname;if(p!=='/'&&p!=='/index.html')return;"
    "var s=null;try{s=localStorage.getItem('pairr.lang')}catch(e){}"
    "if(!s){var m=document.cookie.match(/(?:^|; )pairr_lang=(nl|en)/);s=m&&m[1]}"
    "if(s==='nl')return;if(s==='en'){location.replace('/en/'+location.search+location.hash);return}"
    "if(/bot|crawl|spider|slurp|facebookexternalhit|preview|lighthouse/i.test(navigator.userAgent))return;"
    "var tz=(Intl.DateTimeFormat().resolvedOptions().timeZone)||'';"
    "if(tz&&tz!=='Europe/Amsterdam'&&tz!=='America/Kralendijk')location.replace('/en/'+location.search+location.hash)"
    "}catch(e){}})();"
)


def head(p: Page, path: str, title: str, desc: str, og_title: str, og_desc: str, og_alt: str,
         ld: list[dict] | None = None, index: bool = True, keywords: str = "") -> str:
    canon = DOMAIN + p.url(path)
    og_img = f"{DOMAIN}/og/pairr-en.png"  # één deelafbeelding met Engelse tekst (keuze Léon), ook op de NL-pagina's
    alt_nl, alt_en = DOMAIN + path, DOMAIN + "/en" + path
    out = [
        "<!doctype html>",
        f'<html lang="{p.lang}">',
        "<head>",
        '<meta charset="utf-8">',
        '<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">',
    ]
    if p.lang == "nl" and path == "/":
        out.append(f"<script>{ROOT_LANG_JS}</script>")
    out += [
        f"<title>{esc(title)}</title>",
        f'<meta name="description" content="{esc(desc)}">',
    ]
    if keywords:
        out.append(f'<meta name="keywords" content="{esc(keywords)}">')
    out += [
        f'<meta name="robots" content="{"index, follow, max-image-preview:large" if index else "noindex, nofollow"}">',
        '<meta name="author" content="Léon van der Linden">',
        '<meta name="application-name" content="Pairr">',
        '<meta name="apple-mobile-web-app-title" content="Pairr">',
        '<meta name="format-detection" content="telephone=no">',
    ]
    if APP_STORE_ID:
        out.append(f'<meta name="apple-itunes-app" content="app-id={APP_STORE_ID}">')
    out += [
        '<meta name="theme-color" content="#F4F8FC" media="(prefers-color-scheme: light)">',
        '<meta name="theme-color" content="#071321" media="(prefers-color-scheme: dark)">',
        f'<link rel="canonical" href="{canon}">',
    ]
    if index:
        out += [
            f'<link rel="alternate" hreflang="nl" href="{alt_nl}">',
            f'<link rel="alternate" hreflang="en" href="{alt_en}">',
            f'<link rel="alternate" hreflang="x-default" href="{alt_en}">',
        ]
    out += [
        '<meta property="og:type" content="website">',
        '<meta property="og:site_name" content="Pairr">',
        f'<meta property="og:url" content="{canon}">',
        f'<meta property="og:title" content="{esc(og_title)}">',
        f'<meta property="og:description" content="{esc(og_desc)}">',
        f'<meta property="og:image" content="{og_img}">',
        '<meta property="og:image:type" content="image/png">',
        '<meta property="og:image:width" content="1200">',
        '<meta property="og:image:height" content="630">',
        f'<meta property="og:image:alt" content="{esc(OG_ALT)}">',
        f'<meta property="og:locale" content="{"nl_NL" if p.lang == "nl" else "en_US"}">',
        f'<meta property="og:locale:alternate" content="{"en_US" if p.lang == "nl" else "nl_NL"}">',
        '<meta name="twitter:card" content="summary_large_image">',
        f'<meta name="twitter:title" content="{esc(og_title)}">',
        f'<meta name="twitter:description" content="{esc(og_desc)}">',
        f'<meta name="twitter:image" content="{og_img}">',
        f'<meta name="twitter:image:alt" content="{esc(OG_ALT)}">',
        '<link rel="icon" href="/favicon.ico" sizes="any">',
        '<link rel="icon" type="image/png" sizes="32x32" href="/assets/img/favicon-32.png">',
        '<link rel="apple-touch-icon" href="/assets/img/apple-touch-icon.png">',
        '<link rel="manifest" href="/site.webmanifest">',
        '<link rel="preload" href="/assets/fonts/inter-latin-400-normal.woff2" as="font" type="font/woff2" crossorigin>',
        '<link rel="preload" href="/assets/fonts/plus-jakarta-sans-latin-800-normal.woff2" as="font" type="font/woff2" crossorigin>',
        '<link rel="stylesheet" href="/assets/style.css?v=1">',
    ]
    for block in ld or []:
        out.append('<script type="application/ld+json">' + json.dumps(block, ensure_ascii=False, separators=(",", ":")) + "</script>")
    out.append('<script src="/assets/site.js?v=1" defer></script>')
    out.append("</head>")
    return "\n".join(out)


def header(p: Page, path: str, home: bool) -> str:
    base = p.url("/")
    a = (lambda frag: f"{base}#{frag}") if not home else (lambda frag: f"#{frag}")
    nl_href, en_href = path, "/en" + path
    return f"""<body>
<a class="skip" href="#main">{p.t("Naar de inhoud", "Skip to content")}</a>
<header class="top">
  <div class="wrap">
    <a class="brand" href="{base}" aria-label="Pairr, {p.t("naar de startpagina", "home")}"><img src="/assets/img/icon-128.png" alt="" width="34" height="34">Pairr</a>
    <nav class="nav" aria-label="{p.t("Hoofdmenu", "Main menu")}">
      <a href="{a("hoe")}">{p.t("Zo werkt het", "How it works")}</a>
      <a href="{a("codes")}">{p.t("Codes", "Codes")}</a>
      <a href="{a("veilig")}">{p.t("Veiligheid", "Security")}</a>
      <a href="{a("faq")}">{p.t("Vragen", "FAQ")}</a>
    </nav>
    <div class="lang" role="group" aria-label="{p.t("Taal", "Language")}">
      <a href="{nl_href}" hreflang="nl" lang="nl" data-lang="nl"{' aria-current="true"' if p.lang == "nl" else ""}>NL</a>
      <a href="{en_href}" hreflang="en" lang="en" data-lang="en"{' aria-current="true"' if p.lang == "en" else ""}>EN</a>
    </div>
    <a class="btn btn-primary" href="{a("download")}">{p.t("Download", "Download")}</a>
  </div>
</header>"""


def store_badge(p: Page) -> str:
    if APP_STORE_URL:
        return (f'<a class="store" href="{APP_STORE_URL}" rel="noopener">{APPLE}<span><small>'
                f'{p.t("Download in de", "Download on the")}</small><b>App Store</b></span></a>')
    soon = (f'<span class="store soon" role="note">{APPLE}<span><small>{p.t("Binnenkort in de", "Coming soon to the")}</small>'
            f'<b>App Store</b></span></span>')
    if TESTFLIGHT_URL:
        soon += (f'<a class="btn btn-primary beta" href="{TESTFLIGHT_URL}" rel="noopener">'
                 f'{p.t("Doe mee met de bèta", "Join the beta")}<small>TestFlight</small></a>')
    return soon


def footer(p: Page) -> str:
    year = UPDATED.year
    return f"""<footer>
  <div class="wrap">
    <a class="more-apps" href="https://lrvdlinden.app" rel="noopener">
      <img class="lr" src="/assets/img/lr-logo.png" alt="" width="56" height="56">
      <span><b>{p.t("Meer apps van de ontwikkelaar", "More apps by the developer")}</b><span>{p.t("Apps van Léon van der Linden", "Apps by Léon van der Linden")}</span></span>
      <em>{p.t("Bekijk", "View")}</em>
    </a>
    <div class="foot">
      <span>© {year} Léon van der Linden · Pairr {VERSION}</span>
      <nav aria-label="{p.t("Voettekst", "Footer")}">
        <a href="{p.url("/support/")}">{p.t("Support", "Support")}</a>
        <a href="{p.url("/privacy/")}">{p.t("Privacy", "Privacy")}</a>
        <a href="{GITHUB}" rel="noopener">GitHub</a>
        <a href="https://lrvdlinden.app" rel="noopener">lrvdlinden.app</a>
      </nav>
    </div>
  </div>
</footer>
</body>
</html>
"""


# ---------------------------------------------------------------- home

def phone(p: Page) -> str:
    rows = [
        ("lightbulb", "#F2A516", p.t("Lamp woonkamer", "Living room lamp"), p.t("Philips Hue · Woonkamer", "Philips Hue · Living room"), ["hue", "zigbee"]),
        ("plug", "#2F6FE4", p.t("Slimme stekker", "Smart plug"), p.t("Matter · Keuken", "Matter · Kitchen"), ["matter", "homekit"]),
        ("thermometer", "#E8603C", p.t("Thermostaat", "Thermostat"), p.t("HomeKit · Gang", "HomeKit · Hallway"), ["homekit"]),
        ("door-open", "#14A884", p.t("Deursensor voordeur", "Front door sensor"), p.t("Zigbee · Hal", "Zigbee · Entrance"), ["zigbee"]),
        ("lock", "#5A43E0", p.t("Slim slot", "Smart lock"), p.t("Z-Wave · Voordeur", "Z-Wave · Front door"), ["zwave", "pin"]),
        ("camera", "#27AE60", p.t("Camera tuin", "Garden camera"), p.t("Wifi · Tuin", "Wi-Fi · Garden"), ["wifi"]),
        ("router", "#6B7280", p.t("Mesh-router", "Mesh router"), p.t("Pincode · Meterkast", "PIN · Utility cupboard"), ["pin", "wifi"]),
    ]
    items = "".join(
        f'<div class="row" style="animation-delay:{0.25 + i * 0.09:.2f}s"><span class="ic" style="background:{col}">{ic(icn)}</span>'
        f'<span class="tx"><b>{esc(n)}</b><small>{esc(s)}</small></span><span class="tags">{"".join(tag(t) for t in tags)}</span></div>'
        for i, (icn, col, n, s, tags) in enumerate(rows)
    )
    return f"""<div class="stage" aria-hidden="true">
  <div class="badge-float bf1"><i style="background:var(--mint)">{ic("shield-check")}</i><span>{p.t("Versleuteld", "Encrypted")}<small>AES-GCM · iCloud</small></span></div>
  <div class="badge-float bf2"><i style="background:var(--ocean)">{ic("sparkles")}</i><span>{p.t("Automatisch ingevuld", "Filled in automatically")}<small>{p.t("Merk, model en logo", "Brand, model and logo")}</small></span></div>
  <div class="phone">
    <div class="screen">
      <div class="island"></div>
      <div class="sb"><span>9:41</span><span class="sbi"><i></i><i></i><i></i><i></i><b></b></span></div>
      <div class="app-title">{p.t("Apparaten", "Devices")}<span>+</span></div>
      <div class="search">⌕ {p.t("Zoeken", "Search")}</div>
      <div class="list">{items}</div>
      <div class="scan" id="scan"><div class="frame">{qr_svg(QR_PAYLOAD)}<span class="beam"></span></div><p>{p.t("Richt op de QR-code", "Point at the QR code")}</p></div>
      <div class="found" id="found">
        <div class="hd"><span class="ic">{ic("plug")}</span><span><b>{p.t("Slimme stekker", "Smart plug")}</b><small>Matter · {p.t("Koppelcode", "Setup code")}</small></span></div>
        <div class="code">3497-011-2332</div>
        <div class="ok">{ic("badge-check")} {p.t("Geldige Matter-code", "Valid Matter code")}</div>
        <div class="sp">{ic("sparkles")} {p.t("Fabrikant en model ingevuld", "Vendor and model filled in")}</div>
      </div>
    </div>
  </div>
  <div class="watch"><div class="w-screen">{qr_svg(QR_PAYLOAD)}</div></div>
</div>"""


def home(p: Page) -> str:
    T = p.t
    faqs = [
        (T("Wat kost Pairr?", "How much does Pairr cost?"),
         T("Eenmalig € 0,99. Daarna geen abonnement, geen in-app-aankopen, geen reclame en geen account. Alle functies zitten erin, en je betaalt één keer voor iPhone, iPad, Mac en Apple Watch samen.",
           "A one-time € 0.99 (or the equivalent price in your country's App Store). After that: no subscription, no in-app purchases, no ads and no account. Every feature is included, and one purchase covers iPhone, iPad, Mac and Apple Watch.")),
        (T("Kan ik Pairr nu al proberen?", "Can I try Pairr already?"),
         T("Ja, via de openbare bèta in TestFlight: installeer de app TestFlight van Apple en open de link op deze pagina. Bèta-versies zijn gratis; feedback stuur je via TestFlight of de supportpagina.",
           "Yes, through the public beta on TestFlight: install Apple's TestFlight app and open the link on this page. Beta versions are free; send feedback through TestFlight or the support page.")),
        (T("Wat gebeurt er als ik de app verwijder?", "What happens if I delete the app?"),
         T("Niets gaat verloren. Je apparaten en codes staan in je eigen iCloud en de sleutel van je kluis in de iCloud-sleutelhanger. Installeer je Pairr opnieuw, dan komt alles vanzelf terug. Daarnaast maakt Pairr elke week een versleutelde back-up in iCloud Drive.",
           "Nothing is lost. Your devices and codes live in your own iCloud and the key to your vault in iCloud Keychain. Reinstall Pairr and everything comes back by itself. Pairr also makes an encrypted backup in iCloud Drive every week.")),
        (T("Kan iemand anders mijn codes zien?", "Can anyone else see my codes?"),
         T("Nee. Codes, QR-codes en bijlagen worden versleuteld met AES-GCM voordat ze worden opgeslagen. Er is geen server van Pairr en de ontwikkelaar kan nergens bij. Met Face ID of Touch ID zet je de app ook nog op slot.",
           "No. Codes, QR codes and attachments are encrypted with AES-GCM before they are stored. Pairr has no server and the developer can't access anything. Add Face ID or Touch ID to lock the app as well.")),
        (T("Welke codes herkent Pairr?", "Which codes does Pairr recognise?"),
         T("HomeKit-codes (8 cijfers en X-HM://-QR), Matter (MT:-QR en handmatige codes van 11 of 21 cijfers, met controle), Zigbee-installatiecodes met IEEE-adres, het serienummer van 6 tekens op Philips Hue-lampen, Z-Wave DSK en SmartStart-QR, wifi-gegevens en gewone pincodes.",
           "HomeKit codes (8 digits and X-HM:// QR), Matter (MT: QR and 11 or 21-digit manual codes, checked), Zigbee install codes with IEEE address, the 6-character serial number on Philips Hue bulbs, Z-Wave DSK and SmartStart QR, Wi-Fi details and plain PIN codes.")),
        (T("Waarom zou ik een code bewaren als mijn apparaat al gekoppeld is?", "Why keep a code once my device is paired?"),
         T("Omdat je hem later bijna altijd weer nodig hebt: na een reset, bij een nieuwe hub of controller, als je verhuist of als de sticker onder een lamp of in een inbouwdoos niet meer te bereiken is.",
           "Because you almost always need it again later: after a reset, when you switch hub or controller, when you move house, or when the sticker sits under a ceiling lamp or behind a wall plate.")),
        (T("Hoe vult Pairr merk en model in?", "How does Pairr fill in brand and model?"),
         T("Een Matter-QR bevat een fabrikant- en product-ID. Pairr zoekt die op in de openbare Matter-database van de Connectivity Standards Alliance en haalt het logo van de website van het merk. Daarbij gaan alleen die ID's of de domeinnaam mee, nooit je codes.",
           "A Matter QR contains a vendor and product ID. Pairr looks those up in the public Matter database of the Connectivity Standards Alliance and fetches the logo from the brand's website. Only those IDs or the domain name are sent, never your codes.")),
        (T("Werkt Pairr zonder iCloud?", "Does Pairr work without iCloud?"),
         T("Ja. Zonder iCloud blijft alles op je apparaat. Maak dan zelf af en toe een back-up met wachtwoord, of exporteer naar PDF of CSV.",
           "Yes. Without iCloud everything stays on your device. Just make a password-protected backup now and then, or export to PDF or CSV.")),
        (T("Op welke apparaten werkt Pairr?", "Which devices does Pairr run on?"),
         T("iPhone en iPad met iOS 17 of nieuwer, Mac met macOS 14 of nieuwer en Apple Watch met watchOS 10 of nieuwer. Eén download voor alles.",
           "iPhone and iPad with iOS 17 or later, Mac with macOS 14 or later and Apple Watch with watchOS 10 or later. One download for all of them.")),
    ]

    title = T("HomeKit-, Matter- en Zigbee-codes bewaren | Pairr",
              "Store HomeKit, Matter and Zigbee codes | Pairr")
    desc = T("App voor al je koppelcodes: HomeKit, Matter, Zigbee, Hue en Z-Wave. Scannen, automatisch invullen, versleuteld in iCloud. Eenmalig € 0,99, geen abonnement.",
             "App for all your setup codes: HomeKit, Matter, Zigbee, Hue and Z-Wave. Scan, auto-fill, encrypted in iCloud. One-time purchase, no subscription.")
    og_title = T("Pairr: nooit meer een koppelcode kwijt", "Pairr: never lose a setup code again")
    og_desc = T("Al je HomeKit-, Matter-, Zigbee- en Hue-codes veilig op één plek. Eenmalig € 0,99, zonder account.",
                "All your HomeKit, Matter, Zigbee and Hue codes safely in one place. One-time purchase, no account.")
    og_alt = T("Pairr op een iPhone en Apple Watch: een lijst met slimme apparaten en een Matter-QR-code",
               "Pairr on an iPhone and Apple Watch: a list of smart devices and a Matter QR code")
    keywords = T("homekit code bewaren, matter code bewaren, koppelcode kwijt, homekit code kwijt, zigbee install code, philips hue serienummer, z-wave dsk, smart home codes app",
                 "save homekit codes, store matter setup code, lost homekit code, zigbee install code, philips hue serial number, z-wave dsk, smart home code vault")

    ld = [
        {"@context": "https://schema.org", "@type": "SoftwareApplication", "name": "Pairr",
         "applicationCategory": "UtilitiesApplication", "operatingSystem": "iOS 17, iPadOS 17, macOS 14, watchOS 10",
         "inLanguage": ["nl", "en", "de", "fr", "es", "it", "sv", "nb", "da", "pl"],
         "description": desc, "url": DOMAIN + p.url("/"), "image": f"{DOMAIN}/assets/img/icon-512.png",
         "softwareVersion": VERSION, "isAccessibleForFree": False,
         "offers": {"@type": "Offer", "price": "0.99", "priceCurrency": "EUR"},
         "author": {"@type": "Person", "name": "Léon van der Linden", "url": "https://lrvdlinden.app"},
         **({"downloadUrl": APP_STORE_URL} if APP_STORE_URL else {})},
        {"@context": "https://schema.org", "@type": "WebSite", "name": "Pairr", "url": DOMAIN + p.url("/"), "inLanguage": p.lang,
         "publisher": {"@type": "Person", "name": "Léon van der Linden", "url": "https://lrvdlinden.app",
                       "sameAs": ["https://lrvdlinden.app", "https://github.com/LRvdLinden"]}},
        {"@context": "https://schema.org", "@type": "FAQPage", "inLanguage": p.lang, "mainEntity": [
            {"@type": "Question", "name": q, "acceptedAnswer": {"@type": "Answer", "text": a}} for q, a in faqs]},
    ]

    chips = "".join(f'<span class="chip"><i style="background:{c[1]}">{ic(c[2])}</i>{c[3] if p.lang == "nl" else c[4]}</span>' for c in CODE_TYPES)

    types = [
        ("homekit", T("Code van 8 cijfers of de X-HM://-QR op de sticker. Pairr toont hem weer als scanbare code.",
                      "The 8-digit code or the X-HM:// QR on the sticker. Pairr shows it again as a scannable code."), "123-45-678"),
        ("matter", T("QR en handmatige code, met controle op typfouten. Fabrikant en model worden opgezocht.",
                     "QR and manual code, checked for typos. Vendor and model are looked up for you."), "MT:Y.K9042C00…"),
        ("zigbee", T("Installatiecode met IEEE-adres, gecontroleerd met de CRC, klaar voor je hub.",
                     "Install code with IEEE address, verified with its CRC, ready for your hub."), "83FE D340 7A93 …"),
        ("hue", T("Het serienummer van 6 tekens op de fitting, om een lamp te resetten of toe te voegen.",
                  "The 6-character serial on the bulb fitting, to reset or add a bulb."), "A1B2C3"),
        ("zwave", T("DSK en SmartStart-QR, met de pincode van 5 cijfers apart zichtbaar.",
                    "DSK and SmartStart QR, with the 5-digit PIN shown separately."), "12345-…"),
        ("wifi", T("Netwerknaam en wachtwoord van camera's, stekkers of je gastnetwerk, als QR om te delen.",
                   "Network name and password for cameras, plugs or your guest network, as a QR to share."), "WIFI:S:…"),
        ("pin", T("Pincodes en wachtwoorden van routers, alarmen en sloten.",
                  "PIN codes and passwords for routers, alarms and locks."), "••••••"),
    ]
    type_cards = "".join(
        f'<article class="type reveal{" d" + str(i % 3) if i % 3 else ""}"><span class="ti" style="background:{CT[t][1]}">{ic(CT[t][2])}</span>'
        f'<h3>{CT[t][3] if p.lang == "nl" else CT[t][4]}</h3><p>{esc(txt)}</p><p style="margin-top:10px"><code>{esc(ex)}</code></p></article>'
        for i, (t, txt, ex) in enumerate(types)
    )

    feats = [
        ("scan-line", T("Scannen met de camera", "Scan with the camera"), T("QR-codes en gedrukte cijfers in één keer, ook van een schuine sticker.", "QR codes and printed digits in one go, even from a crooked sticker.")),
        ("image", T("Uit een foto", "From a photo"), T("Al een foto van de doos gemaakt? Pairr leest de code eruit.", "Already took a photo of the box? Pairr reads the code from it.")),
        ("nfc", T("NFC-tags", "NFC tags"), T("Houd je iPhone bij een Matter- of HomeKit-tag en de code staat erin.", "Hold your iPhone to a Matter or HomeKit tag and the code is in.")),
        ("house", T("Importeren uit Woning", "Import from Home"), T("Neem je HomeKit-apparaten met kamer, merk en model in één keer over.", "Bring in your HomeKit accessories with room, brand and model in one go.")),
        ("paperclip", T("Bijlagen", "Attachments"), T("Foto van de sticker, handleiding of bon: versleuteld bij het apparaat.", "Sticker photo, manual or receipt: encrypted with the device.")),
        ("search", T("Zoeken en filteren", "Search and filter"), T("Op naam, kamer, merk of soort code. Ook op de Mac met het toetsenbord.", "By name, room, brand or code type. With the keyboard on the Mac too.")),
        ("watch", T("Op je pols", "On your wrist"), T("Toon een code als QR op je Apple Watch en scan hem met je andere telefoon.", "Show a code as a QR on your Apple Watch and scan it with your other phone.")),
        ("file-down", T("Exporteren", "Export"), T("Printklare PDF met QR-codes, CSV of Markdown. En importeren uit CSV.", "Print-ready PDF with QR codes, CSV or Markdown. And import from CSV.")),
        ("globe", T("In 10 talen", "In 10 languages"), T("Nederlands, Engels, Duits, Frans, Spaans, Italiaans, Zweeds, Noors, Deens en Pools.", "English, Dutch, German, French, Spanish, Italian, Swedish, Norwegian, Danish and Polish.")),
    ]
    feat_cards = "".join(
        f'<article class="feat reveal{" d" + str(i % 3) if i % 3 else ""}"><span class="fi">{ic(icn)}</span><h3>{esc(h)}</h3><p>{esc(t)}</p></article>'
        for i, (icn, h, t) in enumerate(feats)
    )

    checks = [
        ("lock", T("Versleuteld met AES-GCM", "Encrypted with AES-GCM"), T("Elke code, QR en bijlage, met een eigen sleutel van 256 bits.", "Every code, QR and attachment, with your own 256-bit key.")),
        ("cloud", T("In je eigen iCloud", "In your own iCloud"), T("Synchroniseert tussen iPhone, iPad, Mac en Watch. Geen server van Pairr.", "Syncs between iPhone, iPad, Mac and Watch. No Pairr server.")),
        ("scan-face", T("Face ID of Touch ID", "Face ID or Touch ID"), T("Zet het slot aan en de app vergrendelt zodra je hem verlaat.", "Turn on the lock and the app locks as soon as you leave it.")),
        ("clipboard-x", T("Klembord wist zichzelf", "Clipboard clears itself"), T("Een gekopieerde code verdwijnt na 60 seconden en gaat niet naar je andere apparaten.", "A copied code disappears after 60 seconds and never syncs to your other devices.")),
        ("hard-drive-download", T("Blijft bewaard", "Stays safe"), T("App per ongeluk verwijderd? Opnieuw installeren en alles is terug, plus wekelijkse back-ups.", "Deleted the app by accident? Reinstall and everything is back, plus weekly backups.")),
        ("eye-off", T("Geen account, geen tracking", "No account, no tracking"), T("Geen analytics, geen reclame, niets dat meekijkt.", "No analytics, no ads, nothing watching along.")),
    ]
    check_items = "".join(f"<li><i>{ic(icn)}</i><div><b>{esc(h)}</b><span>{esc(t)}</span></div></li>" for icn, h, t in checks)

    Y = f'<span class="yes" role="img" aria-label="{T("Ja", "Yes")}">{ic("check")}</span>'
    N = f'<span class="no" role="img" aria-label="{T("Nee", "No")}">{ic("x")}</span>'

    def part(s: str) -> str:
        return f'<span class="part">{esc(s)}</span>'

    cmp_rows = [
        (T("Herkent HomeKit-, Matter-, Zigbee-, Hue- en Z-Wave-codes", "Recognises HomeKit, Matter, Zigbee, Hue and Z-Wave codes"), Y, N, N),
        (T("Toont de code weer als scanbare QR", "Shows the code again as a scannable QR"), Y, part(T("Foto van sticker", "Photo of sticker")), N),
        (T("Per apparaat met merk, model en kamer", "Per device with brand, model and room"), Y, N, part(T("Zelf typen", "Type it yourself"))),
        (T("Controleert codes op typfouten", "Checks codes for typos"), Y, N, N),
        (T("Versleuteld met een eigen sleutel", "Encrypted with its own key"), Y, N, part(T("Vergrendelde notitie", "Locked note"))),
        (T("Op slot met Face ID", "Locked with Face ID"), Y, part(T("Verborgen album", "Hidden album")), part(T("Vergrendelde notitie", "Locked note"))),
        (T("Synchroniseert via iCloud", "Syncs via iCloud"), Y, Y, Y),
    ]
    cmp_html = "".join(f'<tr><td>{esc(r)}</td><td class="us">{a}</td><td>{b}</td><td>{c}</td></tr>' for r, a, b, c in cmp_rows)

    faq_html = "".join(f"<details><summary>{esc(q)}</summary><div><p>{esc(a)}</p></div></details>" for q, a in faqs)

    devices = [
        ("smartphone", "iPhone", "iOS 17+"), ("tablet", "iPad", "iPadOS 17+"),
        ("laptop", "Mac", "macOS 14+"), ("watch", "Apple Watch", "watchOS 10+"),
    ]
    dev_html = "".join(f'<div class="dev reveal{" d" + str(i) if i else ""}">{ic(icn)}<b>{n}</b><span>{v}</span></div>' for i, (icn, n, v) in enumerate(devices))

    # vault orbit tiles (positions in %)
    orbs = [("homekit", 50, 2), ("matter", 92, 30), ("zigbee", 84, 78), ("hue", 40, 96), ("zwave", 4, 70), ("wifi", 8, 22)]
    orb_html = "".join(f'<span class="orb" style="left:calc({x}% - 23px);top:calc({y}% - 23px);background:{CT[t][1]}">{ic(CT[t][2])}</span>' for t, x, y in orbs)

    body = f"""
<main id="main">
<section class="hero">
  <div class="wrap">
    <div>
      <span class="eyebrow"><span class="dot"></span>{T("€ 0,99 eenmalig · geen abonnement", "One-time purchase · no subscription")}</span>
      <h1>{T('Nooit meer een <span class="grad">koppelcode</span> kwijt.', 'Never lose a <span class="grad">setup code</span> again.')}</h1>
      <p class="lead">{T("Pairr bewaart de codes van al je slimme apparaten veilig op één plek. Scan de sticker, Pairr herkent de code, vult merk en model in en toont hem later weer als QR. Versleuteld in je eigen iCloud.",
                         "Pairr keeps the codes of all your smart devices safe in one place. Scan the sticker, Pairr recognises the code, fills in brand and model and shows it again as a QR later. Encrypted in your own iCloud.")}</p>
      <div class="cta" id="download-top">{store_badge(p)}<a class="btn btn-ghost" href="#hoe">{T("Zo werkt het", "See how it works")}</a></div>
      <ul class="platforms"><li>iPhone · iPad · Mac · Apple Watch</li><li>{T("10 talen", "10 languages")}</li></ul>
      <div class="chips" aria-label="{T("Ondersteunde codes", "Supported codes")}">{chips}</div>
    </div>
    {phone(p)}
  </div>
</section>

<section class="dark problem">
  <div class="wrap">
    <div class="sec-head reveal">
      <span class="kicker">{T("Herkenbaar?", "Sound familiar?")}</span>
      <h2>{T("De code zit altijd net op de plek waar je niet bij kunt.", "The code is always right where you can't reach it.")}</h2>
      <p>{T("Onder een plafondlamp, achter een stopcontact, op een doos die al bij het oud papier ligt. En juist na een reset of een nieuwe hub heb je hem weer nodig.",
            "Under a ceiling lamp, behind a wall plate, on a box that's already in the recycling. And it's exactly after a reset or a new hub that you need it again.")}</p>
    </div>
    <div class="grid">
      <div class="dark-card reveal"><span class="big">{T("Reset", "Reset")}</span><p>{T("Apparaat doet raar? Opnieuw koppelen kan alleen met de originele code.", "Device acting up? Re-pairing only works with the original code.")}</p></div>
      <div class="dark-card reveal d1"><span class="big">{T("Nieuwe hub", "New hub")}</span><p>{T("Overstappen naar Matter, Thread of een andere bridge betekent alles opnieuw toevoegen.", "Switching to Matter, Thread or another bridge means adding everything again.")}</p></div>
      <div class="dark-card reveal d2"><span class="big">{T("Verhuizen", "Moving")}</span><p>{T("Geef de nieuwe bewoners een printje met alle codes, of neem ze mee.", "Hand the new owners a printout with every code, or take them with you.")}</p></div>
    </div>
  </div>
</section>

<section id="hoe">
  <div class="wrap">
    <div class="sec-head reveal">
      <span class="kicker">{T("Zo werkt het", "How it works")}</span>
      <h2>{T("Scannen, klaar. Pairr doet de rest.", "Scan, done. Pairr does the rest.")}</h2>
    </div>
    <div class="steps">
      <article class="step reveal"><span class="si">{ic("scan-line")}</span><h3>{T("Scan de sticker", "Scan the sticker")}</h3><p>{T("Met de camera, uit een foto of via NFC. QR en gedrukte cijfers worden allebei gelezen.", "With the camera, from a photo or via NFC. QR and printed digits are both read.")}</p></article>
      <article class="step reveal d1"><span class="si">{ic("sparkles")}</span><h3>{T("Pairr vult het in", "Pairr fills it in")}</h3><p>{T("Soort code, controle op fouten, merk, model, logo en een passend icoon. Jij kiest alleen nog de kamer.", "Code type, error check, brand, model, logo and a fitting icon. You just pick the room.")}</p></article>
      <article class="step reveal d2"><span class="si">{ic("qr-code")}</span><h3>{T("Later weer scannen", "Scan it again later")}</h3><p>{T("Pairr tekent de code opnieuw als QR, op je iPhone, iPad, Mac of Apple Watch. Je hub scant hem gewoon.", "Pairr redraws the code as a QR on your iPhone, iPad, Mac or Apple Watch. Your hub simply scans it.")}</p></article>
    </div>
  </div>
</section>

<section id="codes" style="background:var(--soft)">
  <div class="wrap">
    <div class="sec-head reveal">
      <span class="kicker">{T("Alle codes", "Every code")}</span>
      <h2>{T("Eén kluis voor elk protocol.", "One vault for every protocol.")}</h2>
      <p>{T("Pairr kent de opbouw van elke soort code. Zo weet je zeker dat wat je bewaart ook werkt.", "Pairr knows how each type of code is built, so you know what you save will actually work.")}</p>
    </div>
    <div class="types">{type_cards}</div>
  </div>
</section>

<section>
  <div class="wrap">
    <div class="sec-head reveal">
      <span class="kicker">{T("Alles erin", "Everything included")}</span>
      <h2>{T("Maximaal handig. Eén keer betalen.", "As handy as it gets. Pay once.")}</h2>
    </div>
    <div class="features">
      <article class="feat wide reveal">
        <div><span class="fi">{ic("sparkles")}</span><h3>{T("Automatisch ingevuld", "Filled in automatically")}</h3><p>{T("Een Matter-code verraadt fabrikant en product. Pairr zoekt ze op in de openbare Matter-database en zet merk, model, logo en icoon klaar.", "A Matter code reveals vendor and product. Pairr looks them up in the public Matter database and prepares brand, model, logo and icon.")}</p></div>
        <div class="fill-demo" id="fill" aria-hidden="true">
          <div class="fl"><span>{T("Soort", "Type")}</span><b>Matter</b></div>
          <div class="fl"><span>{T("Merk", "Brand")}</span><b data-type="Eve Systems"></b></div>
          <div class="fl"><span>{T("Model", "Model")}</span><b data-type="Eve Energy"></b></div>
          <div class="fl"><span>{T("Icoon", "Icon")}</span><b data-type="{T("Stekker", "Plug")}"></b></div>
          <div class="fl"><span>{T("Kamer", "Room")}</span><b data-type="{T("Keuken", "Kitchen")}"></b></div>
        </div>
      </article>
      {feat_cards}
    </div>
  </div>
</section>

<section id="veilig" class="dark security">
  <div class="wrap">
    <div class="vault reveal" aria-hidden="true"><span class="ring"></span><span class="ring r2"></span><span class="core">{ic("shield-check")}</span>{orb_html}</div>
    <div>
      <div class="sec-head reveal" style="margin-bottom:28px">
        <span class="kicker">{T("Veilig", "Secure")}</span>
        <h2>{T("Jouw codes. Alleen van jou.", "Your codes. Only yours.")}</h2>
        <p>{T("Wie je koppelcode heeft, kan je apparaat toevoegen. Daarom gaat Pairr er zo zuinig mee om.", "Whoever has your setup code can add your device. That's why Pairr treats it so carefully.")}</p>
      </div>
      <ul class="checks reveal">{check_items}</ul>
    </div>
  </div>
</section>

<section>
  <div class="wrap">
    <div class="sec-head reveal">
      <span class="kicker">{T("Vergelijk", "Compare")}</span>
      <h2>{T("Beter dan een foto van de sticker.", "Better than a photo of the sticker.")}</h2>
    </div>
    <div class="compare-wrap reveal">
      <table class="compare">
        <thead><tr><th scope="col"><span class="sr">{T("Functie", "Feature")}</span></th><th scope="col" class="us">Pairr</th><th scope="col">{T("Foto's", "Photos")}</th><th scope="col">{T("Notities", "Notes")}</th></tr></thead>
        <tbody>{cmp_html}</tbody>
      </table>
    </div>
    <p class="foot-note">{T("Vergeleken met de standaardapps van Apple zonder extra instellingen.", "Compared with Apple's built-in apps using their default settings.")}</p>
  </div>
</section>

<section style="background:var(--soft)">
  <div class="wrap">
    <div class="sec-head reveal">
      <span class="kicker">{T("Overal", "Everywhere")}</span>
      <h2>{T("Eén download. Al je Apple-apparaten.", "One download. All your Apple devices.")}</h2>
      <p>{T("Voeg een code toe op je iPhone en hij staat meteen op je iPad, Mac en Apple Watch.", "Add a code on your iPhone and it's right there on your iPad, Mac and Apple Watch.")}</p>
    </div>
    <div class="devices">{dev_html}</div>
  </div>
</section>

<section id="faq">
  <div class="wrap">
    <div class="sec-head reveal"><span class="kicker">{T("Vragen", "FAQ")}</span><h2>{T("Veelgestelde vragen", "Frequently asked questions")}</h2></div>
    <div class="faq reveal">{faq_html}</div>
  </div>
</section>

<section class="final" id="download" style="background:var(--soft)">
  <div class="wrap">
    <img class="icon reveal" src="/assets/img/icon-512.png" alt="{T("App-icoon van Pairr", "Pairr app icon")}" width="108" height="108" loading="lazy">
    <h2 class="reveal">{T("Al je codes. Eén plek.", "All your codes. One place.")}</h2>
    <p class="lead reveal" style="margin:0 auto">{T("Eenmalig € 0,99 voor iPhone, iPad, Mac en Apple Watch samen.", "One purchase for iPhone, iPad, Mac and Apple Watch together.")}</p>
    <div class="cta reveal">{store_badge(p)}</div>
  </div>
</section>
</main>
"""
    return head(p, "/", title, desc, og_title, og_desc, og_alt, ld, keywords=keywords) + "\n" + header(p, "/", True) + body + footer(p)


# ---------------------------------------------------------------- privacy

def privacy(p: Page) -> str:
    T = p.t
    d = UPDATED.strftime("%-d %B %Y") if p.lang == "en" else f"{UPDATED.day} november {UPDATED.year}"
    body = f"""
<main id="main" class="wrap page">
  <span class="kicker">Pairr</span>
  <h1>{T("Privacyverklaring", "Privacy policy")}</h1>
  <p class="updated">{T("Laatst bijgewerkt", "Last updated")}: {d}</p>
  <div class="box"><p style="margin:0"><b>{T("Kort gezegd:", "In short:")}</b> {T("Pairr verzamelt niets. Er is geen account, geen server van Pairr, geen analytics en geen reclame. Je gegevens staan versleuteld op je eigen apparaten en in je eigen iCloud.",
    "Pairr collects nothing. There is no account, no Pairr server, no analytics and no ads. Your data is stored encrypted on your own devices and in your own iCloud.")}</p></div>

  <h2>{T("Wie is verantwoordelijk", "Who is responsible")}</h2>
  <p>{T("Pairr is gemaakt door Léon van der Linden (lrvdlinden.app), Nederland. Vragen over privacy kun je stellen via de supportpagina.", "Pairr is made by Léon van der Linden (lrvdlinden.app), the Netherlands. Questions about privacy can be asked via the support page.")}</p>

  <h2>{T("Welke gegevens Pairr gebruikt", "What data Pairr uses")}</h2>
  <p>{T("Alleen wat jij zelf invoert: apparaten, codes, kamers, notities, bijlagen en je instellingen. Die gegevens worden niet naar de ontwikkelaar gestuurd.", "Only what you enter yourself: devices, codes, rooms, notes, attachments and your settings. That data is never sent to the developer.")}</p>

  <h2>{T("Opslag en iCloud", "Storage and iCloud")}</h2>
  <ul>
    <li>{T("Codes, QR-codes en bijlagen worden versleuteld met AES-GCM (256 bits) voordat ze worden opgeslagen.", "Codes, QR codes and attachments are encrypted with AES-GCM (256-bit) before they are stored.")}</li>
    <li>{T("De sleutel staat in de iCloud-sleutelhanger van je Apple-account. De Apple Watch krijgt hem rechtstreeks van je iPhone.", "The key is stored in the iCloud Keychain of your Apple Account. The Apple Watch receives it directly from your iPhone.")}</li>
    <li>{T("Als iCloud aan staat, synchroniseert Pairr via de privédatabase van iCloud (CloudKit) van jouw Apple-account. De ontwikkelaar heeft daar geen toegang toe.", "With iCloud turned on, Pairr syncs through the private iCloud database (CloudKit) of your Apple Account. The developer has no access to it.")}</li>
    <li>{T("Automatische back-ups komen in je eigen iCloud Drive (map Pairr), versleuteld met dezelfde sleutel.", "Automatic backups go to your own iCloud Drive (Pairr folder), encrypted with the same key.")}</li>
    <li>{T("Een gekopieerde code blijft alleen op het apparaat waar je hem kopieert en verdwijnt na 60 seconden van het klembord.", "A copied code stays only on the device where you copied it and is removed from the clipboard after 60 seconds.")}</li>
  </ul>

  <h2>{T("Opzoeken van apparaatgegevens", "Looking up device details")}</h2>
  <p>{T("Om merk, model en logo in te vullen maakt Pairr soms verbinding met internet:", "To fill in brand, model and logo, Pairr sometimes connects to the internet:")}</p>
  <ul>
    <li>{T("de openbare Matter-database van de Connectivity Standards Alliance (on.dcl.csa-iot.org), met alleen het fabrikant- en product-ID uit een Matter-code;", "the public Matter database of the Connectivity Standards Alliance (on.dcl.csa-iot.org), with only the vendor and product ID from a Matter code;")}</li>
    <li>{T("de website van het merk, om het pictogram (logo) op te halen.", "the brand's website, to fetch its icon (logo).")}</li>
  </ul>
  <p>{T("Je koppelcodes zelf worden nooit verstuurd. Zoals bij elke internetverbinding kunnen die partijen je IP-adres zien; Pairr stuurt geen andere gegevens mee.", "Your setup codes themselves are never sent. As with any internet connection those parties can see your IP address; Pairr sends nothing else.")}</p>

  <h2>{T("Toestemmingen", "Permissions")}</h2>
  <ul>
    <li><b>{T("Camera", "Camera")}</b>: {T("om codes te scannen. Beelden worden niet bewaard, tenzij je zelf een foto als bijlage toevoegt.", "to scan codes. Images are not stored unless you add a photo as an attachment yourself.")}</li>
    <li><b>{T("Foto's", "Photos")}</b>: {T("alleen de foto die je kiest, om er een code uit te lezen of hem als bijlage te bewaren.", "only the photo you pick, to read a code from it or keep it as an attachment.")}</li>
    <li><b>NFC</b>: {T("om een code van een NFC-tag te lezen (iPhone).", "to read a code from an NFC tag (iPhone).")}</li>
    <li><b>{T("Woning (HomeKit)", "Home (HomeKit)")}</b>: {T("alleen-lezen, om je accessoires met kamer, merk en model te importeren. Pairr verandert niets in je woning.", "read-only, to import your accessories with room, brand and model. Pairr changes nothing in your home.")}</li>
    <li><b>Face ID / Touch ID</b>: {T("wordt door iOS en macOS afgehandeld; Pairr krijgt alleen te horen of het gelukt is.", "is handled by iOS and macOS; Pairr only learns whether it succeeded.")}</li>
  </ul>

  <h2>{T("Wat Pairr niet doet", "What Pairr doesn't do")}</h2>
  <p>{T("Geen account, geen tracking, geen analytics, geen crashrapportage van derden, geen reclame en geen verkoop of delen van gegevens. Een beoordeling vragen gaat via het standaardvenster van Apple.", "No account, no tracking, no analytics, no third-party crash reporting, no ads and no selling or sharing of data. Asking for a rating uses Apple's standard prompt.")}</p>
  <p>{T("Apple deelt met ontwikkelaars alleen geanonimiseerde, opgetelde cijfers over downloads uit de App Store. Daaruit is niet te herleiden wie je bent.", "Apple only shares anonymised, aggregated App Store download figures with developers. These can't be traced back to you.")}</p>

  <h2>{T("Je gegevens verwijderen", "Deleting your data")}</h2>
  <p>{T("In Pairr kun je bij Instellingen → Gegevens alles wissen, ook uit iCloud. Je kunt de gegevens van Pairr ook verwijderen via Instellingen → [je naam] → iCloud → Opslag beheren op je iPhone.", "In Pairr you can erase everything under Settings → Data, including from iCloud. You can also remove Pairr's data via Settings → [your name] → iCloud → Manage Storage on your iPhone.")}</p>

  <h2>{T("Deze website", "This website")}</h2>
  <p>{T("pairr.lrvdlinden.app gebruikt geen cookies voor tracking en geen analytics. Alleen als je zelf een taal kiest, wordt die keuze in je browser onthouden (cookie pairr_lang). Lettertypen worden vanaf deze site geladen, niet van Google.", "pairr.lrvdlinden.app uses no tracking cookies and no analytics. Only when you pick a language yourself is that choice remembered in your browser (cookie pairr_lang). Fonts are served from this site, not from Google.")}</p>

  <h2>{T("Wijzigingen", "Changes")}</h2>
  <p>{T("Verandert er iets aan deze verklaring, dan staat de nieuwe versie hier met een nieuwe datum.", "If this policy changes, the new version will appear here with a new date.")}</p>
</main>
"""
    title = T("Privacyverklaring | Pairr", "Privacy policy | Pairr")
    desc = T("Pairr verzamelt niets: geen account, geen server, geen analytics. Lees hoe je codes versleuteld in je eigen iCloud blijven.",
             "Pairr collects nothing: no account, no server, no analytics. Read how your codes stay encrypted in your own iCloud.")
    return (head(p, "/privacy/", title, desc, title, desc, T("App-icoon van Pairr", "Pairr app icon"))
            + "\n" + header(p, "/privacy/", False) + body + footer(p))


# ---------------------------------------------------------------- support

def support(p: Page) -> str:
    T = p.t
    tips = [
        (T("Mijn codes staan niet op mijn andere apparaat", "My codes don't show up on my other device"),
         T("Controleer of je op beide apparaten met hetzelfde Apple-account bent ingelogd en of iCloud voor Pairr aan staat (Instellingen → [je naam] → iCloud → Apps die iCloud gebruiken). De iCloud-sleutelhanger moet ook aan staan. Synchroniseren kan een paar minuten duren.",
           "Make sure both devices are signed in to the same Apple Account and that iCloud is on for Pairr (Settings → [your name] → iCloud → Apps Using iCloud). iCloud Keychain needs to be on too. Syncing can take a few minutes.")),
        (T("De Apple Watch zegt dat de kluis op slot zit", "The Apple Watch says the vault is locked"),
         T("Open Pairr een keer op je iPhone terwijl je Watch in de buurt is. De iPhone geeft de sleutel dan door aan je Watch.",
           "Open Pairr once on your iPhone while your Watch is nearby. The iPhone then passes the key to your Watch.")),
        (T("De scanner leest de code niet", "The scanner doesn't read the code"),
         T("Zorg voor genoeg licht, houd de camera recht en niet te dichtbij. Lukt het niet, maak een foto en kies \"Uit foto\", of typ de code over: Pairr controleert hem dan op fouten.",
           "Make sure there's enough light, hold the camera straight and not too close. If it still fails, take a photo and choose \"From photo\", or type the code: Pairr checks it for mistakes.")),
        (T("Ik zie geen NFC of import uit Woning", "I don't see NFC or Import from Home"),
         T("NFC werkt alleen op de iPhone. Importeren uit de Woning-app kan op iPhone en iPad, en alleen als je Pairr toegang tot Woning hebt gegeven.",
           "NFC only works on iPhone. Importing from the Home app works on iPhone and iPad, and only once you've given Pairr access to Home.")),
        (T("Ik heb een nieuwe telefoon", "I have a new phone"),
         T("Log in met hetzelfde Apple-account, zet de iCloud-sleutelhanger aan en installeer Pairr. Je apparaten en codes komen vanzelf terug.",
           "Sign in with the same Apple Account, turn on iCloud Keychain and install Pairr. Your devices and codes come back by themselves.")),
    ]
    tip_html = "".join(f"<details><summary>{esc(q)}</summary><div><p>{esc(a)}</p></div></details>" for q, a in tips)
    body = f"""
<main id="main" class="wrap page">
  <span class="kicker">Pairr</span>
  <h1>{T("Support", "Support")}</h1>
  <p class="lead">{T("Loop je ergens tegenaan of heb je een idee? Hieronder staan de meest gestelde vragen. Staat je vraag er niet bij, laat het dan weten.", "Stuck on something or have an idea? The most common questions are below. If yours isn't there, let me know.")}</p>
  <div class="faq" style="margin-top:28px">{tip_html}</div>
  <div class="box">
    <h2 style="margin-top:0">{T("Contact", "Contact")}</h2>
    <p>{T("Meld een probleem of deel een idee via GitHub. Vermeld je apparaat en de versie van Pairr (onderaan in Instellingen). Zet nooit echte koppelcodes in je bericht: GitHub is openbaar.",
          "Report a problem or share an idea on GitHub. Mention your device and the Pairr version (bottom of Settings). Never include real setup codes in your message: GitHub is public.")}</p>
    <p style="margin:0"><a class="btn btn-primary" href="{ISSUES}" rel="noopener">{ic("radio")} {T("Probleem of idee melden", "Report a problem or idea")}</a></p>
  </div>
  <p>{T("Meer over hoe Pairr met je gegevens omgaat lees je in de", "Read more about how Pairr handles your data in the")} <a href="{p.url("/privacy/")}">{T("privacyverklaring", "privacy policy")}</a>.</p>
</main>
"""
    title = T("Support | Pairr", "Support | Pairr")
    desc = T("Hulp bij Pairr: synchroniseren via iCloud, de Apple Watch, scannen en NFC. Meld een probleem of deel een idee via GitHub.",
             "Help with Pairr: iCloud sync, the Apple Watch, scanning and NFC. Report a problem or share an idea on GitHub.")
    return (head(p, "/support/", title, desc, title, desc, T("App-icoon van Pairr", "Pairr app icon"))
            + "\n" + header(p, "/support/", False) + body + footer(p))


# ---------------------------------------------------------------- 404

def not_found() -> str:
    p = Page("nl")
    h = head(p, "/404.html", "Pagina niet gevonden | Pairr", "Deze pagina bestaat niet.", "Pairr", "Pagina niet gevonden",
             "Pairr", index=False)
    h = h.replace('<link rel="canonical" href="https://pairr.lrvdlinden.app/404.html">\n', "")
    return h + f"""
<body>
<main id="main" class="wrap page" style="text-align:center;padding-top:96px">
  <img src="/assets/img/icon-192.png" alt="" width="96" height="96" style="border-radius:22px">
  <h1 style="margin-top:24px">404</h1>
  <p class="lead" lang="nl">Deze pagina bestaat niet (meer).</p>
  <p class="lead" lang="en">This page doesn't exist (anymore).</p>
  <div class="cta" style="justify-content:center"><a class="btn btn-primary" href="/" lang="nl">Naar Pairr</a><a class="btn btn-ghost" href="/en/" lang="en">Go to Pairr</a></div>
</main>
</body>
</html>
"""


# ---------------------------------------------------------------- server files

HTACCESS = r"""# BEGIN pairr
RewriteEngine On

# Altijd HTTPS en zonder www
RewriteCond %{HTTPS} off [OR]
RewriteCond %{HTTP_HOST} ^www\. [NC]
RewriteRule ^ https://pairr.lrvdlinden.app%{REQUEST_URI} [L,R=301]

# Geen .html in adressen: /support.html en /support/index.html gaan naar /support/
RewriteCond %{THE_REQUEST} \s/+(.+?)(?:/index)?\.html[\s?] [NC]
RewriteRule ^ /%1/ [L,R=301]
RewriteCond %{THE_REQUEST} \s/+index\.html[\s?] [NC]
RewriteRule ^ / [L,R=301]

# Taal: wie de taal zelf kiest, krijgt cookie pairr_lang (via de taalknop)
# Bezoekers buiten Nederland gaan op / naar de Engelse versie, als de server het land weet
# (Cloudflare: CF-IPCountry, of mod_geoip/mod_maxminddb: GEOIP_COUNTRY_CODE). Zonder land beslist site.js.
RewriteCond %{REQUEST_URI} ^/$
RewriteCond %{HTTP_COOKIE} pairr_lang=en
RewriteRule ^ /en/ [L,R=302]

RewriteCond %{REQUEST_URI} ^/$
RewriteCond %{HTTP_COOKIE} !pairr_lang=
RewriteCond %{HTTP_USER_AGENT} !(bot|crawl|spider|slurp|facebookexternalhit|preview) [NC]
RewriteCond %{HTTP:CF-IPCountry} ^[A-Z]{2}$
RewriteCond %{HTTP:CF-IPCountry} !^(NL|BQ|XX|T1)$
RewriteRule ^ /en/ [L,R=302]

RewriteCond %{REQUEST_URI} ^/$
RewriteCond %{HTTP_COOKIE} !pairr_lang=
RewriteCond %{HTTP_USER_AGENT} !(bot|crawl|spider|slurp|facebookexternalhit|preview) [NC]
RewriteCond %{ENV:GEOIP_COUNTRY_CODE} ^[A-Z]{2}$
RewriteCond %{ENV:GEOIP_COUNTRY_CODE} !^(NL|BQ)$
RewriteRule ^ /en/ [L,R=302]

DirectoryIndex index.html
ErrorDocument 404 /404.html

<IfModule mod_headers.c>
  Header always set X-Content-Type-Options "nosniff"
  Header always set Referrer-Policy "strict-origin-when-cross-origin"
  Header always set X-Frame-Options "SAMEORIGIN"
  Header always set Permissions-Policy "camera=(), microphone=(), geolocation=(), interest-cohort=()"
  Header always set Strict-Transport-Security "max-age=31536000"
  Header append Vary "Cookie"
  <FilesMatch "\.(png|jpg|svg|ico|woff2)$">
    Header set Cache-Control "public, max-age=2592000, immutable"
  </FilesMatch>
  <FilesMatch "\.(css|js)$">
    Header set Cache-Control "public, max-age=604800"
  </FilesMatch>
  <FilesMatch "\.html$">
    Header set Cache-Control "public, max-age=600"
  </FilesMatch>
</IfModule>

<IfModule mod_mime.c>
  AddType font/woff2 .woff2
  AddType application/manifest+json .webmanifest
</IfModule>

<IfModule mod_deflate.c>
  AddOutputFilterByType DEFLATE text/html text/css application/javascript image/svg+xml application/manifest+json
</IfModule>
# END pairr
"""

BEHEER_HTACCESS = """# Beheer niet indexeren en niet cachen
<IfModule mod_headers.c>
  Header always set X-Robots-Tag "noindex, nofollow"
  Header always set Cache-Control "no-store"
  Header always set X-Frame-Options "DENY"
</IfModule>
"""


def robots() -> str:
    return f"User-agent: *\nAllow: /\nDisallow: /beheer/\n\nSitemap: {DOMAIN}/sitemap.xml\n"


def sitemap() -> str:
    paths = [("/", "1.0", "weekly"), ("/support/", "0.6", "monthly"), ("/privacy/", "0.4", "yearly")]
    out = ['<?xml version="1.0" encoding="UTF-8"?>',
           '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">']
    for path, prio, freq in paths:
        for lang in LANGS:
            loc = DOMAIN + (("/en" + path) if lang == "en" else path)
            out += ["  <url>", f"    <loc>{loc}</loc>", f"    <lastmod>{UPDATED.isoformat()}</lastmod>",
                    f'    <xhtml:link rel="alternate" hreflang="nl" href="{DOMAIN}{path}"/>',
                    f'    <xhtml:link rel="alternate" hreflang="en" href="{DOMAIN}/en{path}"/>',
                    f'    <xhtml:link rel="alternate" hreflang="x-default" href="{DOMAIN}/en{path}"/>',
                    "  </url>"]
    out.append("</urlset>")
    return "\n".join(out) + "\n"


def manifest() -> str:
    return json.dumps({
        "name": "Pairr", "short_name": "Pairr", "lang": "nl", "start_url": "/", "display": "browser",
        "background_color": "#F4F8FC", "theme_color": "#091828",
        "icons": [{"src": "/assets/img/icon-192.png", "sizes": "192x192", "type": "image/png"},
                  {"src": "/assets/img/icon-512.png", "sizes": "512x512", "type": "image/png"},
                  {"src": "/assets/img/apple-touch-icon.png", "sizes": "180x180", "type": "image/png"}],
    }, indent=2) + "\n"


# ---------------------------------------------------------------- main

def write(rel: str, text: str) -> None:
    f = OUT / rel
    f.parent.mkdir(parents=True, exist_ok=True)
    f.write_text(text)


def main() -> None:
    for lang in LANGS:
        p = Page(lang)
        pre = "en/" if lang == "en" else ""
        write(pre + "index.html", home(p))
        write(pre + "privacy/index.html", privacy(p))
        write(pre + "support/index.html", support(p))
    write("404.html", not_found())
    write(".htaccess", HTACCESS)
    write("robots.txt", robots())
    write("sitemap.xml", sitemap())
    write("site.webmanifest", manifest())
    shutil.copy(SRC / "style.css", OUT / "assets/style.css")
    shutil.copy(SRC / "site.js", OUT / "assets/site.js")
    beheer = SRC / "beheer.html"
    if beheer.exists():
        write("beheer/index.html", beheer.read_text())
        write("beheer/.htaccess", BEHEER_HTACCESS)
    print("web/ gebouwd:", sum(1 for _ in OUT.rglob("*") if _.is_file()), "bestanden")


if __name__ == "__main__":
    main()
