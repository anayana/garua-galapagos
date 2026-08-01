# Konzept v2: Wald-App „Garúa & Scalesia" — Galápagos

### Bewerbungsbeilage FOR 5621 GArua, Teilprojekt A1 (Uni Marburg)

*Ersetzt die Modulplanung aus `Konzept_GArua_A1_App.md` (v1). Rahmung, Datenquellen-
Grundlage und Deployment-Empfehlung aus v1 bleiben gültig; neu sind die Architektur-
entscheidung („saubere Wald-App"), die geprüfte Datenlage und die Wiederverwertung
bestehender eigener Projekte.*

---

## 1. Die Entscheidung in einem Satz

Aus sechs geplanten Modulen plus Ozean- und TLS-Ideen wird **eine Wald-App mit drei
Daten-Panes und einer Methodik-Pane**. Ozean, Satellitendetektion und Datenqualität
bleiben erhalten — aber als *Eingangsgrößen und Kovariaten*, nicht als eigene
Oberflächenbereiche. Alles, wofür es keine Galápagos-Daten gibt, wandert in die
Methodik-Pane und wird dort ehrlich als Vorhaben statt als Ergebnis gekennzeichnet.

Der Leitsatz: **Nichts in der App, was nicht auf realen Galápagos-Daten steht — außer
in Pane 4, wo genau das draufsteht.**

---

## 2. Architektur

### Pane 1 — Nebelklimatologie

Der Kern aus v1 — aber mit einer anderen Botschaft, als v1 vorgesehen hatte.

- Zeitreihenexplorer **Puerto Ayora** (2 m, 1964–2026) ↔ **Bellavista** (223 m, 1987–2019)
- Saisonale Klimatologie mit hervorgehobener Garúa-Saison (Jun–Dez)
- **Interaktiv wählbare Nebelereignis-Definition** — der Nutzer verschiebt Regler und
  sieht, wie stark die Ereigniszahl von der Definition abhängt

#### Die Definition — und der Regler, der keiner war

Der erste Entwurf hatte `rh_min` und `dpd_max` als zwei Achsen. Es war eine:
Korrelation **−0,998**, denn die Taupunktdifferenz wird über Magnus *aus* der
relativen Feuchte berechnet. Sichtbar wurde es daran, dass bei `dpd_max = 0,5 K`
alle RH-Schwellen von 85 bis 97 % dieselbe Ereigniszahl lieferten.

Die tragfähige Definition kombiniert drei **unabhängige** Größen — Sättigungsnähe,
Bedeckungsgrad und ein Niederschlags*fenster* (Garúa ist Niesel: messbar, aber gering):

| Definition | Bellavista | Puerto Ayora | Kontrast | Saisonfaktor |
|---|---:|---:|---:|---:|
| DPD ≤ 1,5 + P ≤ 5 (erster Entwurf) | 42,2 % | 24,2 % | 1,75 | ×1,65 |
| **DPD ≤ 1,5 + clouds ≥ 7/8 + P 0,1–5 mm** | **21,8 %** | **7,3 %** | **2,99** | **×3,66** |

Der vertikale Feuchtegradient Küste → Hochland *ist* die Kernaussage des Projekts.
Eine Definition, die ihn auf Faktor 1,75 zusammendrückt, ist die schlechtere.
Monatsklimatologie Bellavista mit der besseren Definition: **August 40,9 %,
März 3,3 %** — ein Lehrbuch-Garúa-Signal.

#### Der Befund, der Pane 1 neu ausrichtet: die Reihen sind nicht homogen

Bruchpunktanalyse auf saisonbereinigten Monatsanomalien (362 gemeinsame Monate,
Pettitt + SNHT + binäre Segmentierung, `analysis/03_homogeneity.R`).

Ein Bruch in der **Differenzreihe** Bellavista − Puerto Ayora kann kein Klima sein:
das gemeinsame Regionalsignal kürzt sich dort weg. Was bleibt, ist Stationseffekt.

| Bruch | Sprung | T0 | zuzuordnen |
|---|---:|---:|---|
| 2015-10 | **−15,0 Pp** | 15,1 | dokumentierte Verlegung Bellavista |
| 2001-08 | +10,4 Pp | 15,6 | Puerto Ayora (Gegenstück zu 2002-03) |
| 2004-09 | −9,0 Pp | 24,5 | Bellavista (auch in der Einzelreihe, −13,3 Pp) |
| 1993-05 | −8,9 Pp | 16,9 | Puerto Ayora (Gegenstück zu 1992-07, T0 = 109) |
| 2011-08 | +8,7 Pp | 19,9 | Bellavista (Einzelreihe 2012-03, +11,2 Pp) |
| 2007-11 | +7,8 Pp | 11,4 | Bellavista (Einzelreihe 2008-10, +11,5 Pp) |

**Die Summe der Sprungbeträge ist 60 Prozentpunkte. Der mittlere Nebelanteil an
Bellavista ist 22 %.** Die aufsummierten Stationsartefakte sind größer als die
gemessene Größe selbst.

Drei Einzelbefunde, die daraus folgen:

- **Die Betreiberwarnung stimmt — trifft aber nur ein Sechstel des Problems.**
  Die Verlegung Ende 2015 ist der größte Einzelsprung, aber einer von sechs. Und
  statistisch der schwächste: nur 31 bzw. 42 Monate links und rechts.
- **1999-07 erscheint in *beiden* Einzelreihen, im selben Monat** (+12,7 Pp Bellavista,
  +8,4 Pp Puerto Ayora) — und deshalb *nicht* in der Differenz. Zwei Stationen 20 km
  auseinander brechen nicht zufällig im gleichen Monat. Das ist eine **netzweite
  Praxisänderung**, kein lokales Ereignis.
- **Der wahrscheinliche Mechanismus:** Der Bedeckungsgrad ist eine *Beobachter­schätzung*
  in Achteln. Ein Personalwechsel an der Station verschiebt die Statistik sofort — ohne
  dass ein Gerät ausgetauscht wurde. Das erklärt Sprünge dieser Größenordnung besser als
  jede Sensordrift.

> **Die Botschaft von Pane 1 lautet damit nicht mehr „so hat sich der Nebel entwickelt",
> sondern: Aus diesen Daten lässt sich kein Trend ableiten — und hier ist der Nachweis.**
> Klimatologie ja, Trend nein.

Für eine Stelle, zu der „Wartung und Betrieb der Feldinfrastruktur" gehört, ist das
das stärkere Signal. Eine Trendkurve kann jeder zeichnen; zu erkennen, dass die Reihe
sie nicht hergibt, ist die eigentliche Qualifikation.

**Methodischer Vorbehalt, der mit ausgewiesen wird:** Die Segmentierung testet rekursiv
ohne Korrektur für Mehrfachtestung, die SNHT-Schwellen gelten für einen Einzeltest.
Die Zahl der Brüche ist eher zu hoch. Deshalb wird zu jedem die Sprunghöhe ausgewiesen —
alle sechs liegen über 5 Prozentpunkten, und *das* ist das Auswahlkriterium, nicht das
Signifikanzsternchen.

#### Was dabei zerbrochen ist: die ENSO-Kopplung

v1 hielt fest, Garúa und El Niño seien antikorreliert und ein ONI-Plot sei „fachlich
sofort einleuchtend". In diesem Proxy ist er das nicht:

- Bellavista, Nebelanteil ~ ONI (Garúa-Saison): **+0,046** — praktisch null
- Puerto Ayora: **−0,344** — schwach, immerhin richtiges Vorzeichen

Angesichts der sechs Brüche ist das nicht überraschend: Stationsartefakte von 8–15 Pp
überdecken jedes ENSO-Signal. Die Kopplung wird deshalb **erst nach Homogenisierung**
geprüft und bis dahin nicht behauptet.

**Ozean bleibt Kovariate, nicht Pane:** ONI und SST-Anomalie als Overlay auf der
Nebelreihe. Zusätzlich verfügbar und bisher übersehen: Puerto Ayora führt eine
**In-situ-Wassertemperatur seit 1964 bei 98,8 % Abdeckung** — für die
Ozean-Kopplung wertvoller als jede Reanalyse, weil unabhängig gemessen.

**Datenqualität als Streifen, nicht als Pane:** unter der Zeitreihe eine schmale Leiste
mit Lücken, Uptime und den sechs Bruchmarken. Adressiert den Ausschreibungspunkt
„Wartung und Betrieb der Feldinfrastruktur" direkt.

---

### Pane 2 — Der Wald

Neu, und der Grund, warum das Ganze eine **Wald**-App ist.

**Datengrundlage:** `A_ECOSISTEMAS_NATIVOS_2016` (siehe §3), verschnitten mit dem
Höhenband aus Copernicus GLO-30 und dem Nebelgürtel aus Pane 1. Der Datensatz liegt
seit dem 2026-08-01 lokal vor: 1437 Polygone, 14 Klassen — nach geometrischer Korrektur
1219 Polygone und 100.695 ha auf Santa Cruz + Baltra (siehe Datenqualität unten).

**Kernabbildung:** Höhenprofil Santa Cruz mit drei übereinandergelegten Bändern —
humide Evergreen-Zone (Vegetationskarte), Nebelzone (Pane 1, Nebelhäufigkeit über
Höhe), Invasiven-Zone (Vegetationskarte). Daraus die Zahl, um die es geht: **welcher
Flächenanteil liegt derzeit im Nebelgürtel.**

#### Erste Korrektur nach dem Blick in die Daten

Die Klasse *Evergreen Forest and Shrubland* umfasst auf Santa Cruz **rund 4.700 ha**.
Die Literatur beziffert den verbliebenen Scalesia-Wald auf **~300 ha**, etwa 3 % der
historischen Ausdehnung. Das ist Faktor 15 auseinander.

Die Klasse ist also **nicht** der Scalesia-Restbestand, sondern die humide
Immergrün-Zone insgesamt — die potenzielle Standortzone. v1 und der erste Entwurf von
v2 haben das gleichgesetzt; das war falsch.

Das ist die bessere Geschichte, nicht die schlechtere: Pane 2 kann **potenzielle Zone
gegen tatsächlichen Restbestand** stellen. Die Lücke zwischen 4.700 ha geeignetem
Standort und ~300 ha verbliebenem Wald ist genau das Bild, das den Zustand des Systems
erklärt — und *Invasive Species* liegt mit rund 2.760 ha in derselben Größenordnung
wie die humide Zone selbst.

**Ankerzahlen aus der Literatur (zitiert, nicht gerechnet):**

| Größe | Wert |
|---|---|
| Verbliebene Scalesia-Fläche Santa Cruz | ~3 % der historischen Ausdehnung, ~300 ha |
| Bestand Los Gemelos | ~140 ha |
| Prognose unter Brombeer-Druck (*Rubus niveus*) | Quasi-Extinktion in ~20 Jahren |

#### Datenqualität: der Fehler lag im Attribut, nicht in der Geometrie

Ein erster Befund lautete, die Klassen überlappten sich: Summe aller Geometrieflächen
141.836 ha bei einer Insel von rund 100.700 ha. **Das war die falsche Diagnose.**
Die Nachprüfung ergibt:

**1. Der Attributfilter `Isla` ist unbrauchbar.** Alle 1437 Polygone tragen den Wert
`Santa Cruz` — die Geometrien spannen aber −91,36 bis −89,25 ° Länge und −1,00 bis
+0,59 ° Breite, also den halben Archipel. 225 Polygone mit zusammen 44.128 ha liegen
außerhalb Santa Cruz'. Das größte angeblich-Santa-Cruz-Polygon ist ein
*Deciduous Forest* mit 57.119 ha; die Insel selbst misst nur ~98.600 ha.

**2. Nach geometrischem Clip stimmt alles.** Bounding-Box-Clip auf Santa Cruz + Baltra
statt Attributfilter:

- **Gesamtfläche 100.695 ha** — Santa Cruz mit Baltra misst ~100.700 ha
- **Überlappung exakt null.** Summe der Einzelpolygone = Union, klassenintern wie
  klassenübergreifend. *Evergreen Forest and Shrubland* × *Invasive Species* = 0,0 ha

Die Karte ist also eine saubere, überschneidungsfreie Aufteilung. Es braucht **keine**
Prioritätsregel und kein `st_intersection`.

**3. `Area_Ha` bleibt unzuverlässig** — ein *Agricultural-Lands*-Polygon führt 0,65 ha
im Attribut und misst 8.342 ha. Regel: **Flächen aus der Geometrie rechnen, das Attribut
ignorieren.** Dass die Attributsumme zufällig nahe der Inselfläche lag, war Koinzidenz
und kein Hinweis auf eine frühere Fassung.

**Konsequenz für `06_download_vegetation.R`:** Der Clip muss geometrisch erfolgen —
`st_intersection` mit der Insel-Bounding-Box bzw. besser mit einem Küstenlinienpolygon,
nicht `filter(Isla == "Santa Cruz")`. Solange das nicht umgestellt ist, sind alle
Flächenzahlen um bis zu 44 % zu hoch.

> Nach Regel 3 der Ehrlichkeitsregeln (§8) gehört dieser Ablauf — falsche Diagnose,
> Nachprüfung, Korrektur — sichtbar in die App. Ein Gutachter erkennt daran mehr
> Sorgfalt als an einer Zahl, die von Anfang an gestimmt hat.

#### Flächenbilanz Santa Cruz + Baltra (geometrisch geclippt)

| Klasse | ha | Polygone | Zentroidhöhe min / median / max |
|---|---:|---:|---|
| Deciduous Forest | 57.567 | 149 | −1 / 23 / 604 m |
| Evergreen Seasonal Forest | 11.541 | 158 | 1 / 74 / 633 m |
| Agricultural Lands | 11.347 | 1 | 392 m |
| Deciduous Shrubland | 8.595 | 147 | — |
| **Evergreen Forest and Shrubland** | **4.716** | **163** | **51 / 197 / 837 m** |
| Deciduous tallgrass | 3.015 | 235 | — |
| **Invasive Species** | **2.755** | **186** | **122 / 560 / 772 m** |
| Coastal Humid Forest and Shrubland | 444 | 113 | — |
| Old Lava | 232 | 117 | — |
| Urban Settings | 210 | 24 | — |
| Humid Tallgrass | 119 | 41 | 637 / 679 / 821 m |
| Mangroves | 114 | 55 | — |
| Water Bodies | 20 | 13 | — |
| Recent Lava | 19 | 17 | — |
| **Summe** | **100.695** | **1.219** | |

Die Kernzahl aus dem Abschnitt oben ändert sich durch die Korrektur kaum
(4.720 → 4.716 ha) — die Argumentation *potenzielle Zone vs. Restbestand* steht.

#### Die eigentliche Entdeckung: der Wald ist in zwei Fragmente zerschnitten

Zonale Statistik, rasterbasiert (DEM × Vegetation auf dem GLO-30-Gitter,
`analysis/01_zonal_vegetation_dem.R`). Alle Werte in ha:

| Höhenband | Evergreen Forest & Shrubland | Invasive Species | Agricultural Lands | Humid Tallgrass |
|---|---:|---:|---:|---:|
| 0–100 m | 428 | 0 | 0 | 0 |
| **100–200 m** | **1.531** | 877 | 1.794 | 0 |
| 200–300 m | 177 | 596 | **3.336** | 0 |
| 300–400 m | 172 | 100 | **2.779** | 0 |
| 400–500 m | 136 | 35 | **2.395** | 0 |
| 500–600 m | 838 | 259 | 984 | 0 |
| **600–700 m** | **1.238** | 701 | 41 | 68 |
| 700–900 m | 184 | 196 | 0 | 48 |
| **Summe** | **4.704** | **2.764** | **11.329** | **116** |

> **Kreuzvalidierung:** Dieselbe Rechnung wurde unabhängig in Python
> (`geopandas` + `rasterio`, Rasterisierung auf dasselbe DEM-Gitter) durchgeführt.
> Abweichung je Zelle unter 1 % — z. B. Evergreen 100–200 m: 1.531 ha (R) vs.
> 1.527 ha (Python), 600–700 m: 1.238 vs. 1.232. Zwei getrennte Implementierungen
> mit demselben Ergebnis. Kontrollsumme: zonal 100.437 ha gegen vektoriell
> 100.695 ha, 0,26 % Abweichung durch Rasterisierung schmaler Polygone.

Die humide Immergrün-Zone besteht aus **zwei getrennten Fragmenten**: eines bei
100–200 m (1.531 ha) — genau auf Höhe der Station Bellavista (223 m) — und eines bei
500–700 m (2.076 ha). Dazwischen, in 200–500 m, liegen zusammen nur 485 ha.

**In dieser Lücke liegt die Landwirtschaft.** Von 11.329 ha *Agricultural Lands*
entfallen 8.510 ha auf genau die Bänder 200–500 m, in denen der Wald fehlt. Das ist
die zentrale Grafik für Pane 2:

> Der Nebelgürtel ist nicht durchgängig bewaldet, sondern in einen unteren und einen
> oberen Rest zerschnitten — und die Landwirtschaftszone sitzt exakt im Bruch.

Die Invasiven folgen nicht den Rändern, sondern liegen **direkt auf beiden
Fragmenten**: 877 ha im unteren (100–200 m), 701 ha im oberen (600–700 m). Beide
verbliebenen Waldreste sind also aktiv unter Invasionsdruck, nicht nur randlich
bedroht.

Die Gipfelfrage aus dem ersten Entwurf hat sich weitgehend erledigt: oberhalb 700 m
liegen nur noch 184 ha Evergreen, daneben 116 ha *Humid Tallgrass*. Die Gipfelzone ist
zu klein, um die Aussage zu tragen oder zu gefährden.

#### Warum diese Tabelle die zweite Korrektur ist

Eine erste Fassung hatte die Höhenbänder **zentroidbasiert** gerechnet — je Polygon
den Schwerpunkt nehmen, dort die DEM-Höhe abfragen, die ganze Fläche diesem Band
zuschlagen. Das Ergebnis war grob falsch:

| Höhenband | Zentroid-Näherung | zonal (korrekt) |
|---|---:|---:|
| 100–200 m | 1.936 | 1.531 |
| 200–300 m | 82 | 177 |
| 500–600 m | 161 | 838 |
| 600–700 m | 37 | 1.238 |
| **700–900 m** | **2.305** | **184** |

Die Näherung verlegt 2.305 ha in die Gipfellage, wo tatsächlich 184 ha liegen, und
übersieht den zweiten Schwerpunkt bei 600–700 m fast vollständig. Ein Polygon, das von
550 bis 850 m reicht, hat seinen Zentroid bei ~700 m und wird komplett dorthin gebucht.

**Ein Polygon ist keine Punktmessung.** Die Herleitung steht im Kopf von
`analysis/01_zonal_vegetation_dem.R`, damit die Abkürzung nicht doch wieder genommen
wird — und sie gehört als Beispiel in Pane 4, weil sie zeigt, wie eine plausibel
aussehende Zahl entsteht, die niemand nachrechnet.

#### Das Ehrlichkeitsargument, das diese Pane trägt

Die **akute** Bedrohung von *Scalesia pedunculata* ist heute die **Invasion**, nicht
der Nebelverlust: *Rubus niveus*, *Cestrum auriculatum*, *Tradescantia fluminensis*.
Natürliche Verjüngung wurde nur auf invasivenfreien Flächen beobachtet. Der
Nebelrückgang ist der langsamere, zweite Stressor.

Das gehört sichtbar in die App. Wer es übergeht, produziert genau den Eindruck, dem
Gutachter am misstrauischsten gegenüberstehen: dass eine Klimageschichte auf ein
Invasionsproblem montiert wird. Wer es benennt und die Invasivenklasse mitkartiert,
zeigt Kenntnis des Systems — und positioniert die Nebelfrage korrekt als
*Langfristrisiko auf einem bereits geschwächten Restbestand*.

---

### Pane 3 — Kopplung & Upscaling

Der technische Höhepunkt. Schluckt das frühere Satellitenmodul.

**Modell:** Random Forest / Gradient Boosting
**Prädiktoren:**

- DEM-abgeleitet: Höhe, Hangneigung, Exposition zum SE-Passat, TPI (GLO-30)
- **GOES-BTD** (T₁₀,₃ − T₃,₉) als Prädiktorlayer — *nicht* als eigene Pane mit
  Kontingenztafel-UI, sondern als Spalte in der Modellmatrix
- ERA5: Inversionsstärke (LTS/EIS), 700-hPa-Temperatur, Grenzschichthöhe, LCL
- SST-Anomalie / ONI (aus der Ozean-Pipeline)

**Zielgröße:** Nebelhäufigkeit bzw. Nebelwasserproxy

**Der Punkt, an dem fachlich gepunktet wird:** **räumliche Kreuzvalidierung** statt
zufälligem CV, plus **Area of Applicability** (`CAST`). Räumliche Autokorrelation macht
random-CV-Gütemaße bei Umweltdaten systematisch zu optimistisch; die AOA zeigt, wo die
Vorhersagekarte überhaupt gültig ist. Die Karte bekommt eine ausgegraute
„hier nicht anwendbar"-Maske.

**Der Verschnitt, der Pane 2 und 3 verbindet:** Vorhersagekarte × Scalesia-Polygon ×
AOA-Maske → *welcher Anteil des Restbestands liegt im verlässlich vorhergesagten
Nebelbereich, und wie verschiebt sich das bei angehobener Wolkenuntergrenze.* Das ist
die eine Aussage, auf die die ganze App hinausläuft.

---

### Pane 4 — Methodik

Explizit und sichtbar als *„so würde ich messen und prüfen"* gerahmt, sauber getrennt
von Pane 1–3. Diese Trennung ist selbst das Glaubwürdigkeitssignal.

**4a — Nebelausschlussexperiment: Design statt Daten.**
Kein Fake-Datensatz. Stattdessen ein Power-Analyse-Werkzeug: BACI-Design, *n* Plots ×
*m* Jahre, gemischtes Modell, Monte-Carlo-Simulation der Teststärke bei gegebener
Effektgröße und Zwischen-Plot-Varianz. Der Nutzer sieht, wie viele Replikate für einen
20-%-Effekt nötig wären.
*Botschaft: Feldexperimente mitplanen, nicht nur auswerten.* Das ist der originellste
Teil der ganzen App.

**4b — Bestandesstruktur: warum die Fernerkundung hier an eine Grenze stößt.**
Kurzer, präziser Abschnitt (Text + eine Schemagrafik, keine geliehenen Punktwolken):

- Weltraumgestütztes Lidar (GEDI, ICESat-2) kann die Frage prinzipiell nicht
  beantworten — Lidar durchdringt keine Wolken, und die Scalesia-Zone liegt Jun–Dez
  unter quasi-permanentem Stratus. **Das untersuchte Phänomen zensiert den Sensor.**
  Die verbleibenden Footprints sind systematisch auf die wolkenfreie Trockenzeit
  verschoben — also auf genau die Bedingungen, die *nicht* Garúa sind.
- Was eine terrestrische Kampagne liefern würde: Blattflächendichteprofil, Gap
  Fraction, Kronenprojektionsfläche → **Interzeptionsfläche → Nebelwasserertrag**.
  Diese Kette ist der eigentliche Grund, warum Struktur für A1 relevant ist.
- Ehrliche Konsequenz: Struktur ist in dieser App eine *Lücke mit Begründung*, kein
  Modul. Das zu sagen ist stärker, als sie mit fremden Daten zu füllen.

---

## 3. Datenquellen mit Zugriffspfaden

### Neu zu ergänzen

| Quelle | Zugriff | Login |
|---|---|---|
| **Vegetationskarte Galápagos v.2016** — `A_ECOSISTEMAS_NATIVOS_2016`, USFQ Instituto de Geografía | ArcGIS FeatureServer, öffentlich:<br>`https://services5.arcgis.com/qefe3CGaSKnteGG1/arcgis/rest/services/A_ECOSISTEMAS_NATIVOS_2016/FeatureServer/0/query?where=1%3D1&outFields=*&f=geojson`<br>direkt per `sf::st_read()` | nein |

**Geprüft am 2026-08-01** (FeatureServer-Metadaten und Statistikabfragen):

- **20.106 Polygone**, Geometrie in EPSG:3857, Felder `FID`, `OBJECTID`,
  `Ecosis_Nat`, `Isla`, `Shape_Leng`, `Shape_Area`, `Area_Ha`
- **15 Klassen, nicht 10.** Vollständig: *Agricultural Lands*, *Coastal Humid Forest
  and Shrubland*, *Deciduous Forest*, *Deciduous Shrubland*, *Deciduous tallgrass*,
  ***Evergreen Forest and Shrubland***, *Evergreen Seasonal Forest*, *Highland
  Deciduous tallgrass*, *Humid Tallgrass*, ***Invasive Species***, *Mangroves*,
  *Old Lava*, *Recent Lava*, *Urban Settings*, *Water Bodies*
- Auflösung 30 m, Maßstab 1:60.000, Landsat-8/OLI, Bezugsjahr 2016
  (Item-Metadaten nennen 2018)

Die zusätzlichen Klassen sind kein Beiwerk. *Old Lava* und *Recent Lava* zeigen, wogegen
die Scalesia-Zone abgegrenzt ist, und ***Agricultural Lands*** ist im Hochland genau der
zweite Nutzungsdruck neben den Invasiven — beides gehört in das Höhenprofil von Pane 2.

Das Feld `Isla` ist sauber gepflegt (15 Inseln, u. a. `Santa Cruz`). Ein
Attributfilter `where=Isla='Santa Cruz'` ist damit bequemer und exakter als ein
Bbox-Clip.

> ⚠️ **Die Falle in Schritt 1 der Nächsten Schritte.** Der Dienst hat
> `maxRecordCount = 2000` bei 20.106 Features. Ein nacktes `sf::st_read()` auf die
> Query-URL liefert **stillschweigend die ersten 2000 Polygone** — ohne Fehler, ohne
> Warnung. Eine Flächenbilanz darauf wäre stumm falsch, und zwar so, dass es niemandem
> auffällt. Nötig ist eine `resultOffset`-Schleife mit anschliessendem Abgleich gegen
> `returnCountOnly`. Genau das tut `06_download_vegetation.R`; es bricht ab, wenn die
> Zahlen nicht übereinstimmen.

**Grenze, die in der App stehen muss:** Bei 30 m und 1:60.000 ist Los Gemelos (~140 ha)
etwa 15 Pixel breit. Tauglich für Zonen- und Flächenanteilsaussagen, **nicht** für
Bestandes- oder Einzelbaumebene. Die auf der USFQ-Projektseite genannte
E-Mail-Anfrage an das Institut ist für den öffentlichen FeatureServer nicht nötig,
für die vollständigen Shapefiles (inkl. Invasiven-Einheiten in Originalauflösung) aber
weiterhin der saubere Weg — und ein guter Anlass für Kontaktaufnahme.

### Bereits in `config.yml` und `download/` vorhanden

| Quelle | Skript | Status |
|---|---|---|
| CDF-Stationsdaten (Puerto Ayora, Bellavista) | `01_download_cdf_stations.R` | ✓ |
| ONI / ENSO (NOAA CPC/PSL) | `02_download_enso.R` | ✓ |
| Copernicus DEM GLO-30 | `03_download_dem.R` | ✓ |
| ERA5 single + pressure levels | `04_download_era5.R` | ✓ |
| GOES ABI C07/C13 (AWS Open Data) | `05_download_goes.R` | ✓ |

| Vegetationskarte (USFQ FeatureServer) | `06_download_vegetation.R` | ✓ |

`config.yml` hat einen `vegetation:`-Block analog zu `dem:` — Dienst-URL, Seitengröße,
Inselfilter, die 15 Klassen und die drei Fokusklassen (Scalesia / Invasive /
Agricultural). Das Skript paginiert, prüft die Vollständigkeit, schreibt ein GeoPackage
und stellt die mitgelieferte `Area_Ha` der aus der Geometrie neu gerechneten Fläche
gegenüber — weichen sie um mehr als 5 % ab, gibt es eine Warnung.

### Lizenzhinweise, die in die App gehören

- CDF-Klimadaten: **CC BY-NC-SA 4.0** — Namensnennung Pflicht, keine kommerzielle
  Nutzung. Zitationsstring steht bereits in `config.yml`.
- Vegetationskarte: Quelle *Instituto de Geografía – Universidad San Francisco de
  Quito*, Item als „Available for download" gekennzeichnet.

---

## 4. Recycling-Matrix

### 4.1 Ozean-App (`D:\R\Ozean`)

Deutlich mehr wert als die Portfolio-Seite vermuten ließ. `nrt/` enthält eine
vollständige Near-Real-Time-Pipeline: CMEMS SST + Chlorophyll, ERA5-Wind,
OISST-Baseline 1993–2022 (liegt lokal), Argo-Validierung mit Bias/RMSE/Korrelation,
MHW nach Hobday et al. (2016), täglich per GitHub Actions. Das README sagt wörtlich:
*„Region wechseln: nur config.yml anpassen."*

| Bestandteil | Verwendung |
|---|---|
| `nrt/`-Pipeline, Region-Umschaltung per bbox | **Direkt.** Galápagos-Werte stehen bereits in der Galapagos-`config.yml` |
| SST-Anomalie, ONI-Kopplung | **Direkt** als Kovariate in Pane 1 und Prädiktor in Pane 3 |
| MHW-Metriken, Fronten, Chlorophyll, Zonenvergleich | **Nicht** — gehört nicht in eine Wald-App |
| Argo-Validierung, Skill-Metriken | **Als Muster** für den Datenqualitätsstreifen in Pane 1 |
| 7 Dashboard-Panes aus `CVoceanTwin.R` | **Nicht übernehmen** |

**Architekturentscheidung: nicht forken.** Die Ocean-Pipeline bleibt ihr eigenes Repo
— regionsagnostisch zu sein *ist* ihr Verkaufsargument. Die Wald-App konsumiert deren
Output als Datenlayer. Zwei Region-Profile in einem Codebase ist auch die bessere
Portfolio-Geschichte als zwei getrennte Apps.

**Archivierung Cabo Verde:**

1. Git-Tag `v1.0` mit Cabo-Verde-Config, `CITATION.cff` ergänzen
2. `.rds`/`.nc`-Snapshots einfrieren (Datenstand fixieren statt Live-API)
3. shinylive-Export → GitHub Pages
4. `PersPage/projects/cv-ocean-twin/index.qmd`: iframe auf den statischen Build
   umhängen, Badge „Archived / v1.0"
5. shinyapps.io abschalten

*Begründung (korrigiert am 2026-08-01):* Nicht, weil die freie Instanz „einschläft" —
eine schlafende App wacht bei der nächsten Anfrage auf, das kostet Sekunden. Das echte
Limit sind 25 aktive Stunden pro Monat, und die reichen für Portfolio-Traffic locker.
Der Grund ist ein anderer und für ein **Archiv** der bessere: Ein eingefrorener
Datenstand braucht keinen Server. shinylive kostet nichts, läuft ohne Konto, ohne
Kontingent und ohne Wartung — und genau deshalb überlebt es einen Kontowechsel oder
eine Preisänderung bei Posit. Für die **aktive** Galápagos-App bleibt klassisches
Shiny die richtige Wahl (siehe §6).

### 4.2 `3p_climana`

Ehrliche Bilanz: **etwa 20 % verwertbar — aber es sind die guten 20 %.** Der ODT ist
überwiegend Skizzencode mit hartkodierten `data.frame`s.

| Bestandteil | Verwendung |
|---|---|
| **Backtesting-Logik** aus `climpath_backtesting.R` (Kalibrierung 1951–80 → Validierung 1991–2020) | **Übernehmen.** Derselbe intellektuelle Zug wie räumliche CV + AOA in Pane 3: Gütemaß gegen die naive Version halten |
| `compute_climatology()`, ERA5/terra-Plumbing, 30-Jahres-Normale je Rasterzelle | **Übernehmen.** ~100 Zeilen, gleiche Variablen wie in der Galapagos-`config.yml` |
| Analogklima-Konzept (geografisch) | **Nicht.** Analoga brauchen einen großen Suchraum; Galápagos ist ein kleiner Archipel |
| — Reframe, falls gewünscht | Space-for-Time **vertikal**: Puerto Ayora (2 m) → Bellavista (223 m) → Cerro Crocker (~860 m). Der relevante Gradient ist die Höhe, nicht die Geografie |
| Bewirtschaftungsformen, MCA, Transformationspfade | **Nicht.** Agroforst für Brandenburger Landwirte hat keine Brücke zu einem Nationalpark, wo die Managementfrage Neophytenbekämpfung heißt |

### 4.3 `360Pano3D`

| Bestandteil | Verwendung |
|---|---|
| Methodenkette Punktwolke → LAD → Gap Fraction → **Interzeptionsfläche → Nebelwasser** | **Als Text + Schemagrafik in Pane 4b** |
| `canopy_lai.py/.R`, `hemi_from_pano.py`, `occlusion_map.py` | **Nicht ausführen** — keine Galápagos-Daten, keine Fisheye-Messungen |
| Renon-/Hechingen-Szenen, Pannellum-Viewer, 3D Gaussian Splatting | **Nicht.** Entscheidung: keine 3D-Visualisierung, keine geliehenen Szenen |
| Ehrlichkeitsprinzipien aus `EXPOSE.md` (Provenienz-Trennung, Kreuzvalidierung, Machbarkeitsstufen ✓/~/✗) | **Als Haltung übernehmen** — passt auf die Datenherkunftskennzeichnung der ganzen App |

---

## 5. Geprüfte Befunde

Drei Vorabklärungen, die die Architektur bestimmt haben. Sie gehören in Kurzform auch
in die App, weil sie Kompetenz zeigen.

### 5.1 GEDI — geprüft, verworfen

`GEDI02_A`-Granules schneiden die Santa-Cruz-Box (CMR-Abfrage, frühester Treffer
2019-05-21). Orbits kommen also vorbei. **Trotzdem keine Grundlage für ein
Strukturmodul:**

1. Granule-Polygone sind ganze Orbit-Segmente — Schnitt ≠ Beam-Treffer. Die belastbare
   Footprint-Zahl erfordert Earthdata-Login und das Öffnen der HDF5-Beams
   (`rGEDI` / `gedi_subset`). *Offener Punkt, ~20 min.*
2. **Datenlücke 17.03.2023 – 24.04.2024** — Instrument von der ISS abgebaut und
   eingelagert, null Daten. Nominaler Wissenschaftsbetrieb erst wieder ab 11.06.2024.
3. Geometrie: 8 Beams, 25-m-Footprints alle 60 m längs, ~600 m quer, ~4,2 km
   Streifenbreite. Stichprobe, keine Flächendeckung — Trackdichte ist am Äquator am
   niedrigsten (ISS-Bahnneigung 51,6°).
4. **Entscheidend:** Lidar durchdringt keine Wolken. Siehe Pane 4b.

### 5.2 TLS / Fisheye — es gibt nichts

- **Keine öffentliche TLS-Punktwolke der Galápagos-Vegetation.**
- OpenTopography hat Galápagos-Daten, aber Sierra Negra (Lavaströme, Eruption 2018) —
  Geologie, keine Kronen.
- **Keine Fisheye-/hemisphärischen Messungen** für die Scalesia-Zone.

→ Methodik-Transfer statt Datentransfer (Pane 4b). Keine Ersatzdatensätze.

### 5.3 Vegetationskarte — verfügbar

Siehe §3. Der Fund, der Pane 2 überhaupt möglich macht.

---

## 6. Technische Umsetzung

*Gegenüber v1 präzisiert am 2026-08-01: Deployment und Sprachwahl.*

**Klassisches Shiny auf shinyapps.io**, Idle-Timeout auf 5 Minuten. Die App lebt: Sie
soll weiterentwickelt werden, GOES-Raster verarbeiten und gegen ERA5 nachladen können.
Genau das kann shinylive nicht — im Browser gibt es keine Live-API-Abrufe (CORS), alle
Daten müssten zum Client übertragen werden, und die Paketauswahl beschränkt sich auf
das für webR Kompilierte.

shinylive bleibt richtig für **Archive** mit eingefrorenem Datenstand — also für die
Cabo-Verde-App (§4.1), nicht für diese hier.

**Repo als Teil des Nachweises:** `renv` für Reproduzierbarkeit, `targets` für die
Pipeline, sauberes README, MIT-Lizenz, sichtbare Datenherkunftskennzeichnung.

**Paketstack:** `tidyverse`, `terra`/`sf`/`stars`, `ecmwfr`, `httr2`/`xml2`,
`tidymodels`/`ranger`, **`CAST`**, `leaflet`, `plotly`/`ggiraph`, `bslib`, `targets`,
`renv`.

> **Sprachwahl korrigiert.** Hier stand, ein Python-Anteil (`xarray`/`satpy` für GOES
> via `reticulate`) belege den „R und/oder Python"-Punkt. Das ist hinfällig: Die
> Downloadpipeline `01`–`06` ist vollständig in R, GOES inklusive — `httr2` für das
> S3-Listing über die öffentliche REST-Schnittstelle, `terra` für Projektion und
> Zuschnitt. Ein nachträglich eingebauter Python-Anteil wäre Ballast in einem sonst
> konsistenten Repo. Die Ausschreibung verlangt „R **und/oder** Python".

Zusätzlich eine **statische 2-Seiten-Zusammenfassung (PDF/HTML)** als
Bewerbungsanlage mit Link zur App. Nicht jeder Gutachter klickt.

---

## 7. Aufwandsstufen

| Stufe | Umfang | Aufwand |
|---|---|---|
| **Minimal** | Pane 1 + Pane 2 | 3–4 Tage |
| **Solide** ← empfohlen | + Pane 3 (ML mit DEM/ERA5/SST, ohne GOES) + Pane 4a | 1–1,5 Wochen |
| **Vollständig** | + GOES-BTD als Prädiktor + Pane 4b ausformuliert | 2,5–3 Wochen |

**Warum „Solide" das beste Verhältnis hat:** Pane 3 mit AOA ist das stärkste einzelne
Fachsignal, Pane 4a das originellste. Pane 2 ist neu, aber billig — ein
FeatureServer-Query plus ein DEM, das ohnehin heruntergeladen wird. Der Brocken bleibt
Pane 3.

---

## 8. Ehrlichkeitsregeln für die App

Vier Regeln, die durchgängig gelten und sichtbar sein müssen:

1. **Keine erfundenen Daten.** Nichts wird simuliert, außer in Pane 4a — und dort
   heißt es explizit Simulation.
2. **Jede Aussage trägt ihre Herkunft** (Messung / Reanalyse / Satellit / Modell /
   Literatur). Prinzip aus `360Pano3D/EXPOSE.md` §2c.
3. **Grenzen stehen neben dem Ergebnis, nicht im Kleingedruckten.** BTD versagt bei
   mehrschichtiger Bewölkung. Die Vegetationskarte ist 30 m. Die AOA-Maske ist
   ausgegraut, nicht weggelassen.
4. **Keine Vorwegnahme von A1.** Kopfzeile: unabhängige methodische Machbarkeitsstudie
   auf Basis öffentlicher Daten, mit Zitationshinweis für CDF und USFQ.

**Rahmungssatz fürs Anschreiben** (unverändert aus v1):

> „Um meine Arbeitsweise mit Klima- und Fernerkundungsdaten konkret zu machen, habe ich
> eine kleine methodische Machbarkeitsstudie zur Garúa-Klimatologie und zum
> Scalesia-Bestand auf Basis öffentlich verfügbarer Daten (CDF DataZone, USFQ-
> Vegetationskarte, ERA5, GOES ABI) erstellt: [Link]. Sie ist bewusst als
> Methodendemonstration angelegt und nimmt keine Ergebnisse des Teilprojekts vorweg."

---

## 9. Nächste Schritte

| # | Schritt | Aufwand |
|---|---|---|
| 1 | ~~`06_download_vegetation.R` schreiben, `vegetation:`-Block in `config.yml`~~ | **erledigt** |
| 2 | ~~Skript laufen lassen, Flächenbilanz ablesen~~ | **erledigt** — Befund in §2 |
| 2a | ~~Überlappungen auflösen~~ | **entfällt** — es gibt keine (§2) |
| 2b | ~~`06_download_vegetation.R` auf geometrischen Clip umstellen~~ | **erledigt** — `clip_to_bbox()`, `clip_bbox` in `config.yml` |
| 2c | ~~Zonale Statistik DEM × Vegetation~~ | **erledigt** — `analysis/01_zonal_vegetation_dem.R`, Ergebnis in §2 |
| 2c′ | ~~Skripte in R gegenlaufen lassen~~ | **erledigt** — läuft, Ergebnis deckt sich mit dem Python-Vorlauf auf <1 % |
| 2d | ~~Gipfelfraktion klären~~ | **entschärft** — oberhalb 700 m nur noch 186 ha, trägt die Aussage nicht |
| 2e | Scalesia-Restbestand von der humiden Zone trennen — Los Gemelos und die übrigen Bestände als eigene Auswahl, notfalls per Handdigitalisierung nach Literaturkarte | 2 h |
| 3 | ~~CDF-Stationsdaten, Nebeldefinition (Pane 1)~~ | **erledigt** — `analysis/02_fog_definition.R` |
| 3a | ~~Homogenitätsprüfung~~ | **erledigt** — `analysis/03_homogeneity.R`, sechs Brüche in der Differenzreihe |
| 3b | **Homogenisierung**: Teilperioden an die jüngste anpassen (Differenzreihen-Verfahren), danach Trend und ENSO-Kopplung erneut prüfen | 1–2 Tage |
| 3c | Rückfrage CDF: Stationsprotokolle für 1993, 1999, 2002, 2005, 2008, 2012 — gab es Personal-/Gerätewechsel? Sechs datierte Brüche sind eine sehr konkrete Frage | — |
| 4 | Ozean-Repo: `v1.0` taggen, shinylive-Export, PersPage-iframe umhängen | 0,5 Tag |
| 5 | *Optional:* GEDI-Footprintzahl mit Earthdata-Login verifizieren — nur um die Aussage in Pane 4b mit einer Zahl zu belegen | 20 min |
| 6 | ERA5-LTS + SST-Anomalie zusammenführen, Prädiktormatrix aufbauen (Pane 3) | 2–3 Tage |
| 7 | Kontakt USFQ (grivast@usfq.edu.ec) wegen vollständiger Shapefiles | — |

---

## Quellen

**Forschungsgruppe und Kontext**

- [When the Garúa Disappears – Research Unit GArua, Philipps-Universität Marburg](https://www.uni-marburg.de/en/prfolder-en/news/when-the-garua-disappears-a-new-research-unit-will-study-the-future-of-the-galapagos-cloud-forests)
- [DFG fördert fünf neue Forschungsgruppen](https://www.dfg.de/de/aktuelles/neuigkeiten-themen/pressemitteilungen/2026/pressemitteilung-nr-24)
- [DARWIN-Projekt, WP1 Field observations (AWS-Netz Marburg)](https://vhrz669.hrz.uni-marburg.de/darwin/content_subprojects.do?phase=1&subpage=aims&subprojectid=1020)

**Daten**

- [CDF DataZone – Climatology Database](https://datazone.darwinfoundation.org/en/climate/bellavista)
- [A_NATIVE_ECOSISTEMS_2016 – FeatureServer (USFQ)](https://services5.arcgis.com/qefe3CGaSKnteGG1/arcgis/rest/services/A_ECOSISTEMAS_NATIVOS_2016/FeatureServer)
- [Vegetation Map of Galapagos v.2016 – Plant Ecology Lab, USFQ](https://ecologyecuador.com/projects/galapagos/drones/)
- [Fundación Charles Darwin – Geodata Hub](https://geodata-fcdgps.opendata.arcgis.com/)
- [GEDI L2A Elevation and Height Metrics V002 – NASA Earthdata](https://www.earthdata.nasa.gov/data/catalog/lpcloud-gedi02-a-002)
- [GEDI Mission Status – University of Maryland](https://gedi.umd.edu/mission-status/)
- [NASA: Pause der GEDI-Mission](https://www.earthdata.nasa.gov/news/nasa-announces-pause-gedi-mission)
- [OpenTopography – Sierra Negra Volcano, Galápagos 2018](https://portal.opentopography.org/dataspace/dataset?opentopoID=OTDS.092020.32715.1)

**Scalesia und Invasive**

- [Restoring the threatened Scalesia forest: a decade of invasive plant management (Frontiers in Forests and Global Change, 2024)](https://www.frontiersin.org/journals/forests-and-global-change/articles/10.3389/ffgc.2024.1350498/full)
- [Limited natural regeneration of unique Scalesia forest following invasive plant removal (PLOS One)](https://journals.plos.org/plosone/article?id=10.1371%2Fjournal.pone.0258467)
- [Scalesia Forests in Santa Cruz could be gone in 20 years – CDF](https://www.darwinfoundation.org/en/news/all-news-stories/scalesia-forests-in-santa-cruz-could-be-gone-in-20-years/)
- [Scalesia Forest Restoration – Charles Darwin Foundation](https://www.darwinfoundation.org/en/our-work/land/scalesia-forest-restoration/)

**Methodik**

- [GOES-R Fog Product / Night Fog BTD (CIMSS)](https://fusedfog.ssec.wisc.edu/2019/12/17/ifr-probability-brightness-temperature-differences-and-nighttime-microphysics-rgb-estimates-of-fog/)
- [TLS to Predict Canopy Metrics, Water Storage Capacity and Throughfall (Remote Sensing)](https://www.mdpi.com/2072-4292/10/12/1958)
- [Water security and agricultural systems in the Galapagos Islands (Frontiers in Water)](https://www.frontiersin.org/journals/water/articles/10.3389/frwa.2023.1245207/full)
