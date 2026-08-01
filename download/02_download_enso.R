# =============================================================================
# 02_download_enso.R
#
# Lädt den ENSO-Index (Niño-3.4 / ONI) der NOAA.
#
# Warum er in dieses Projekt gehört:
#   Auf Galápagos sind Garúa und El Niño gegenläufig. In El-Niño-Jahren
#   erwärmt sich das Oberflächenwasser, die Passatinversion schwächt sich ab,
#   die Wolkenuntergrenze steigt -- die Hochlandnebel gehen zurück, während
#   im Tiefland konvektiver Starkregen zunimmt.
#
#   Ein warmes ENSO-Jahr ist damit das beste natürliche Analogon für die
#   Erwärmungsszenarien, um die es in Teilprojekt A1 geht. Wer die
#   Bellavista-Nebelhäufigkeit gegen den ONI aufträgt, bekommt aus zwei
#   freien Reihen eine physikalisch interpretierbare Sensitivität --
#   ohne ein einziges Modell.
#
# Aufruf in der R-Konsole (Arbeitsverzeichnis = Projektordner Galapagos):
#   source("download/02_download_enso.R")           laeuft sofort
#   download_enso(overwrite = TRUE)
# =============================================================================

this_dir <- function() {
  a <- commandArgs(trailingOnly = FALSE)
  m <- grep("^--file=", a, value = TRUE)
  if (length(m)) return(dirname(normalizePath(sub("^--file=", "", m[1]))))
  fr <- sys.frames()
  if (length(fr) && !is.null(fr[[1]]$ofile)) return(dirname(normalizePath(fr[[1]]$ofile)))
  getwd()
}
source(file.path(this_dir(), "00_common.R"))

TAG <- "enso"

# Erste erreichbare Quelle gewinnt -- die CPC-Pfade ändern sich gelegentlich.
try_sources <- function(urls, out_dir, overwrite) {
  for (url in urls) {
    name <- basename(url)
    if (!nzchar(name)) name <- "oni.txt"
    dest <- file.path(out_dir, name)

    if (file.exists(dest) && !overwrite) {
      log_info(TAG, "übersprungen (vorhanden): %s", name)
      return(dest)
    }

    ok <- download_file_safe(url, dest, overwrite = overwrite,
                             retries = 2L, allow_404 = TRUE, tag = TAG)
    if (!ok) next

    # Plausibilitätsprüfung: eine ONI-Reihe hat viele Zeilen, keine HTML-Seite
    txt <- readLines(dest, warn = FALSE)
    if (length(txt) < 20 || any(grepl("<html", txt[1:min(5, length(txt))],
                                      ignore.case = TRUE))) {
      log_warn(TAG, "Antwort sieht nicht nach Datenreihe aus, nächste Quelle: %s", url)
      unlink(dest)
      next
    }
    log_info(TAG, "%s: %d Zeilen  (%s)", name, length(txt), url)
    return(dest)
  }
  NULL
}

download_enso <- function(overwrite = FALSE) {
  cfg <- load_config()
  out <- resolve_path(cfg, "enso")

  dest <- try_sources(unlist(cfg$enso$oni_urls), out, isTRUE(overwrite))

  if (is.null(dest)) {
    stop("Keine ENSO-Quelle erreichbar. Aktuelle Pfade prüfen unter ",
         "https://www.cpc.ncep.noaa.gov/products/analysis_monitoring/ensostuff/ ",
         "und in config.yml eintragen.", call. = FALSE)
  }

  write_citation(out,
"ENSO-Index
==========

NOAA Climate Prediction Center bzw. NOAA Physical Sciences Laboratory.
Niño-3.4-SST-Anomalien / Oceanic Niño Index (ONI).

Der ONI ist ein gleitendes 3-Monats-Mittel der Niño-3.4-Anomalie gegen eine
gleitende 30-Jahres-Basisperiode. El Niño ab +0,5 K, La Niña ab -0,5 K,
jeweils über mindestens fünf aufeinanderfolgende Überlappungsperioden.

Frei nutzbar (US-Regierungsdaten, gemeinfrei). Quellenangabe dennoch üblich.")

  log_info(TAG, "fertig -- Ablage: %s", out)
  invisible(dest)
}

# Standardlauf beim source(); Variante: download_enso(overwrite = TRUE)
.a <- parse_args(list(overwrite = FALSE))
download_enso(overwrite = isTRUE(.a$overwrite))
