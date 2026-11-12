# Pairr: App Store-pakket 1.0.0

Alles voor App Store Connect, versie 1.0.0 (build 7).

## Inhoud
- `metadata/`: teksten in nl-NL en en-US (naam, ondertitel, promotietekst, beschrijving, trefwoorden, Wat is nieuw, URL's), copyright, categorieën, privacyverklaring (NL/EN) en de App Review-gegevens (`review_information/notes.txt` in het Engels, `notes-nl.txt` alleen ter referentie). Opgezet zoals fastlane deliver het verwacht.
- `app-info.md`: algemene informatie, leeftijd, privacylabel, toegankelijkheid en URL's.
- `screenshots/nl-NL` en `screenshots/en-US` (de app is meertalig, daarom beide talen):
  - `iphone-6.3` (1206×2622) en `iphone-6.1` (1179×2556): 5 per taal: lijst, scannen, apparaat, QR-weergave, instellingen
  - `ipad-13` (2064×2752) en `ipad-12.9` (2048×2732): 3 per taal: lijst met apparaat, QR-weergave, instellingen
  - `mac-2880x1800`, `mac-2560x1600`, `mac-1440x900`, `mac-1280x800`: 3 per taal (kies er één maat voor upload)
  - `watch-416x496` (Series 10/11 46 mm) en `watch-422x514` (Ultra): 2 per taal, zonder rand: QR-code en apparatenlijst
- `marketing/nl-NL` en `marketing/en-US`: productpagina-beelden: header 5244×2950 en 3840×1646, zoekresultaten 5244×2950, 3840×2560 en 1920×1280.

De schermen zijn **nagemaakt** in HTML op basis van de SwiftUI-code (geen simulatorcaptures), met verzonnen voorbeeldapparaten. Bronnen: `tools/appstore/` (`screens.py`, `build.py`, `render.js`, `finish.py`). Alle PNG's zijn RGB zonder alfa, op exacte maat.

## Uploaden
1. Maak de app aan (bundle `app.lrvdlinden.pairr`, SKU idem) en zet primaire taal op Nederlands.
2. Vul per taal de teksten uit `metadata/<taal>/` in; categorie Utilities, secundair Lifestyle.
3. Upload de schermafbeeldingen per apparaat en taal; Mac: één maat; Watch: één maat.
4. Privacylabel: Data Not Collected. Leeftijd: 4+. Encryptie: geen niet-vrijgestelde encryptie.
5. App Review: notities uit `review_information/notes.txt`, geen inlog nodig. Telefoon en e-mail zelf invullen (TODO).
6. Productpagina-beelden (`marketing/`) bij de App Store-productpagina of in-app-evenementen, als je die gebruikt.
