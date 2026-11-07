# Pairr

Een kluis voor alle koppelcodes van je slimme huis: HomeKit, Matter, Zigbee, Philips Hue, Z-Wave, wifi en pincodes. Gratis, zonder in-app aankopen.

- **Platforms:** iPhone, iPad en Mac (één app, universal purchase) en Apple Watch.
- **Bundle ID:** `app.lrvdlinden.pairr` (Watch: `app.lrvdlinden.pairr.watchkitapp`).
- **Versie:** 1.0.0 (build 1). Minimaal iOS/iPadOS 17, macOS 14, watchOS 10.
- **Team:** EU3UY476T6, automatisch ondertekenen.

## Project openen

Het Xcode-project wordt gemaakt met [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```sh
brew install xcodegen
xcodegen generate
open Pairr.xcodeproj
```

Kies het schema **Pairr** en een iPhone, iPad of "My Mac" als bestemming.

## Capabilities (in het developer-account)

Bij het eerste bouwen maakt Xcode de App ID's aan. Controleer daarna bij de App ID `app.lrvdlinden.pairr`:

- **iCloud:** CloudKit en iCloud Documents, container `iCloud.app.lrvdlinden.pairr` (ook voor de Watch-app).
- **Push Notifications:** nodig voor de iCloud-synchronisatie op de achtergrond.
- **HomeKit:** voor het importeren uit de Woning-app (alleen iPhone/iPad).
- **NFC Tag Reading:** alleen iPhone.
- **Keychain Sharing:** groep `app.lrvdlinden.pairr.shared` (app en Watch).

Zet het CloudKit-schema vóór de release in het CloudKit Dashboard op **Production** (Deploy Schema Changes).

## Hoe het werkt

- **Opslag:** SwiftData met CloudKit, in de privédatabase van de gebruiker. Verwijderen van de app wist niets: na herinstallatie komt alles terug.
- **Versleuteling:** codes, QR-codes en bijlagen zijn versleuteld met AES-GCM. De sleutel van 256 bits staat in de iCloud-sleutelhanger (synchroniseert, blijft bewaard na verwijderen). De Watch krijgt de sleutel van de iPhone via WatchConnectivity.
- **Back-ups:**
  - wekelijks automatisch naar iCloud Drive → Pairr → Backups (versleuteld met de kluissleutel, laatste 5);
  - handmatig een back-up met wachtwoord (PBKDF2-SHA256 + AES-GCM), werkt ook zonder iCloud;
  - export naar PDF (printklaar met QR-codes), CSV en Markdown; import uit CSV en back-ups.
- **Herkenning van codes:** HomeKit (`X-HM://`, 8 cijfers), Matter (`MT:` QR, 11/21 cijfers met Verhoeff-controle), Zigbee (install code met CRC-16/X-25 en IEEE-adres), Hue-serienummer (6 tekens), Z-Wave (DSK, SmartStart-QR).

## Mappen

- `Shared/`: modellen, kluis, code-herkenning, logo en gedeelde views (app én Watch), `Localizable.xcstrings`.
- `Pairr/`: de app voor iPhone, iPad en Mac.
- `PairrWatch/`: de Watch-app.

## Talen

Engels (ontwikkeltaal), Nederlands, Duits, Frans, Spaans, Italiaans, Zweeds, Noors, Deens en Pools.

Meer apps: [lrvdlinden.app](https://lrvdlinden.app)
