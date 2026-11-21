# PH.SwiftEdit — Riepilogo lavoro: logo e icone app (macOS + iPhone)

Questo documento riassume il lavoro svolto sul logo e sulle icone dell'app, e lo confronta con i requisiti indicati nella conversazione. Per ogni requisito dice se è soddisfatto, come, e cosa resta aperto.

## 1. Logo approvato (concept E2)

- Sorgente: [logo-e2-refined.svg](logo-e2-refined.svg)
- Anteprima: [logo-e2-refined-512.png](logo-e2-refined-512.png)
- Design system di lavoro (tutti i concept A–F, palette, indice asset): [PH.SwiftEdit Logo Concepts](https://claude.ai/artifact/E7m1JE96Fqyj1STvmtRJ3A) — privato, da condividere dal menu Share.

Il concept E2 è la rielaborazione della piuma dal riferimento fornito (piuma con punta ricurva e barbe tagliate in negativo) dentro un triangolo rovesciato a contorno viola. Il triangolo è stato ingrandito rispetto ai concept iniziali (base 400 px su un canvas 512 px). Lo stelo della piuma è stato spostato a circa 14 px dal bordo sinistro del triangolo per evitare il contatto.

## 2. Requisiti e stato

| # | Requisito (dalla richiesta) | Come è soddisfatto | Stato |
|---|---|---|---|
| R1 | Logo molto dark | Sfondo `#0B0614` (token `logo-ground`), quasi nero viola | Soddisfatto |
| R2 | Colore viola | Contorno e piuma in gradiente viola (`#A78BFA` → `#7C3AED`) | Soddisfatto |
| R3 | Triangolo equilatero rovesciato (punta in basso) | Triangolo rovesciato con punta in basso. Base 400 px, lati circa 415 px: **non è perfettamente equilatero** (scarto circa 4%) | Parziale — approvato così; correggibile |
| R4 | Dentro il triangolo, una piuma | Piuma ricalcata dal riferimento fornito, con barbe e punta ricurva | Soddisfatto |
| R5 | Piuma rielaborata sul riferimento, triangolo più grande | Concept E2, triangolo ingrandito rispetto alla prima versione | Soddisfatto |
| R6 | Icone per app Swift su macOS | Set `AppIcon.appiconset` macOS con 10 immagini (16–1024 px, 1x e 2x) | Soddisfatto |
| R7 | Icone per iPhone | Set `AppIcon.appiconset` iOS con 8 immagini iPhone più la 1024 px per App Store | Soddisfatto |
| R8 | Palette viola della costituzione | Il viola è l'accento; l'icona usa lo sfondo scuro, coerente con la regola del canvas `#000000` | Parziale — vedi nota 4.2 |
| R9 | Salvataggio in `reasoning/001_project-constitution/deliverables/assets` | Tutti i file sono in questa cartella (sezione 3) | Soddisfatto |
| R10 | Documento riepilogativo con i requisiti | Questo file | Soddisfatto |

## 3. File prodotti

```
deliverables/assets/
├── logo-e2-refined.svg              ← logo approvato (sorgente)
├── logo-e2-refined-512.png          ← anteprima
├── app-icons/
│   ├── macos/AppIcon.appiconset/    ← icone macOS
│   │   ├── Contents.json
│   │   └── icon_{16,32,128,256,512}x…@1x/@2x.png  (10 file)
│   └── ios/AppIcon.appiconset/      ← icone iPhone + App Store
│       ├── Contents.json
│       └── AppIcon-{40,60,58,87,80,120,180,1024}.png  (8 file)
└── app-icons-riepilogo.md           ← questo documento
```

### Icone macOS (`app-icons/macos/AppIcon.appiconset`)

| File | Pixel | Scala |
|---|---|---|
| `icon_16x16.png` | 16 | 1x |
| `icon_16x16@2x.png` | 32 | 2x |
| `icon_32x32.png` | 32 | 1x |
| `icon_32x32@2x.png` | 64 | 2x |
| `icon_128x128.png` | 128 | 1x |
| `icon_128x128@2x.png` | 256 | 2x |
| `icon_256x256.png` | 256 | 1x |
| `icon_256x256@2x.png` | 512 | 2x |
| `icon_512x512.png` | 512 | 1x |
| `icon_512x512@2x.png` | 1024 | 2x |

Il contenuto è un riquadro arrotondato da 824 px centrato in una tela da 1024 px, con margine di 100 px, come nella griglia delle icone macOS. Lo sfondo è trasparente fuori dal riquadro, come richiesto da macOS.

### Icone iPhone (`app-icons/ios/AppIcon.appiconset`)

| File | Pixel | Uso |
|---|---|---|
| `AppIcon-40.png` | 40 | Notifiche iPhone 2x |
| `AppIcon-60.png` | 60 | Notifiche iPhone 3x |
| `AppIcon-58.png` | 58 | Impostazioni iPhone 2x |
| `AppIcon-87.png` | 87 | Impostazioni iPhone 3x |
| `AppIcon-80.png` | 80 | Spotlight iPhone 2x |
| `AppIcon-120.png` | 120 | Spotlight iPhone 3x; App iPhone 2x |
| `AppIcon-180.png` | 180 | App iPhone 3x |
| `AppIcon-1024.png` | 1024 | App Store (marketing) |

Le icone iOS sono quadrate, a tutta tela, senza trasparenza e senza angoli arrotondati: iOS applica la maschera da sé. La `AppIcon-1024.png` non ha canale alfa, come richiesto da App Store.

## 4. Note e limiti

1. **Triangolo non perfettamente equilatero (R3).** Con base 400 px l'altezza ideale sarebbe circa 346 px, mentre il disegno approvato ne ha circa 364. Il logo approvato non è stato modificato. Se vuoi il triangolo equilatero esatto, va rifatto il disegno del contorno e rigenerate le icone.
2. **Icone e tema chiaro/scuro (R8).** Il logo ha sempre lo sfondo scuro, quindi non segue i temi Light/Black/Auto dell'app. Le icone iOS 18+ con varianti *dark* e *tinted* non sono state generate: il logo è già scuro, quindi servirebbe solo una variante tinta, da decidere.
3. **Leggibilità a piccole dimensioni.** A 16–32 px la piuma diventa quasi illeggibile: le barbe si perdono. Il set macOS usa comunque la stessa illustrazione a tutte le scale. Se serve un'icona leggibile a 16 px, va disegnata una variante semplificata con meno barbe.
4. **Formato.** Sono stati prodotti set `AppIcon.appiconset` classici. Xcode 26 può anche usare il formato `.icon` (Icon Composer), non generato qui.
5. **iPad e Mac Catalyst.** Non richiesti: il set iOS copre solo iPhone e App Store.
6. **Griglia macOS.** La griglia 824/100 px è la convenzione del template Apple; non ho verificato l'ombra che macOS aggiunge in sistema.

## 5. Come usare le icone in Xcode

1. Apri il progetto e il file `Assets.xcassets`.
2. Trascina la cartella `app-icons/macos/AppIcon.appiconset` nel catalogo, sostituendo `AppIcon`; ripeti con `app-icons/ios/AppIcon.appiconset` per il target iPhone, oppure usa lo stesso nome `AppIcon` nel catalogo di ciascuna piattaforma.
3. Verifica nell'editor che ogni slot sia riempito.

## 6. Prossimi passi proposti

- Decidere se correggere il triangolo a equilatero perfetto (nota 1).
- Decidere se generare la variante tinta per iOS 18+ (nota 2).
- Valutare una variante semplificata per 16–32 px (nota 3).
