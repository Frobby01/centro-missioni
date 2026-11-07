# Widget macOS

Widget WidgetKit (piccolo/medio/grande): livello, XP, streak, missione del giorno e task di oggi, letti da `tasks.json` nel repo dati. Solo lettura; un clic apre il sito.

```bash
brew install xcodegen   # solo se cambi project.yml
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project CentroMissioni.xcodeproj -scheme CentroMissioni -configuration Release -derivedDataPath build build
rm -rf /Applications/CentroMissioni.app && cp -R build/Build/Products/Release/CentroMissioni.app /Applications/
open /Applications/CentroMissioni.app   # registra il widget
```

Poi: apri l'app, incolla il token GitHub e premi Salva (finisce in `~/Library/Application Support/CentroMissioni/token`); clic destro sul desktop → Modifica widget → Centro Missioni.
Niente App Intents: con la firma locale macOS 27 li ignora e il widget resta grigio. I chip del filtro aprono `centromissioni://filter/<id>`, che l'app gestisce ed esce.
La logica XP/livelli è copiata da `index.html` (`stats()`, `focusHTML()`): se cambi lì, aggiorna `Widget/Model.swift`.

Se dopo un riavvio o un aggiornamento di macOS il widget diventa nero, macOS ha dimenticato l'estensione (firma locale, senza team Apple): apri una volta l'app da /Applications.
