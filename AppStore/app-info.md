# Pairr: app-informatie voor App Store Connect

## Algemene informatie
- **Bundle ID**: `app.lrvdlinden.pairr` (Watch: `app.lrvdlinden.pairr.watchkitapp`)
- **SKU**: `app.lrvdlinden.pairr`
- **Apple ID**: TODO (staat in App Store Connect; zet hem ook als `ASC_PAIRR_APPLE_ID` in app.lrvdlinden.secrets voor het beheer, omdat de naam in de store niet precies "Pairr" is)
- **Versie**: 1.0.0 (build 7)
- **Primaire taal**: Nederlands (nl-NL)
- **Talen van de app**: Engels, Nederlands, Duits, Frans, Spaans, Italiaans, Zweeds, Noors (Bokmål), Deens, Pools
- **Platforms**: iPhone en iPad (iOS/iPadOS 17+), Mac (macOS 14+, native, universal purchase), Apple Watch (watchOS 10+)
- **Categorie**: primair **Utilities** (een kluis/naslag voor codes, gereedschap bij het koppelen van apparaten); secundair **Lifestyle** (slim huis)
- **Content Rights**: kies **Yes** (de app toont inhoud van derden) en bevestig dat de rechten in orde zijn: fabrikant- en productnamen komen uit de openbare Matter Distributed Compliance Ledger van de CSA, logo's zijn de openbare websitepictogrammen van het merk, alleen ter herkenning bij het apparaat van de gebruiker.
- **License Agreement**: Apple Standard EULA
- **Encryptie**: `ITSAppUsesNonExemptEncryption = NO` (AES-GCM via CryptoKit, alleen om de eigen gegevens van de gebruiker te beschermen; vrijgesteld)
- **Prijs**: gratis, geen in-app-aankopen

## Leeftijdsclassificatie
Alle vragen: **None / No** (geen geweld, seksuele inhoud, grof taalgebruik, drugs, gokken, horror, medische informatie; geen onbeperkte webtoegang, geen chat of door gebruikers gedeelde inhoud, geen wedstrijden, geen leeftijdscontrole nodig). Resultaat: **4+**.

## App-privacy (privacylabel)
**Data Not Collected.**
- Geen account, geen analytics, geen crashrapportage van derden, geen reclame, geen tracking (geen ATT).
- Gegevens van de gebruiker staan in zijn eigen iCloud (CloudKit-privédatabase en iCloud Drive); de ontwikkelaar kan er niet bij.
- Opzoeken van productgegevens stuurt alleen het fabrikant- en product-ID naar de openbare Matter-database (on.dcl.csa-iot.org) en vraagt het websitepictogram van een merk op; dat zijn geen gegevens die de ontwikkelaar verzamelt.
- Geen SDK's van derden.
- `PrivacyInfo.xcprivacy` in app en Watch-app (alleen de verplichte API-redenen).

## Toegankelijkheid (Accessibility Nutrition Labels)
| Functie | iPhone | iPad | Mac | Watch | Onderbouwing |
| --- | --- | --- | --- | --- | --- |
| VoiceOver | ✓ | ✓ | ✓ | ✓ | standaard SwiftUI-elementen, labels bij icoonknoppen en badges |
| Larger Text | ✓ | ✓ | – | ✓ | tekststijlen van het systeem (Dynamic Type); de grote code in de QR-weergave schaalt mee met minimumScaleFactor |
| Dark Interface | ✓ | ✓ | ✓ | ✓ | eigen kleuren met licht/donker-variant, Weergave-keuze |
| Differentiate Without Color Alone | ✓ | ✓ | ✓ | ✓ | elke soort code heeft een eigen icoon én naam, niet alleen een kleur |
| Reduced Motion | ✓ | ✓ | ✓ | – | splash respecteert Verminder beweging |
| Sufficient Contrast | niet geclaimd | | | | niet gemeten |
| Voice Control | niet geclaimd | | | | niet getest |
| Captions / Audio Descriptions | n.v.t. | | | | geen video of audio |

## URL's
- Support: https://pairr.lrvdlinden.app/support/ (EN: /en/support/)
- Marketing: https://pairr.lrvdlinden.app/ (EN: /en/)
- Privacy: https://pairr.lrvdlinden.app/privacy/ (EN: /en/privacy/)

Vanaf build 7 linkt de app (Instellingen) naar deze pagina's, NL of EN naar de taal van het apparaat. Build 1 t/m 6 en het veld in App Store Connect gebruikten nog `https://lrvdlinden.app/pairr/privacy`: zet in App Store Connect de nieuwe privacy-URL, of laat die oude link doorsturen naar `pairr.lrvdlinden.app/privacy/`.
