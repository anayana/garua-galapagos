# =============================================================================
# 04_maps.R
#
# Kartengrundlagen für Pane 3 der App vorbereiten.
#
# ---------------------------------------------------------------------------
# WARUM VORBERECHNEN STATT IN DER APP RECHNEN
# ---------------------------------------------------------------------------
# Die App soll später mit shinylive nach WebAssembly kompiliert werden und
# ohne Server im Browser laufen. sf und terra sind dafür schwere bis
# unmögliche Abhängigkeiten -- GDAL/PROJ im Browser ist ein Glücksspiel.
#
# Deshalb wird hier einmalig alles zu einfachen Matrizen gerastert und als
# RDS abgelegt. Die App braucht dann nur noch image() aus dem Basis-R.
# Preis: die Karte ist ein Raster fester Auflösung, kein zoombarer Vektor.
# Für Zonenaussagen reicht das -- die Quellkarte hat ohnehin nur 30 m.
#
# Erzeugt in data/processed/:
#   maps_santacruz.rds   Liste mit veg (Klassencodes), dem (Höhe), Achsen,
#                        Klassennamen, Stationen, optional LULC-Zeitschnitte
#
# VORAUSSETZUNG: 03_download_dem.R und 06_download_vegetation.R
# Optional:      07_download_lulc.R  (ESA WorldCover / MapBiomas)
#
# Aufruf (Arbeitsverzeichnis = Projektordner Galapagos):
#   source("analysis/04_maps.R")
#   build_maps(n = 600)        feineres Raster
# =============================================================================

this_dir <- function() {
  a <- commandArgs(trailingOnly = FALSE)
  m <- grep("^--file=", a, value = TRUE)
  if (length(m)) return(dirname(normalizePath(sub("^--file=", "", m[1]))))
  fr <- sys.frames()
  if (length(fr) && !is.null(fr[[1]]$ofile)) return(dirname(normalizePath(fr[[1]]$ofile)))
  getwd()
}
source(file.path(dirname(this_dir()), "download", "00_common.R"))

TAG <- "maps"

# -----------------------------------------------------------------------------
build_maps <- function(n = 400, island = "SantaCruz") {
  need_pkg("sf", "terra")

  cfg <- load_config()
  v   <- cfg$vegetation
  bb  <- v$clip_bbox

  veg_path <- file.path(resolve_path(cfg, "vegetation"),
                        sprintf("ecosistemas_nativos_2016_%s.gpkg", island))
  dem_path <- list.files(resolve_path(cfg, "dem"), pattern = "\\.tif$",
                         full.names = TRUE)[1]
  if (!file.exists(veg_path)) stop("Vegetationskarte fehlt: ", veg_path)
  if (is.na(dem_path))        stop("DEM fehlt")

  veg <- sf::st_read(veg_path, quiet = TRUE)
  dem <- terra::rast(dem_path)

  # --- Zielraster ------------------------------------------------------------
  # Seitenverhältnis aus der Bbox, damit die Karte nicht verzerrt.
  ext <- terra::ext(as.numeric(bb$lon_min), as.numeric(bb$lon_max),
                    as.numeric(bb$lat_min), as.numeric(bb$lat_max))
  br  <- (ext[4] - ext[3]) / (ext[2] - ext[1])
  tmpl <- terra::rast(ext, ncol = n, nrow = round(n * br), crs = "EPSG:4326")
  log_info(TAG, "Zielraster %d x %d Zellen", terra::ncol(tmpl), terra::nrow(tmpl))

  # --- Vegetation ------------------------------------------------------------
  lev <- sort(unique(veg[["Ecosis_Nat"]]))
  vv  <- terra::vect(sf::st_transform(veg, "EPSG:4326"))
  vv$.cid <- match(vv$Ecosis_Nat, lev)
  vr  <- terra::rasterize(vv, tmpl, field = ".cid")

  # --- DEM auf dasselbe Gitter ----------------------------------------------
  dr <- terra::resample(terra::crop(dem, ext), tmpl, method = "bilinear")

  # --- Als Matrix ablegen ----------------------------------------------------
  # terra liefert Zeilen von Nord nach Süd; image() erwartet y aufsteigend.
  # Deshalb wird gespiegelt und transponiert -- sonst steht die Karte kopf.
  as_img <- function(r) {
    m <- terra::as.matrix(r, wide = TRUE)
    t(m[nrow(m):1, ])
  }

  out <- list(
    veg     = as_img(vr),
    dem     = as_img(dr),
    x       = seq(ext[1], ext[2], length.out = terra::ncol(tmpl)),
    y       = seq(ext[3], ext[4], length.out = terra::nrow(tmpl)),
    klassen = lev,
    stationen = data.frame(
      name = c("Puerto Ayora", "Bellavista"),
      lon  = c(cfg$stations$puerto_ayora$lon, cfg$stations$bellavista$lon),
      lat  = c(cfg$stations$puerto_ayora$lat, cfg$stations$bellavista$lat),
      hoehe = c(cfg$stations$puerto_ayora$elevation_m,
                cfg$stations$bellavista$elevation_m),
      stringsAsFactors = FALSE
    ),
    stand = as.character(Sys.Date())
  )

  # --- Optional: LULC-Zeitschnitte ------------------------------------------
  lulc_dir <- file.path(cfg$paths$raw, "lulc")
  if (dir.exists(lulc_dir)) {
    tifs <- list.files(lulc_dir, pattern = "\\.tif$", full.names = TRUE)
    if (length(tifs)) {
      log_info(TAG, "%d LULC-Zeitschnitte gefunden", length(tifs))
      out$lulc <- lapply(tifs, function(f) {
        r <- terra::resample(terra::crop(terra::rast(f), ext), tmpl, method = "near")
        as_img(r)
      })
      names(out$lulc) <- gsub("\\.tif$", "", basename(tifs))
    }
  } else {
    log_info(TAG, "kein data/raw/lulc -- Zeitreihe bleibt leer.")
    log_info(TAG, "  MapBiomas Ecuador: source(\"download/07_download_lulc.R\")")
  }

  dir.create(cfg$paths$processed, recursive = TRUE, showWarnings = FALSE)
  dest <- file.path(cfg$paths$processed, sprintf("maps_%s.rds", island))
  saveRDS(out, dest, compress = "xz")
  log_info(TAG, "geschrieben: %s (%.1f MB)", dest, file.size(dest) / 1e6)

  # Kontrolle: Höhenbereich muss zu Santa Cruz passen (~0 bis 864 m)
  rng <- range(out$dem, na.rm = TRUE)
  log_info(TAG, "Höhenbereich im Ausschnitt: %.0f bis %.0f m", rng[1], rng[2])
  if (rng[2] < 500 || rng[2] > 1200) {
    log_warn(TAG, "Gipfelhöhe unplausibel -- Cerro Crocker liegt bei ~864 m.")
  }

  invisible(out)
}

build_maps()
