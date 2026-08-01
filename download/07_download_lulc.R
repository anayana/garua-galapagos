# =============================================================================
# 07_download_lulc.R
#
# Landbedeckungs-Zeitschnitte für den Karten-Tab.
#
# ---------------------------------------------------------------------------
# ENTWEDER EINE ECHTE ZEITREIHE ODER KEINE
# ---------------------------------------------------------------------------
# Die USFQ-Vegetationskarte (06_download_vegetation.R) hat nur einen
# Zeitschnitt (2016). Für Landnutzungswandel reicht das nicht.
#
# Naheliegend wäre ESA WorldCover (10 m, ohne Login per S3). Es ist hier
# BEWUSST NICHT umgesetzt: die beiden Jahrgänge 2020 und 2021 liegen ein Jahr
# auseinander und verwenden verschiedene Algorithmusversionen (v100/v200).
# Differenzen daraus sind überwiegend Methodik, nicht Realität. Ein Jahr
# Abstand ist kein Wandel.
#
# Die brauchbare Quelle ist MapBiomas Ecuador:
#   1985-2024, JÄHRLICH, 30 m, 21 Klassen, Galápagos eingeschlossen.
#
# Der Bezug läuft über Google Earth Engine und lässt sich aus R heraus nicht
# automatisieren. Ein kostenloses Konto genügt, der Rest ist ein manueller
# Schritt -- dieses Skript prüft nur, ob das Ergebnis am richtigen Ort liegt,
# und meldet, was fehlt.
#
# VORGEHEN
#   1. Kostenloses Konto: https://earthengine.google.com
#   2. Download-Werkzeug: https://ecuador.mapbiomas.org/en/descargas/
#      (GEE-Skript, erlaubt räumlichen und zeitlichen Zuschnitt)
#   3. Asset in GEE:
#      projects/mapbiomas-public/assets/ecuador/lulc/collection2/...
#      Bandindex: 0 = 1985 ... 38 = 2023
#   4. Legendencodes: https://ecuador.mapbiomas.org/en/codigos-de-la-leyenda/
#   5. Zuschnitt auf die Bbox aus config.yml (vegetation.clip_bbox),
#      Export als GeoTIFF, ablegen als
#         data/raw/lulc/mapbiomas_<jahr>.tif
#   6. source("analysis/04_maps.R")   -- liest alle .tif dort automatisch ein
#
# Aufruf (Arbeitsverzeichnis = Projektordner Galapagos):
#   source("download/07_download_lulc.R")
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

TAG <- "lulc"

# -----------------------------------------------------------------------------
# Prüft, was an MapBiomas-Zeitschnitten vorliegt, und meldet den Rest.
download_lulc <- function() {
  cfg <- load_config()
  out <- file.path(cfg$paths$raw, "lulc")
  dir.create(out, recursive = TRUE, showWarnings = FALSE)

  tifs <- list.files(out, pattern = "^mapbiomas_\\d{4}\\.tif$", full.names = TRUE)

  if (!length(tifs)) {
    log_warn(TAG, "Keine Zeitschnitte in %s", out)
    log_warn(TAG, "MapBiomas Ecuador muss über Google Earth Engine bezogen werden:")
    log_warn(TAG, "  1. Konto:     https://earthengine.google.com")
    log_warn(TAG, "  2. Werkzeug:  https://ecuador.mapbiomas.org/en/descargas/")
    log_warn(TAG, "  3. Zuschnitt: lon %.2f..%.2f / lat %.2f..%.2f",
             as.numeric(cfg$vegetation$clip_bbox$lon_min),
             as.numeric(cfg$vegetation$clip_bbox$lon_max),
             as.numeric(cfg$vegetation$clip_bbox$lat_min),
             as.numeric(cfg$vegetation$clip_bbox$lat_max))
    log_warn(TAG, "  4. Ablage:    %s/mapbiomas_<jahr>.tif", out)
    log_warn(TAG, "ESA WorldCover ist bewusst nicht implementiert -- 2020 und 2021")
    log_warn(TAG, "sind ein Jahr auseinander und algorithmisch verschieden.")
    return(invisible(FALSE))
  }

  jahre <- as.integer(sub(".*_(\\d{4})\\.tif$", "\\1", tifs))
  log_info(TAG, "%d Zeitschnitte: %d bis %d", length(tifs), min(jahre), max(jahre))
  if (length(jahre) < 5 || diff(range(jahre)) < 10) {
    log_warn(TAG, "Weniger als 5 Schnitte oder unter 10 Jahre Spanne --")
    log_warn(TAG, "für eine Wandel-Aussage zu wenig.")
  }

  write_citation(out,
"Landbedeckung -- MapBiomas Ecuador
==================================

MapBiomas Ecuador, Kollektion 2.0: jaehrlich 1985-2024, 30 m, 21 Klassen,
Galapagos-Archipel eingeschlossen.
https://ecuador.mapbiomas.org  --  Bezug ueber Google Earth Engine.
Zitierhinweis: https://ecuador.mapbiomas.org/en/faq/

NICHT verwendet: ESA WorldCover. Die Jahrgaenge 2020 (v100) und 2021 (v200)
liegen ein Jahr auseinander und nutzen verschiedene Algorithmusversionen --
Differenzen daraus sind ueberwiegend Methodik, kein Landnutzungswandel.")

  log_info(TAG, "danach: source(\"analysis/04_maps.R\")")
  invisible(TRUE)
}

download_lulc()
