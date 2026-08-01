# Downloadpipeline — Galápagos-Nebelklimatologie

Holt alle Datensätze der Vorstudie zu Teilprojekt A1 (FOR 5621 GArua).
Alle Quellen sind frei; nur ERA5 braucht einen kostenlosen Account.

**Reines R.** Kein Python, keine externen Kommandozeilenwerkzeuge.

```
Galapagos/
├─ run.R                           # Einstiegspunkt für die R-Konsole
├─ config.yml                      # Region, Stationen, Zeiträume, Dataset-IDs
└─ download/
   ├─ 00_common.R                  # Konfiguration, Download mit Retry, Logging
   ├─ 01_download_cdf_stations.R
   ├─ 02_download_enso.R
   ├─ 03_download_dem.R
   ├─ 04_download_era5.R
   ├─ 05_download_goes.R
   ├─ 06_download_vegetation.R
   └─ download_all.R
```

## Schnellstart

Alles läuft aus der R-Konsole. Arbeitsverzeichnis ist der Projektordner
`Galapagos`. `run.R` enthält dieselben Zeilen zum Durchklicken.

```r
install.packages(c("yaml", "curl", "readr", "terra", "sf", "httr2", "xml2",
                   "jsonlite", "ncdf4", "ecmwfr"))

# Stationen + ENSO + DEM + Vegetation, wenige MB, kein Account nötig
source("download/download_all.R")
```

Jedes Skript läuft beim Sourcen sofort mit den Standardwerten durch **und**
hinterlässt seine Funktion für weitere Aufrufe:

```r
source("download/01_download_cdf_stations.R")
download_stations(with_raw = TRUE)

source("download/06_download_vegetation.R")
download_vegetation(all_islands = TRUE)

source("download/03_download_dem.R")
download_dem(focus = TRUE)

source("download/05_download_goes.R")
download_goes(dry_run = TRUE)
download_goes(start = "2024-07-01", end = "2024-07-31", hours = 6)

source("download/04_download_era5.R")
download_era5(years = 2023:2024)
```

Alle Skripte sind idempotent: Vorhandenes wird übersprungen, `overwrite = TRUE`
erzwingt das Neuladen. Downloads laufen über eine `.part`-Datei und werden erst
nach vollständigem Transfer umbenannt — ein Abbruch hinterlässt keine halben
Dateien, die beim nächsten Lauf fälschlich für fertig gehalten werden.

<details>
<summary>Terminal statt Konsole</summary>

Dieselben Skripte nehmen auch Kommandozeilenflags entgegen, falls sie mal aus
einem Cronjob oder GitHub-Actions-Workflow laufen sollen:

```bash
Rscript download/download_all.R --overwrite
Rscript download/05_download_goes.R --dry-run
Rscript download/04_download_era5.R --years=2023,2024
```
</details>

## Die Datensätze

| Quelle | Umfang | Account | Skript |
|---|---|---|---|
| CDF dataZone — Puerto Ayora, Bellavista | ~2 MB | nein | `01_…` |
| NOAA ONI / Niño-3.4 | ~50 kB | nein | `02_…` |
| Copernicus DEM GLO-30 | wenige MB nach Zuschnitt | nein | `03_…` |
| ERA5 single + pressure levels | ~1 GB / Jahrzehnt | **ja** (CDS) | `04_…` |
| GOES-19/16 ABI L2 CMIP Full Disk | **gross**, siehe unten | nein | `05_…` |
| Vegetationskarte Galápagos v.2016 (USFQ) | ~20 MB | nein | `06_…` |

### 1 · Bodenstationen (Charles Darwin Foundation)

Zwei Stationen auf Santa Cruz, ~7 km voneinander entfernt, 221 Höhenmeter
auseinander — Puerto Ayora auf 2 m, Bellavista auf 223 m. Der Kontrast
zwischen beiden ist die Nebelklimatologie in Reinform.

Spalten: `observation_date, min_air_temp, max_air_temp, mean_air_temp,
sea_temp, humidity, precipitation, sunshine_hours, clouds`

`clouds` sind Achtel (Okta 0–8) aus visueller Beobachtung. Ein Garúa-Tag
lässt sich daraus als `clouds == 8 & humidity >= 95 & precipitation > 0`
annähern — mehr als ein Proxy ist es nicht, und genau diese
Definitionsabhängigkeit ist ein interessanter Befund, kein Mangel.

**Der Qualitätsbericht läuft direkt nach dem Download**, nicht erst in der
Auswertung. Wer eine Zeitreihe lädt, ohne einmal hinzusehen, baut die
Fehler später ins Modell ein. Gemeldet werden Zeitraum, Fehlanteil je
Spalte, vertauschte Min/Max-Paare und die Lückenstruktur — also nicht nur
*wie viel* fehlt, sondern ob am Stück.

Bei Bellavista sind `sea_temp` und `sunshine_hours` durchgehend leer; die
Station misst sie schlicht nicht. Und gleich der erste Datensatz vom
9. Juni 1987 trägt `min = 26.6` bei `max = 16.0`. Solche
Digitalisierungsfehler gehören geflaggt, nicht stillschweigend gelöscht.

Weitere dokumentierte Einschränkungen, die in jede Auswertung gehören:

- **Bellavista wurde Ende 2015 verlegt** (ca. 380 m nach NNW). Bruch in der
  Reihe — bei Trendanalysen zwingend zu berücksichtigen.
- **Puerto Ayora 2020–2021**: Minimumtemperaturen laut Betreiber
  gerätebedingt fehlerhaft.
- Die CSV-Werte wurden für den Viewer aufbereitet. Die unbereinigte
  Arbeitsmappe holt `--with-raw` dazu.

Lizenz **CC BY-NC-SA 4.0**: Namensnennung verpflichtend, keine kommerzielle
Nutzung, Weitergabe unter gleichen Bedingungen. Für eine öffentliche
Shiny-App heisst das: Quelle sichtbar im Interface nennen. Jedes Skript legt
eine `CITATION.txt` neben die Daten.

### 2 · ENSO-Index

Garúa und El Niño verhalten sich gegenläufig. In warmen ENSO-Phasen
schwächt sich die Passatinversion ab und die Wolkenuntergrenze steigt —
ein warmes Jahr ist damit das beste natürliche Analogon für die
Erwärmungsszenarien, um die es in A1 geht. Nebelhäufigkeit gegen ONI
aufgetragen ergibt aus zwei freien Reihen eine physikalisch
interpretierbare Sensitivität, ganz ohne Modell.

Das Skript probiert mehrere Quellen durch und prüft die Antwort auf
Plausibilität — CPC liefert bei geänderten Pfaden gern eine HTML-Fehlerseite
mit Status 200.

### 3 · Copernicus DEM GLO-30

Nebelinterzeption ist auf Galápagos fast vollständig eine Funktion aus Höhe
und Exposition: Passate aus Südost, Luvhänge oberhalb ~250 m regelmässig in
der Stratusschicht, Leeseite trocken. Aus dem DEM kommen Höhe, Hangneigung,
Exposition und TPI — die Prädiktoren für die spätere Flächenübertragung.

**Hier zahlt sich R aus.** Die Kacheln liegen als Cloud Optimized GeoTIFF im
offenen Bucket. `terra` spricht über GDAL direkt mit `/vsicurl/` und liest
nur die Blöcke, die der `crop()` tatsächlich anfasst:

```r
mos <- terra::vrt(paste0("/vsicurl/", urls))
dem <- terra::crop(mos, ext_from_cfg(cfg))
```

Es werden also nie 12 Volltiles heruntergeladen, sondern serverseitig
zugeschnitten und ein einziges kompaktes COG geschrieben. `--keep-tiles`
legt die Volltiles zusätzlich lokal ab, falls gewünscht.

Kachelname bezeichnet die **Südwestecke** einer 1-Grad-Zelle. Reine
Ozeankacheln existieren nicht; ein Fehlschlag ist hier Normalfall, nicht
Fehler.

> GLO-30 ist ein **DSM**, also ein Oberflächenmodell inklusive Vegetation.
> Für Kronenhöhenanalysen relevant: es ist kein Geländemodell.

### 4 · ERA5

Liefert die synoptische Einbettung:

| Grösse | Ableitung | Bedeutung |
|---|---|---|
| LTS | θ(700 hPa) − θ(1000 hPa) | Inversionsstärke |
| LCL | aus T2m und Td2m | Kondensationsniveau |
| `blh` | direkt | Grenzschichthöhe |
| `lcc` | direkt | tiefe Bewölkung |

Damit wird aus „es war neblig" die Frage „unter welchen Bedingungen war es
neblig" — die Voraussetzung für Übertragbarkeit auf Klimaszenarien.

**Einrichtung:** Account auf `cds.climate.copernicus.eu`, dann in R:

```r
ecmwfr::wf_set_key(key = "<persönlicher Token>")
```

Alternativ `CDSAPI_KEY` als Umgebungsvariable — so läuft es auch in
GitHub Actions.

> **Häufigste Fehlerquelle:** Die Lizenzbedingungen des Datensatzes müssen
> einmal im Webinterface akzeptiert werden. Sonst antwortet jede Anfrage mit
> 403, ohne dass der Grund erkennbar wäre.

Anfragen laufen über eine Warteschlange und können dauern. Pro Jahr und
Datensatz wird eine eigene Datei geschrieben, damit ein Abbruch höchstens
ein Jahr kostet.

### 5 · GOES ABI

Zwei Kanäle, ein Prinzip: Wassertröpfchen emittieren bei 3,9 µm deutlich
schlechter als ein Schwarzkörper, bei 10,3 µm nahezu perfekt. Die Differenz
BT(10,3) − BT(3,9) hebt nachts tiefe Wasserwolken hervor.

Bekannte Schwäche, die man offen benennen sollte: Liegt höhere Bewölkung
darüber, ist die tiefe Schicht unsichtbar. Genau deshalb braucht die
Satellitenauswertung die Bodenvalidierung, die A1 liefert.

Das Bucket-Listing läuft über die öffentliche S3-REST-Schnittstelle mit
`httr2` und `xml2` — **kein AWS-SDK nötig**, kein Account, kein Schlüssel.
Die Satellitenwahl erfolgt automatisch: GOES-19 ist seit 7. April 2025
operationeller GOES-East (75,2° W), davor GOES-16.

> ⚠️ **Datenmenge.** Eine Full-Disk-Datei umfasst 100–400 MB *pro Kanal und
> Termin*. Immer erst `--dry-run`.

Der Zuschnitt läuft standardmässig direkt nach dem Download und verwirft die
Vollszene — typisch von einigen hundert MB auf wenige hundert kB. `terra`
übernimmt dabei die geostationäre Projektion aus der NetCDF-Datei; falls
GDAL sie nicht erkennt, wird sie aus den Attributen von
`goes_imager_projection` rekonstruiert. `--no-subset` und `--keep-full`
schalten das ab.

### 6 · Vegetationskarte Galápagos v.2016 (USFQ)

Die Karte enthält die Klasse *Evergreen Forest and Shrubland* — die
Scalesia-Zone — und, davon getrennt, eine Klasse *Invasive Species*. Erst
dieser Gegensatz erlaubt die ehrliche Aussage: Die akute Bedrohung von
*Scalesia pedunculata* ist heute die Invasion, der Nebelrückgang ist der
langsamere, zweite Stressor auf einem bereits geschwächten Restbestand.

Geprüft am 2026-08-01: **20.106 Polygone, 15 Klassen**, Geometrie EPSG:3857,
Felder `Ecosis_Nat`, `Isla`, `Area_Ha`. Das Feld `Isla` ist sauber gepflegt,
deshalb Attributfilter `Isla='Santa Cruz'` statt Bbox-Clip.

> ⚠️ **Der Grund, warum dieses Skript mehr ist als ein `st_read()`.**
> Der Dienst hat `maxRecordCount = 2000`. Eine einzelne Abfrage liefert
> stillschweigend die ersten 2000 Polygone — ohne Fehler, ohne Warnung. Eine
> Flächenbilanz darauf wäre stumm falsch. Das Skript paginiert über
> `resultOffset` und gleicht die geladene Feature-Zahl gegen
> `returnCountOnly` ab; stimmt das nicht überein, bricht es ab.
>
> Santa Cruz allein hat 1437 Polygone und passt damit in eine Seite — beim
> Standardlauf sieht man nur „Seite 1". Bei `--all-islands` sind es 11 Seiten.
> Die Vollständigkeitsprüfung greift in beiden Fällen.

Zusätzlich stellt es die mitgelieferte `Area_Ha` der aus der Geometrie neu
gerechneten Fläche (UTM 15S) gegenüber. Über 5 % Abweichung gibt es eine
Warnung — dann stimmt etwas mit Projektion oder Attribut nicht.

Ausgabe: ein GeoPackage plus `flaechenbilanz_*.csv` mit Polygonzahl und
Fläche je Klasse.

> **Auflösungsgrenze, die neben jedem Ergebnis stehen muss:** Bei 30 m und
> 1:60.000 ist Los Gemelos (~140 ha) rund 15 Pixel breit. Tauglich für
> Zonen- und Flächenanteilsaussagen, **nicht** für Bestandes- oder
> Einzelbaumebene.

Quelle: *Instituto de Geografía, Universidad San Francisco de Quito*. Für die
vollständigen Shapefiles inklusive Invasiven-Einheiten in Originalauflösung
ist die Anfrage beim Institut der saubere Weg.

## Vor dem Produktivlauf prüfen

Diese Punkte konnte ich beim Schreiben nicht gegen einen echten Lauf testen —
im Sandbox-Container war weder R noch Netzzugang verfügbar. Beim ersten
Durchlauf verifizieren:

1. **GOES-Zuschnitt** — einmal `plot()` aufrufen und die Küstenlinie gegen
   die Karte halten, bevor daraus Statistik wird.
2. **CDS-Request-Syntax** — der Climate Data Store hat sein API-Format
   Ende 2024 umgestellt. Bei Fehlern das aktuelle Schema aus dem
   „Show API request"-Knopf der Datensatzseite übernehmen.
3. **ENSO-Pfade** — falls beide Fallbacks scheitern, aktuelle URL bei CPC
   nachsehen und in `config.yml` eintragen.

## Andere Region

Nur den `region`-Block in `config.yml` ändern. DEM-Kacheln, ERA5-Ausschnitt
und GOES-Zuschnitt folgen automatisch. Für Regionen ausserhalb der
GOES-Abdeckung wäre stattdessen Meteosat oder Himawari nötig.

## Quellen

- [CDF dataZone — Climatology Database](https://datazone.darwinfoundation.org/en/climate)
- [Bellavista](https://datazone.darwinfoundation.org/en/climate/bellavista) · [Puerto Ayora](https://datazone.darwinfoundation.org/en/climate/puerto-ayora)
- [NOAA GOES 16/17/18/19 — Registry of Open Data on AWS](https://registry.opendata.aws/noaa-goes/)
- [Declaration of GOES-19 as GOES-East, NOAA OSPO](https://www.ospo.noaa.gov/data/messages/2025/04/MSG_20250402_1345.html)
- [Copernicus DEM — Registry of Open Data on AWS](https://registry.opendata.aws/copernicus-dem/) · [Kachelschema](https://copernicus-dem-30m.s3.amazonaws.com/readme.html)
- [Copernicus Climate Data Store](https://cds.climate.copernicus.eu)
- [GOES-R Fog Product Examples, CIMSS](https://fusedfog.ssec.wisc.edu/)
