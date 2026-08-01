# =============================================================================
# 03_download_dem.R
#
# Copernicus DEM GLO-30 (30 m) für den Galápagos-Ausschnitt.
#
# Warum das Gelände die wichtigste Prädiktorschicht ist:
#   Nebelinterzeption ist auf Galápagos fast vollständig eine Funktion aus
#   Höhe und Exposition. Die Passate kommen aus Südost, die Luv-Südosthänge
#   oberhalb von ~250 m liegen regelmässig in der Stratusschicht, die
#   Leeseite bleibt trocken. Aus dem DEM kommen Höhe, Hangneigung,
#   Exposition und ein Topographic Position Index -- genau die Prädiktoren,
#   mit denen sich Punktmessungen später in die Fläche übertragen lassen.
#
# Warum das in R eleganter geht als über einen klassischen Download:
#   Die Kacheln liegen als Cloud Optimized GeoTIFF im offenen AWS-Bucket.
#   terra spricht über GDAL direkt mit /vsicurl/ und liest nur die Kacheln
#   des angefragten Ausschnitts. Wir laden also nie 12 Volltiles, sondern
#   schneiden serverseitig zu und schreiben ein einziges kompaktes COG.
#
# Kachelschema (Südwestecke einer 1-Grad-Zelle):
#   .../Copernicus_DSM_COG_10_S01_00_W091_00_DEM/
#       Copernicus_DSM_COG_10_S01_00_W091_00_DEM.tif
#   Reine Ozeankacheln existieren nicht -- 404 ist Normalfall, kein Fehler.
#
# Aufruf in der R-Konsole (Arbeitsverzeichnis = Projektordner Galapagos):
#   source("download/03_download_dem.R")            laeuft sofort (Archipel)
#   download_dem(focus = TRUE)                      nur Santa Cruz
#   download_dem(keep_tiles = TRUE, overwrite = TRUE)
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

TAG <- "dem"

tile_name <- function(lat, lon, res_tag = "10") {
  sprintf("Copernicus_DSM_COG_%s_%s%02d_00_%s%03d_00_DEM",
          res_tag,
          if (lat >= 0) "N" else "S", abs(lat),
          if (lon >= 0) "E" else "W", abs(lon))
}

# Alle 1-Grad-Kacheln, deren Südwestecke die Box berührt
tiles_for_bbox <- function(b) {
  lats <- seq(floor(b[["lat_min"]]), floor(b[["lat_max"]]))
  lons <- seq(floor(b[["lon_min"]]), floor(b[["lon_max"]]))
  expand.grid(lat = as.integer(lats), lon = as.integer(lons))
}

download_dem <- function(focus = FALSE, overwrite = FALSE, keep_tiles = FALSE) {
  need_pkg("terra")

  cfg     <- load_config()
  out     <- resolve_path(cfg, "dem")
  base    <- sub("/$", "", cfg$dem$base_url)
  res_tag <- as.character(cfg$dem$resolution_tag)
  focus   <- isTRUE(focus)

  b   <- bbox_from_cfg(cfg, focus = focus)
  tls <- tiles_for_bbox(b)
  log_info(TAG, "Ausschnitt lon [%.2f, %.2f], lat [%.2f, %.2f] -> %d Kandidatenkachel(n)",
           b[["lon_min"]], b[["lon_max"]], b[["lat_min"]], b[["lat_max"]], nrow(tls))

  # GDAL-Einstellungen für zügiges Lesen aus dem Bucket
  terra::setGDALconfig("GDAL_DISABLE_READDIR_ON_OPEN", "EMPTY_DIR")
  terra::setGDALconfig("CPL_VSIL_CURL_ALLOWED_EXTENSIONS", ".tif")

  available <- character(0)
  for (i in seq_len(nrow(tls))) {
    nm  <- tile_name(tls$lat[i], tls$lon[i], res_tag)
    url <- sprintf("/vsicurl/%s/%s/%s.tif", base, nm, nm)
    r <- try(terra::rast(url), silent = TRUE)
    if (inherits(r, "try-error")) {
      log_info(TAG, "keine Kachel (reine Ozeanfläche): %s", nm)
    } else {
      log_info(TAG, "verfügbar: %-42s %d x %d Pixel", nm, terra::ncol(r), terra::nrow(r))
      available <- c(available, url)
    }
  }

  if (!length(available)) {
    stop("Keine einzige Kachel gefunden. Kachelbenennung prüfen: ",
         base, "/readme.html", call. = FALSE)
  }

  suffix   <- if (focus) "santacruz" else "archipel"
  dest_dem <- file.path(out, sprintf("copernicus_dem30_%s.tif", suffix))

  if (file.exists(dest_dem) && !isTRUE(overwrite)) {
    log_info(TAG, "übersprungen (vorhanden): %s", basename(dest_dem))
  } else {
    # Virtueller Mosaik über die vsicurl-Pfade: GDAL holt nur die Blöcke,
    # die der crop() tatsächlich anfasst.
    vrt_path <- tempfile(fileext = ".vrt")
    mos <- if (length(available) == 1L) terra::rast(available) else
      terra::vrt(available, filename = vrt_path, overwrite = TRUE)

    log_info(TAG, "schneide zu und schreibe COG ...")
    dem <- terra::crop(mos, ext_from_cfg(cfg, focus = focus))
    names(dem) <- "elevation"

    terra::writeRaster(dem, dest_dem, overwrite = TRUE,
                       filetype = "COG",
                       gdal = c("COMPRESS=DEFLATE", "PREDICTOR=2", "NUM_THREADS=ALL_CPUS"))
    log_info(TAG, "geschrieben: %s  (%d x %d, %.1f MB)",
             basename(dest_dem), terra::ncol(dem), terra::nrow(dem),
             file.size(dest_dem) / 1e6)
    log_info(TAG, "Höhenbereich im Ausschnitt: %.0f bis %.0f m",
             terra::global(dem, "min", na.rm = TRUE)[1, 1],
             terra::global(dem, "max", na.rm = TRUE)[1, 1])
  }

  # Optional die Volltiles zusätzlich lokal ablegen
  if (isTRUE(keep_tiles)) {
    for (url in available) {
      plain <- sub("^/vsicurl/", "", url)
      download_file_safe(plain, file.path(out, basename(plain)),
                         overwrite = isTRUE(overwrite), tag = TAG)
    }
  }

  write_citation(out,
"Copernicus DEM GLO-30
=====================

European Space Agency (2024). Copernicus Global Digital Elevation Model.
Bezogen über die Registry of Open Data on AWS, Bucket copernicus-dem-30m.
  https://registry.opendata.aws/copernicus-dem/

Lizenz: frei nutzbar unter den Copernicus-DEM-Bedingungen, Quellenangabe
verpflichtend. Höhen als DSM (Oberflächenmodell, inklusive Vegetation) --
für Kronenhöhenanalysen ist das relevant: GLO-30 ist kein Geländemodell.")

  log_info(TAG, "fertig -- Ablage: %s", out)
  invisible(dest_dem)
}

# Standardlauf beim source(); Variante: download_dem(focus = TRUE)
.a <- parse_args(list(focus = FALSE, overwrite = FALSE, keep_tiles = FALSE))
download_dem(focus      = isTRUE(.a$focus),
             overwrite  = isTRUE(.a$overwrite),
             keep_tiles = isTRUE(.a$keep_tiles))
