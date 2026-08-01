# Konzept: Interaktive Vorstudie „Garúa-Nebelwasser Galápagos"
### Bewerbungsbeilage für FOR 5621 GArua, Teilprojekt A1 (Uni Marburg)

---

## 1. Was die App leisten muss (und was nicht)

Sie bewerben sich nicht auf eine Programmierstelle. Die App ist ein **Beleg**, kein Produkt. Sie muss in ≤ 5 Minuten Betrachtungszeit vier Dinge zeigen:

| Ausschreibungspunkt | Was die App beweisen muss |
|---|---|
| Bestandsklimamessungen, Schwerpunkt Nebel | Sie können Klimazeitreihen aufbereiten und Nebelereignisse operational definieren |
| Nebelausschlussexperiment | Sie denken in Versuchsdesign und Statistik, nicht nur in Plots |
| TLS + Satellit + ML-Extrapolation | Sie beherrschen Upscaling inkl. räumlicher Validierung |
| Feldinfrastruktur betreiben | Sie verstehen Datenqualität, Lücken, Sensordrift |

**Zwei Fallen, die es zu vermeiden gilt:**

- *Zu viel Wissenschaft.* Wenn die App so wirkt, als hätten Sie A1 schon vorweggenommen, wirkt das anmaßend gegenüber der Gruppe. Rahmen Sie es explizit als *methodische Machbarkeitsstudie mit öffentlichen Daten*.
- *Erfundene Daten.* Nichts diskreditiert schneller. Jede simulierte Größe muss im UI sichtbar als Simulation gekennzeichnet sein – oder Sie verzichten ganz darauf (siehe Modul 2).

---

## 2. Reale, frei verfügbare Datenquellen

Das ist der eigentlich wertvolle Teil: Es gibt für Galápagos genug offene Daten, um eine **echte** Vorstudie zu bauen.

### 2.1 Bodendaten

**CDF DataZone – Climatology Database** (`datazone.darwinfoundation.org/en/climate`)
Historische Tagesdaten zum Download. Zwei Schlüsselstationen:
- **Puerto Ayora** (Küste, seit 1965) – Referenz für die trockene Tieflandzone
- **Bellavista** (Hochland Santa Cruz, seit 1987) – **die Garúa-Station schlechthin**

Der Kontrast Puerto Ayora ↔ Bellavista *ist* bereits die Kernaussage des Projekts: der vertikale Feuchtegradient, den die Garúa erzeugt. Zwei Stationen, ~35 gemeinsame Jahre, kostenlos. Das reicht für ein überzeugendes Modul 1.

Das AWS-Netz des Marburger DARWIN-Vorgängerprojekts (11 Stationen, W–E-Transekt, Supersite Cerro Crocker mit Micro Rain Radar und BIRAL-Präsenzwettersensor) ist Ihre inhaltliche Anschlussstelle – erwähnen, aber nicht auf dessen Datenverfügbarkeit spekulieren.

### 2.2 Satellit

| Quelle | Zugang | Nutzen |
|---|---|---|
| **GOES ABI** (Full Disk, 10 min, 2 km) | AWS Open Data S3, kein Login | Kanäle C07 (3,9 µm) & C13 (10,3 µm) → **Night-Fog-BTD** für tief liegende Wasserwolken; Tagesgang der Stratusdecke |
| **MODIS MOD06/MYD06** | NASA LAADS / `earthaccess` | Wolkenoberkantenhöhe, optische Dicke, effektiver Radius |
| **VIIRS Day-Night-Band** | NASA | Nächtliche Stratusdetektion bei Mondlicht |
| **Copernicus DEM / SRTM 30 m** | offen | Höhe, Hangneigung, Exposition zu SE-Passat → Prädiktoren |
| **Sentinel-2 / Landsat** | Copernicus / USGS | Scalesia-Bestände, Vegetationsindizes |

Der BTD-Ansatz (T₁₀,₃ − T₃,₉) ist methodisch sauber und literaturgestützt: Wassertröpfchen emittieren bei 3,9 µm nicht wie ein Schwarzkörper, bei 10,3 µm nahezu. Wichtige Limitation, die Sie in der App *benennen* sollten: Bei mehrschichtiger Bewölkung verdeckt hohe Bewölkung die tiefe Schicht – genau deshalb braucht es die Bodenvalidierung, die A1 liefert. Diese Ehrlichkeit ist ein Kompetenzsignal.

### 2.3 Reanalyse & Klimaszenarien

- **ERA5 / ERA5-Land** (Copernicus CDS, R-Paket `ecmwfr`): Inversionsstärke (LTS/EIS), 700-hPa-Temperatur, Hebungskondensationsniveau, Grenzschichthöhe. Das ist der **physikalische Kern des „warming world"-Arguments**: Steigt die Wolkenuntergrenze schneller als das Gelände, fällt die Garúa aus der Vegetationszone heraus.
- **NOAA OISST / ONI-Index**: ENSO-Kopplung. Garúa und El Niño sind auf Galápagos antikorreliert – ein Modul, das Nebelhäufigkeit gegen ONI plottet, ist mit zwei öffentlichen Datensätzen machbar und fachlich sofort einleuchtend.
- **CMIP6** (ESGF/CDS): Projizierte LTS-Änderung für das Szenario-Modul.

---

## 3. Modulkonzept

Sechs Module, direkt auf die Aufgabenliste gemappt. Realistisch bauen Sie **drei bis vier** davon.

### Modul 1 — Nebelklimatologie (Kern, unverzichtbar)
Zeitreihenexplorer Puerto Ayora vs. Bellavista. Saisonale Klimatologie mit Garúa-Saison (Jun–Dez) hervorgehoben. Interaktiv wählbare **Nebelereignis-Definition** (Schwellen für RH, Taupunktdifferenz, Niederschlagsintensität) – der Nutzer verschiebt Regler und sieht sofort, wie stark die Ereigniszahl von der Definition abhängt. *Botschaft: Sie wissen, dass „Nebeltag" keine gegebene Größe ist, sondern eine methodische Entscheidung.*

### Modul 2 — Nebelausschlussexperiment: Design statt Daten
Kein Fake-Datensatz. Stattdessen ein **Power-Analyse-Werkzeug**: BACI-Design, n Plots × m Jahre, gemischtes Modell, Monte-Carlo-Simulation der Teststärke bei gegebener Effektgröße und Zwischen-Plot-Varianz. Der Nutzer sieht, wie viele Replikate für einen 20-%-Effekt nötig wären. *Botschaft: Sie können ein Feldexperiment mitplanen, nicht nur auswerten.* Das ist der Teil, der Sie von anderen Bewerbern unterscheidet.

### Modul 3 — Satellitenbasierte Nebeldetektion
GOES-BTD-Zeitschnitte über Santa Cruz, Vergleich mit Bodenfeuchte/RH aus Modul 1. Kontingenztafel (POD, FAR, Bias) für die Detektionsgüte. Bewusst mit sichtbaren Fehlklassifikationen – und einer Erklärung, woher sie kommen.

### Modul 4 — ML-Upscaling (der technische Höhepunkt)
Random Forest / Gradient Boosting: Prädiktoren aus DEM (Höhe, Exposition, TPI), GOES-BTD, ERA5-Inversionsstärke → Zielgröße Nebelwasser bzw. Nebelfrequenz.

**Entscheidend, und der Punkt, an dem Sie fachlich punkten:** räumliche Kreuzvalidierung statt zufälligem CV, plus **Area of Applicability** (R-Paket `CAST`). Räumliche Autokorrelation macht random-CV-Gütemaße bei Umweltdaten systematisch zu optimistisch; die AOA zeigt, wo die Vorhersagekarte überhaupt gültig ist. Die Karte bekommt also eine ausgegraute „hier nicht anwendbar"-Maske. Wer das zeigt, signalisiert, dass er die Fernerkundungs-ML-Literatur genau dieser Schule kennt – `CAST` stammt aus dem Marburger/Münsteraner Umfeld.

### Modul 5 — Datenqualität & Stationsbetrieb
Lückenkarte, Sensordrift, Plausibilitätsflags, Uptime pro Station. Unspektakulär, aber es adressiert direkt „Wartung und Betrieb der Feldinfrastruktur" und zeigt, dass Sie wissen, wie Felddaten wirklich aussehen.

### Modul 6 — Klimaszenario
Slider für ΔSST / ΔLTS → verschobene Wolkenuntergrenze, überlagert mit dem Höhenprofil von Santa Cruz und der Scalesia-Zone. Zeigt anschaulich, welcher Flächenanteil aus der Nebelzone fällt. **Explizit als illustratives Konzeptmodell kennzeichnen**, nicht als Projektion.

### Optional: TLS
Ein öffentlicher Beispiel-Punktwolkendatensatz (`lidR`-Beispieldaten), voxelbasierte LAD-Ableitung, Kopplung Kronenstruktur ↔ Interzeptionsfläche. Nur bauen, wenn Zeit übrig ist – TLS lässt sich in der Bewerbung auch durch eine Textpassage abdecken.

---

## 4. Technische Umsetzung: Empfehlung

> **Korrigiert am 2026-08-01.** Die ursprüngliche Fassung riet von shinyapps.io
> ab mit der Begründung, die kostenlose Instanz schlafe ein und der Link sei
> tot. Das stimmt nicht: Eine schlafende App wacht bei der nächsten Anfrage
> wieder auf, es kostet ein paar Sekunden Ladezeit. Das tatsächliche Limit
> sind **25 aktive Stunden pro Monat**; Leerlauf zählt mit, Schlafzeit nicht.
> Nach dem letzten Besucher läuft die Instanz noch 15 Minuten weiter (Default,
> auf 5 reduzierbar). Ein Besuch kostet also rund 20 Minuten Kontingent —
> für eine Bewerbung reicht das dreifach.

**Beide Wege sind vertretbar, sie lösen verschiedene Probleme.**

**Klassisches Shiny auf shinyapps.io** — für eine App, die *lebt*:

- Serverseitiges R, also beliebig grosse Daten, Live-Abrufe gegen ERA5/CDS,
  volle Paketauswahl.
- Idle-Timeout auf 5 Minuten stellen, dann ist das Kontingent unkritisch.
- Der Weg der Wahl, solange die App aktiv weiterentwickelt wird.

**Quarto-Dashboard + `shinylive-r` auf GitHub Pages** — für eine App, die
*archiviert* wird:

- Kompiliert Shiny nach WebAssembly, läuft vollständig im Browser, kein Server,
  kein Konto, kein Wartungsrisiko, permanent erreichbar.
- Preis dafür: keine Live-API-Abrufe (CORS), alle Daten müssen zum Client
  übertragen werden, und die Paketauswahl beschränkt sich auf das, was für
  webR kompiliert vorliegt. Für GOES-Raster oder `lidR` ist das nichts.
- Richtig für eingefrorene Datenstände — etwa das Cabo-Verde-Archiv.

Echte R-/Shiny-Kompetenz belegen beide Wege gleichermassen, weil der Code im
Repo lesbar bleibt. Das GitHub-Repo ist ohnehin Teil des Nachweises: `renv`
für Reproduzierbarkeit, `targets` für die Pipeline, sauberes README,
MIT-Lizenz.

Zusätzlich eine **statische PDF-/HTML-Zusammenfassung (2 Seiten)** als
Bewerbungsanlage, mit QR-Code/Link zur App. Nicht jeder Gutachter klickt.

**Paketstack:** `tidyverse`, `terra`/`sf`/`stars`, `ecmwfr`, `httr2`/`xml2`,
`tidymodels`/`ranger`, **`CAST`**, `leaflet`, `plotly`/`ggiraph`, `bslib`,
`targets`, `renv`.

> **Ebenfalls korrigiert:** Hier stand, ein Python-Anteil (`xarray`/`satpy`
> via `reticulate`) belege den „R und/oder Python"-Punkt der Ausschreibung.
> Das ist hinfällig — die Downloadpipeline ist inzwischen vollständig in R
> umgesetzt, GOES inklusive (`httr2` für das S3-Listing, `terra` für
> Projektion und Zuschnitt). Ein künstlich eingebauter Python-Anteil wäre
> Ballast. Die Ausschreibung verlangt „R **und/oder** Python".

---

## 5. Aufwandsstufen

| Stufe | Umfang | Aufwand |
|---|---|---|
| **Minimal** | Modul 1 + 5, nur CDF-Daten | 2–3 Tage |
| **Solide** ← empfohlen | + Modul 4 (ML mit DEM/ERA5) + Modul 2 | 1–1,5 Wochen |
| **Vollständig** | + GOES-BTD (Modul 3) + Szenario (6) | 3+ Wochen |

Die Stufe „Solide" hat das beste Verhältnis von Wirkung zu Aufwand: Modul 4 mit AOA ist das stärkste einzelne Signal, Modul 2 das originellste.

---

## 6. Rahmung in der Bewerbung

Ein Satz im Anschreiben, mehr nicht:

> „Um meine Arbeitsweise mit Klima- und Fernerkundungsdaten konkret zu machen, habe ich eine kleine methodische Machbarkeitsstudie zur Garúa-Klimatologie auf Basis öffentlich verfügbarer Daten (CDF DataZone, ERA5, GOES ABI) erstellt: [Link]. Sie ist bewusst als Methodendemonstration angelegt und nimmt keine Ergebnisse des Teilprojekts vorweg."

Und in der App eine sichtbare Kopfzeile mit Datenherkunft, Zitationshinweis für die CDF-Daten und dem Hinweis, dass es sich um eine unabhängige Vorstudie handelt.

---

## Quellen

- [When the Garúa Disappears – Research Unit GArua, Philipps-Universität Marburg](https://www.uni-marburg.de/en/prfolder-en/news/when-the-garua-disappears-a-new-research-unit-will-study-the-future-of-the-galapagos-cloud-forests)
- [DFG fördert fünf neue Forschungsgruppen](https://www.dfg.de/de/aktuelles/neuigkeiten-themen/pressemitteilungen/2026/pressemitteilung-nr-24)
- [CDF DataZone – Climatology Database](https://datazone.darwinfoundation.org/en/climate/bellavista)
- [History of the Meteorological Station at CDRS](https://www.darwinfoundation.org/en/news/all-news-stories/history-of-the-meteorological-station-at-the-charles-darwin-research-station/)
- [DARWIN-Projekt, WP1 Field observations (AWS-Netz Marburg)](https://vhrz669.hrz.uni-marburg.de/darwin/content_subprojects.do?phase=1&subpage=aims&subprojectid=1020)
- [„Harvesting Water" on Isabela Island, Galápagos – CDF](https://www.darwinfoundation.org/en/news/all-news-stories/update-report-year-one-harvesting-water-isabela-galapagos/)
- [Trial of fog and rainwater harvesting, Galapagos highlands (IWA)](https://iwaponline.com/washdev/article/15/1/1/106235/Trial-of-fog-and-rainwater-harvesting-to-alleviate)
- [Water security and agricultural systems in the Galapagos Islands (Frontiers in Water)](https://www.frontiersin.org/journals/water/articles/10.3389/frwa.2023.1245207/full)
- [GOES-R Fog Product Examples / Night Fog BTD (CIMSS)](https://fusedfog.ssec.wisc.edu/2019/12/17/ifr-probability-brightness-temperature-differences-and-nighttime-microphysics-rgb-estimates-of-fog/)
- [TLS to Predict Canopy Metrics, Water Storage Capacity and Throughfall (Remote Sensing)](https://www.mdpi.com/2072-4292/10/12/1958)
