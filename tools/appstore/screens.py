"""Nagemaakte schermen van Pairr (HTML), op basis van de SwiftUI-code: DeviceListView, DeviceDetailView,
CodeDisplayView, ScannerView, SettingsView en de Watch-app. Teksten uit Shared/Localizable.xcstrings (nl) en de
Engelse ontwikkeltaal. Voorbeeldgegevens zijn neutraal en verzonnen."""
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "web"))
import build as B  # noqa: E402

ic = B.ic
QR = B.QR_PAYLOAD

# soort code: kleur (licht), icoon
CT = {"homekit": ("#F29D12", "house"), "matter": ("#2F6FE4", "share-2"), "zigbee": ("#E0474F", "antenna"),
      "hue": ("#7B61FF", "lightbulb"), "zwave": ("#1696C8", "radio"), "wifi": ("#27AE60", "wifi"), "pin": ("#6B7280", "hash")}
CT_NAME = {"homekit": "HomeKit", "matter": "Matter", "zigbee": "Zigbee", "hue": "Philips Hue", "zwave": "Z-Wave",
           "wifi": ("Wifi-wachtwoord", "Wi-Fi password"), "pin": ("Pincode", "PIN code")}

# soort apparaat: icoon, kleur van de tegel
KIND = {"light": ("lightbulb", "#F2A516"), "plug": ("plug", "#2F6FE4"), "thermostat": ("heater", "#E8603C"),
        "contact": ("door-open", "#14A884"), "lock": ("lock", "#5A43E0"), "camera": ("camera", "#27AE60"),
        "router": ("router", "#6B7280"), "speaker": ("speaker", "#0A8FD6")}


def T(lang, nl, en):
    return nl if lang == "nl" else en


def devices(lang):
    t = lambda nl, en: T(lang, nl, en)  # noqa: E731
    return [
        (t("Woonkamer", "Living room"), [
            ("light", t("Lamp bank", "Sofa lamp"), "Philips Hue White", ["hue", "zigbee"], True),
            ("plug", t("Stekker tv", "TV plug"), "Eve Energy", ["matter", "homekit"], False),
            ("speaker", t("Speaker", "Speaker"), "IKEA Symfonisk", ["wifi"], False),
        ]),
        (t("Hal", "Hallway"), [
            ("contact", t("Voordeur", "Front door"), "Aqara P2", ["matter"], False),
            ("lock", t("Slim slot", "Smart lock"), "Nuki Smart Lock", ["matter", "pin"], True),
            ("thermostat", t("Thermostaat", "Thermostat"), "tado° V3+", ["homekit"], False),
        ]),
        (t("Tuin", "Garden"), [
            ("camera", t("Camera oprit", "Driveway camera"), "Eufy Cam", ["wifi"], False),
        ]),
        (t("Meterkast", "Utility cupboard"), [
            ("router", t("Router", "Router"), "Mesh router", ["pin", "wifi"], False),
        ]),
    ]


def badge(t, size=22):
    c, i = CT[t]
    return f'<i class="cb" style="background:{c};width:{size}px;height:{size}px">{ic(i)}</i>'


def avatar(kind, size=40):
    i, c = KIND[kind]
    return f'<span class="av" style="background:{c};width:{size}px;height:{size}px;border-radius:{size*.26:.0f}px">{ic(i)}</span>'


CSS = """
.ios{position:absolute;inset:0;background:#F2F2F7;color:#000;font-family:Inter,-apple-system,system-ui,sans-serif;overflow:hidden;font-size:17px;letter-spacing:-.01em}
.ios.dark{background:#000;color:#fff}
.ios .sb{height:54px;display:flex;justify-content:space-between;align-items:center;padding:0 34px 0 44px;font-weight:600;font-size:17px}
.ios .sb .r{display:flex;gap:6px;align-items:center}
.ios .isl{position:absolute;top:11px;left:50%;transform:translateX(-50%);width:124px;height:36px;border-radius:20px;background:#000;z-index:5}
.ios svg{width:100%;height:100%}
.nb{display:flex;justify-content:flex-end;align-items:center;gap:10px;padding:2px 16px 0;height:44px}
.nb .ib{width:36px;height:36px;border-radius:50%;background:#E3E3E8;color:#0A84FF;display:grid;place-items:center}
.nb .ib svg{width:19px;height:19px}
.nb .tx{color:#0A84FF;font-weight:400;font-size:17px}
.lt{font:700 34px/1.1 Inter,sans-serif;letter-spacing:-.02em;padding:0 20px 8px}
.srch{margin:0 16px 14px;background:#E3E3E8;border-radius:11px;height:38px;display:flex;align-items:center;gap:7px;padding:0 9px;color:#8A8A8E}
.srch svg{width:17px;height:17px}
.sh{font-size:13px;color:#6D6D72;text-transform:uppercase;padding:0 36px 7px;letter-spacing:0}
.sh.nt{text-transform:none;font-weight:600;font-size:20px;color:#000;padding:4px 36px 8px}
.grp{background:#fff;border-radius:12px;margin:0 16px 22px;overflow:hidden}
.r{display:flex;align-items:center;gap:12px;padding:9px 16px;position:relative}
.r+.r::before{content:"";position:absolute;top:0;right:0;left:68px;border-top:.5px solid #D1D1D6}
.grp.ft .r+.r::before{left:16px}
.r .tx{flex:1;min-width:0}
.r b{display:block;font-weight:600;font-size:17px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.r small{display:block;font-size:15px;color:#8A8A8E;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.r .bs{display:flex;gap:4px}
.r .chev{width:14px;height:14px;color:#C4C4C7;flex:none}
.r .star{width:13px;height:13px;color:#FFCC00;fill:#FFCC00}
.cb{display:inline-grid;place-items:center;border-radius:6px;color:#fff;flex:none}
.cb svg{width:62%;height:62%;stroke-width:2.6}
.av{display:inline-grid;place-items:center;color:#fff;flex:none}
.av svg{width:55%;height:55%}
.lc{display:flex;justify-content:space-between;gap:12px;padding:12px 16px;position:relative}
.lc+.lc::before{content:"";position:absolute;top:0;right:0;left:16px;border-top:.5px solid #D1D1D6}
.lc span:last-child{color:#8A8A8E;text-align:right}
.blue{color:#0A84FF}
.tog{width:51px;height:31px;border-radius:16px;background:#E9E9EB;position:relative;flex:none}
.tog::after{content:"";position:absolute;top:2px;left:2px;width:27px;height:27px;border-radius:50%;background:#fff;box-shadow:0 2px 4px rgba(0,0,0,.2)}
.tog.on{background:#34C759}.tog.on::after{left:22px}
.li{width:29px;height:29px;border-radius:7px;display:grid;place-items:center;color:#fff;flex:none}
.li svg{width:18px;height:18px}
.foot{font-size:13px;color:#6D6D72;padding:0 36px;margin:-14px 0 22px;line-height:1.35}
.home{position:absolute;bottom:8px;left:50%;transform:translateX(-50%);width:140px;height:5px;border-radius:3px;background:#000}
.dark .home{background:#fff}
"""


def statusbar(dark=False):
    c = "#fff" if dark else "#000"
    return (f'<div class="isl"></div><div class="sb" style="color:{c}"><span>9:41</span><span class="r">'
            f'<svg viewBox="0 0 18 12" style="width:18px;height:12px" fill="{c}"><rect x="0" y="8" width="3" height="4" rx="1"/><rect x="5" y="5" width="3" height="7" rx="1"/><rect x="10" y="2.5" width="3" height="9.5" rx="1"/><rect x="15" y="0" width="3" height="12" rx="1"/></svg>'
            f'<span style="width:16px;height:12px;display:inline-block">{ic("wifi-high")}</span>'
            f'<svg viewBox="0 0 27 13" style="width:27px;height:13px"><rect x=".5" y=".5" width="23" height="12" rx="3.5" fill="none" stroke="{c}" opacity=".4"/><rect x="2" y="2" width="20" height="9" rx="2" fill="{c}"/><rect x="24.5" y="4.5" width="1.5" height="4" rx=".7" fill="{c}" opacity=".4"/></svg>'
            f'</span></div>')


def list_rows(lang, rows, chevron=True, selected=None):
    out = []
    for kind, name, model, codes, fav in rows:
        sel = ' style="background:#0A84FF22"' if selected == name else ""
        out.append(f'<div class="r"{sel}>{avatar(kind)}<span class="tx"><b>{name}</b><small>{model}</small></span>'
                   f'<span class="bs">{"".join(badge(c) for c in codes)}</span>'
                   + (f'<svg class="star" viewBox="0 0 24 24"><path d="M12 2l3.1 6.3 6.9 1-5 4.9 1.2 6.8L12 17.8 5.8 21l1.2-6.8-5-4.9 6.9-1z"/></svg>' if fav else "")
                   + (f'<span class="chev">{ic("chevron-right")}</span>' if chevron else "") + "</div>")
    return "".join(out)


def screen_list(lang, chevron=True, selected=None, status=True):
    secs = "".join(f'<div class="sh">{room}</div><div class="grp">{list_rows(lang, rows, chevron, selected)}</div>'
                   for room, rows in devices(lang))
    return (f'{statusbar() if status else ""}<div class="nb"><span class="ib">{ic("list-filter")}</span><span class="ib">{ic("arrow-up-down")}</span>'
            f'<span class="ib">{ic("settings")}</span><span class="ib">{ic("plus")}</span></div>'
            f'<div class="lt">{T(lang, "Alle apparaten", "All devices")}</div>'
            f'<div class="srch">{ic("search")}<span>{T(lang, "Zoek apparaten", "Search devices")}</span></div>{secs}')


def screen_detail(lang, status=True, back=True):
    t = lambda nl, en: T(lang, nl, en)  # noqa: E731
    code_rows = (
        f'<div class="r" style="padding:12px 16px">{badge("matter",30)}<span class="tx"><small style="font-size:13px">{t("Koppelcode", "Pairing code")}</small>'
        f'<b style="font:600 22px/1.25 ui-monospace,Menlo,monospace;letter-spacing:.02em">3497-011-2332</b></span>'
        f'<span class="cb" style="background:#E5F0FF;color:#0A84FF;width:36px;height:36px;border-radius:18px">{ic("qr-code")}</span>'
        f'<span class="cb" style="background:#E5F0FF;color:#0A84FF;width:36px;height:36px;border-radius:18px">{ic("copy")}</span></div>'
        f'<div class="r" style="padding:12px 16px">{badge("homekit",30)}<span class="tx"><small style="font-size:13px">{t("Setup-code", "Setup code")}</small>'
        f'<b style="font:600 22px/1.25 ui-monospace,Menlo,monospace;letter-spacing:.06em">•••-••-•••</b></span>'
        f'<span class="cb" style="background:#E5F0FF;color:#0A84FF;width:36px;height:36px;border-radius:18px">{ic("qr-code")}</span>'
        f'<span class="cb" style="background:#E5F0FF;color:#0A84FF;width:36px;height:36px;border-radius:18px">{ic("copy")}</span></div>'
        f'<div class="r blue" style="padding:13px 16px;gap:10px"><span style="width:22px;height:22px">{ic("plus")}</span>{t("Code toevoegen", "Add code")}</div>')
    det = [(t("Fabrikant", "Manufacturer"), "Eve Systems"), (t("Model", "Model"), "Eve Energy"),
           (t("Serienummer", "Serial number"), "RV49L1A01234"), ("Firmware", "3.5.0"),
           (t("Originele sticker", "Original sticker"), t("Achterkant stekker", "Back of the plug"))]
    dets = "".join(f'<div class="lc"><span>{a}</span><span>{b}</span></div>' for a, b in det)
    nb = (f'<div class="nb" style="justify-content:space-between">'
          + (f'<span class="tx" style="display:flex;align-items:center;gap:2px"><span style="width:24px;height:24px">{ic("chevron-left")}</span>{t("Alle apparaten", "All devices")}</span>' if back else "<span></span>")
          + f'<span style="display:flex;gap:16px;align-items:center"><span class="tx" style="width:22px;height:22px">{ic("star")}</span><span class="tx">{t("Wijzig", "Edit")}</span></span></div>')
    return (f'{statusbar() if status else ""}{nb}'
            f'<div style="display:flex;gap:16px;align-items:center;padding:14px 20px 24px">{avatar("plug",64)}<div>'
            f'<div style="font:700 24px/1.2 Inter">{t("Stekker tv", "TV plug")}</div><div style="color:#8A8A8E;font-size:15px">{t("Slimme stekker", "Smart plug")}</div>'
            f'<div style="color:#8A8A8E;font-size:15px;display:flex;gap:5px;align-items:center"><span style="width:15px;height:15px">{ic("house")}</span>{t("Thuis · Woonkamer", "Home · Living room")}</div></div></div>'
            f'<div class="sh">Codes</div><div class="grp ft">{code_rows}</div>'
            f'<div class="sh">Details</div><div class="grp">{dets}</div>')


def screen_code(lang, status=True):
    t = lambda nl, en: T(lang, nl, en)  # noqa: E731
    return (f'{statusbar(True) if status else ""}<div style="position:absolute;inset:{58 if status else 10}px 0 0;background:#fff;color:#000;border-radius:12px 12px 0 0">'
            f'<div class="nb" style="justify-content:space-between;padding-top:10px"><span></span><b style="font-weight:600">{t("Stekker tv", "TV plug")}</b><span class="tx" style="font-weight:600">{t("Gereed", "Done")}</span></div>'
            f'<div style="display:flex;flex-direction:column;align-items:center;gap:22px;padding:22px 24px">'
            f'<span style="display:inline-flex;gap:6px;align-items:center;background:#2F6FE4;color:#fff;border-radius:99px;padding:5px 11px;font-weight:600;font-size:13px"><span style="width:14px;height:14px">{ic("share-2")}</span>Matter</span>'
            f'<div style="background:#fff;border-radius:26px;padding:22px;box-shadow:0 6px 16px rgba(0,0,0,.12);width:268px">{B.qr_svg(QR)}</div>'
            f'<div style="text-align:center"><div style="color:#8A8A8E;font-size:15px;margin-bottom:6px">{t("Koppelcode", "Pairing code")}</div>'
            f'<div style="font:700 34px/1.1 ui-monospace,Menlo,monospace">3497-011-2332</div></div>'
            f'<span style="display:inline-flex;gap:7px;align-items:center;background:#E5F0FF;color:#0A84FF;border-radius:10px;padding:8px 14px;font-size:16px"><span style="width:17px;height:17px">{ic("copy")}</span>{t("Kopieer code", "Copy code")}</span>'
            f'<div style="color:#8A8A8E;font-size:13px;text-align:center;line-height:1.35">{t("Scan deze code in de Woning-app, Google Home, SmartThings, Homey of een andere Matter-app.", "Scan this code in the Home app, Google Home, SmartThings, Homey or another Matter app.")}</div>'
            f'</div></div>')


def screen_scan(lang):
    t = lambda nl, en: T(lang, nl, en)  # noqa: E731
    sticker = (f'<div style="position:absolute;left:50%;top:330px;transform:translate(-50%,-50%) rotate(-4deg);width:250px;background:#FBFBF8;border-radius:16px;padding:18px;box-shadow:0 20px 40px rgba(0,0,0,.5);color:#111">'
               f'<div style="display:flex;gap:14px;align-items:center"><div style="width:110px">{B.qr_svg(QR)}</div>'
               f'<div style="font:700 13px/1.4 ui-monospace,Menlo,monospace">3497-011-2332<br><span style="font:500 10px Inter;color:#666">Matter</span></div></div></div>')
    return (f'<div style="position:absolute;inset:0;background:radial-gradient(120% 70% at 50% 40%,#5b5f66,#1d2024 70%)"></div>'
            f'<div style="position:absolute;inset:0;background:repeating-linear-gradient(90deg,rgba(255,255,255,.025) 0 2px,transparent 2px 9px)"></div>{sticker}'
            f'<div style="position:absolute;left:50%;top:330px;transform:translate(-50%,-50%);width:290px;height:200px;border-radius:22px;border:4px solid #38C8FF;box-shadow:0 0 0 2000px rgba(0,0,0,.35),0 0 30px rgba(56,200,255,.5)"></div>'
            f'{statusbar(True)}<div style="position:absolute;top:54px;left:0;right:0;height:56px;display:flex;align-items:center;justify-content:space-between;padding:0 20px;color:#fff;background:rgba(30,30,32,.6);backdrop-filter:blur(10px)">'
            f'<span style="color:#38C8FF">{t("Annuleer", "Cancel")}</span><b style="font-weight:600">{t("Scan code", "Scan code")}</b><span style="width:50px"></span></div>'
            f'<div style="position:absolute;left:24px;right:24px;bottom:110px;color:#fff;text-align:center;font-size:16px;background:rgba(0,0,0,.55);border-radius:14px;padding:14px 16px">'
            f'{t("Richt de camera op de QR-code of de code op de sticker.", "Point the camera at the QR code or the code on the sticker.")}</div>')


def screen_settings(lang):
    t = lambda nl, en: T(lang, nl, en)  # noqa: E731

    def row(color, icon, label, right):
        return f'<div class="r">{f"<span class=li style=background:{color}>{ic(icon)}</span>"}<span class="tx" style="font-size:17px">{label}</span>{right}</div>'
    chev = f'<span class="chev">{ic("chevron-right")}</span>'
    return (f'{statusbar()}<div class="nb" style="justify-content:space-between"><span></span><b style="font-weight:600">{t("Instellingen", "Settings")}</b><span class="tx" style="font-weight:600">{t("Gereed", "Done")}</span></div>'
            f'<div style="height:18px"></div>'
            f'<div class="sh">{t("Beveiliging", "Security")}</div><div class="grp">'
            + row("#34C759", "scan-face", t("Pairr vergrendelen", "Lock Pairr"), '<span class="tog on"></span>')
            + row("#8E8E93", "eye", t("Codes direct tonen", "Show codes right away"), '<span class="tog"></span>')
            + f'</div><div class="foot" style="margin-top:-14px">{t("Het slot gebruikt Face ID, Touch ID of je toegangscode.", "The lock uses Face ID, Touch ID or your passcode.")}</div>'
            f'<div class="sh">{t("Je gegevens", "Your data")}</div><div class="grp">'
            + row("#0A84FF", "cloud", t("iCloud-synchronisatie", "iCloud sync"), f'<span style="color:#8A8A8E">{t("Aan", "On")}</span>{chev}')
            + row("#5856D6", "archive-restore", t("Back-up, export en import", "Backup, export and import"), chev)
            + row("#F29D12", "house", t("Importeer uit de Woning-app", "Import from the Home app"), chev)
            + f'</div><div class="foot">{t("Alles staat in je eigen iCloud. Als je de app verwijdert, blijven je gegevens bewaard: na opnieuw installeren komen ze terug.", "Everything is stored in your own iCloud. Deleting the app doesn&#39;t delete your data: after reinstalling, it comes back.")}</div>'
            f'<div class="sh">{t("Productgegevens", "Product details")}</div><div class="grp">'
            + row("#0A8FD6", "search", t("Productgegevens online opzoeken", "Look up product details online"), '<span class="tog on"></span>')
            + row("#14A884", "badge-check", t("Merklogo’s tonen", "Show brand logos"), '<span class="tog on"></span>')
            + "</div>")


def watch_screen(lang):
    return (f'<div style="position:absolute;inset:0;background:#000;color:#fff;font-family:Inter,sans-serif;display:flex;flex-direction:column;align-items:center;padding:10px 12px 0">'
            f'<div style="display:flex;justify-content:space-between;width:100%;font-size:15px;font-weight:600;padding:0 6px"><span style="color:#38C8FF">Matter</span><span>9:41</span></div>'
            f'<div style="background:#fff;border-radius:14px;padding:9px;width:150px;margin-top:10px">{B.qr_svg(QR)}</div>'
            f'<div style="font:700 14px ui-monospace,Menlo,monospace;margin-top:8px">3497-011-2332</div></div>')


def watch_list(lang):
    rows = [d for _, rs in devices(lang) for d in rs][:4]
    items = "".join(f'<div style="background:#222224;border-radius:14px;padding:8px 10px;display:flex;gap:8px;align-items:center;margin-bottom:6px">'
                    f'{avatar(k,26)}<span style="min-width:0"><b style="display:block;font-size:14px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">{n}</b></span></div>'
                    for k, n, m, c, f in rows)
    return (f'<div style="position:absolute;inset:0;background:#000;color:#fff;font-family:Inter,sans-serif;padding:8px 8px 0">'
            f'<div style="display:flex;justify-content:space-between;font-size:15px;font-weight:600;padding:2px 6px 8px"><span style="color:#38C8FF">Pairr</span><span>9:41</span></div>{items}</div>')


def sidebar(lang, mac=False):
    t = lambda nl, en: T(lang, nl, en)  # noqa: E731
    def it(icon, label, sel=False, color="#0A84FF"):
        bg = "background:#0A84FF;color:#fff;" if sel else ""
        ic_c = "#fff" if sel else color
        return (f'<div style="display:flex;gap:9px;align-items:center;padding:{6 if mac else 10}px 10px;border-radius:{6 if mac else 10}px;{bg}font-size:{13 if mac else 17}px">'
                f'<span style="width:{15 if mac else 20}px;height:{15 if mac else 20}px;color:{ic_c}">{ic(icon)}</span>{label}</div>')
    h = lambda s: f'<div style="font-size:{11 if mac else 13}px;font-weight:600;color:#8A8A8E;padding:{10 if mac else 16}px 10px 4px">{s}</div>'  # noqa: E731
    out = (it("smartphone", t("Alle apparaten", "All devices"), True) + it("star", t("Favorieten", "Favorites"))
           + it("clock", t("Recent toegevoegd", "Recently added")) + it("circle-dashed", t("Zonder code", "Without a code")))
    out += h("Codes") + "".join(it(CT[c][1], CT_NAME[c] if isinstance(CT_NAME[c], str) else CT_NAME[c][0 if lang == "nl" else 1], color=CT[c][0])
                               for c in ["homekit", "matter", "zigbee", "hue", "wifi", "pin"])
    out += h(t("Kamers", "Rooms")) + "".join(it("door-open", r) for r, _ in devices(lang))
    return out
