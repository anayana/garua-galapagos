# =============================================================================
# 05_download_goes.R
#
# GOES-ABI-Full-Disk-Szenen (Level 2 Cloud & Moisture Imagery) aus dem
# offenen AWS-Bucket -- ohne Account, ohne Schlüssel, ohne AWS-SDK.
# Das Bucket-Listing läuft über die öffentliche S3-REST-Schnittstelle,
# gelesen wird mit terra über GDAL.
#
# Kanäle:
#   C07   3,9 um  (Shortwave IR)
#   C13  10,3 um  (Clean IR)
#
# Prinzip: Wassertröpfchen emittieren bei 3,9 um deutlich schlechter als ein
# Schwarzkörper, bei 10,3 um nahezu perfekt. Die Differenz
# BT(10,3) - BT(3,9) hebt nachts tiefe Wasserwolken hervor.
#
# Bekannte Schwäche, die man offen benennen sollte: Liegt höhere Bewölkung
# darüber, ist die tiefe Schicht unsichtbar. Genau deshalb braucht die
# Satellitenauswertung die Bodenvalidierung, die A1 liefert.
#
# Satellitenwahl automatisch: GOES-19 ist seit 7. April 2025 operationeller
# GOES-East (75,2 W), davor GOES-16. Beide Buckets sind öffentlich.
#
# DATENMENGE
#   Eine Full-Disk-Datei umfasst 100-400 MB je Kanal und Termin. Das Skript
#   schneidet deshalb standardmässig direkt nach dem Download auf die Region
#   zu und verwirft die Vollszene -- typisch von einigen hundert MB auf
#   wenige hundert kB. keep_full = TRUE behält sie.
#
# Aufruf in der R-Konsole (Arbeitsverzeichnis = Projektordner Galapagos):
#   source("download/05_download_goes.R")           laeuft sofort -- erst zaehlen:
#   download_goes(dry_run = TRUE)
#   download_goes(start = "2024-07-01", end = "2024-07-31", hours = 6)
#   download_goes(subset = FALSE, keep_full = TRUE)
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

TAG <- "goes"

# -----------------------------------------------------------------------------
# S3-Listing über die öffentliche REST-Schnittstelle
# -----------------------------------------------------------------------------
# Kein AWS-SDK nötig: anonymes GET auf
#   https://<bucket>.s3.amazonaws.com/?list-type=2&prefix=...
# liefert XML mit den Objektschlüsseln. Paginierung über den
# ContinuationToken, falls mehr als 1000 Objekte im Präfix liegen.
s3_list_keys <- function(bucket, prefix, max_pages = 5L) {
  need_pkg("httr2", "xml2")
  keys  <- character(0)
  token <- NULL

  for (page in seq_len(max_pages)) {
    req <- httr2::request(sprintf("https://%s.s3.amazonaws.com/", bucket))
    req <- httr2::req_url_query(req, `list-type` = "2", prefix = prefix,
                                `max-keys` = "1000")
    if (!is.null(token)) req <- httr2::req_url_query(req, `continuation-token` = token)
    req <- httr2::req_retry(req, max_tries = 3)
    req <- httr2::req_timeout(req, 60)

    resp <- httr2::req_perform(req)
    doc  <- xml2::read_xml(httr2::resp_body_string(resp))
    xml2::xml_ns_strip(doc)

    keys <- c(keys, xml2::xml_text(xml2::xml_find_all(doc, "//Contents/Key")))

    truncated <- xml2::xml_text(xml2::xml_find_first(doc, "//IsTruncated"))
    if (!identical(truncated, "true")) break
    token <- xml2::xml_text(xml2::xml_find_first(doc, "//NextContinuationToken"))
    if (is.na(token) || !nzchar(token)) break
  }
  keys
}

pick_bucket <- function(cfg, day) {
  switch_date <- as.Date(cfg$goes$switch_date)
  if (day >= switch_date) cfg$goes$bucket_current else cfg$goes$bucket_legacy
}

scene_keys <- function(bucket, product, day, hour, band, first_only = TRUE) {
  doy    <- as.integer(format(day, "%j"))
  prefix <- sprintf("%s/%s/%03d/%02d/", product, format(day, "%Y"), doy, hour)

  keys <- s3_list_keys(bucket, prefix)
  # Dateiname z. B. OR_ABI-L2-CMIPF-M6C13_G19_s2024183...
  # Filter auf "C13_G" ist unabhängig vom Scanmodus (M3/M4/M6).
  keys <- keys[grepl(sprintf("%s_G", band), keys, fixed = TRUE) &
                 grepl("\\.nc$", keys)]
  keys <- sort(keys)
  if (first_only && length(keys)) keys[1] else keys
}

# -----------------------------------------------------------------------------
# Zuschnitt auf die Region
# -----------------------------------------------------------------------------
# terra liest die geostationäre Projektion in aller Regel direkt aus der
# NetCDF-Datei. Falls nicht, wird sie aus den Attributen der Variable
# goes_imager_projection rekonstruiert.
#
# HINWEIS: Beim ersten Lauf einmal plot(sub) aufrufen und die Küstenlinie
# gegen die Karte halten, bevor daraus Statistik wird.
goes_crs_fallback <- function(nc_path) {
  if (!requireNamespace("ncdf4", quietly = TRUE)) return(NA_character_)
  nc <- try(ncdf4::nc_open(nc_path), silent = TRUE)
  if (inherits(nc, "try-error")) return(NA_character_)
  on.exit(ncdf4::nc_close(nc), add = TRUE)

  g <- function(a, default = NA_real_) {
    v <- try(ncdf4::ncatt_get(nc, "goes_imager_projection", a), silent = TRUE)
    if (inherits(v, "try-error") || !isTRUE(v$hasatt)) return(default)
    as.numeric(v$value)
  }
  h    <- g("perspective_point_height")
  lon0 <- g("longitude_of_projection_origin")
  a    <- g("semi_major_axis")
  b    <- g("semi_minor_axis")
  swp  <- try(ncdf4::ncatt_get(nc, "goes_imager_projection", "sweep_angle_axis"),
              silent = TRUE)
  sweep <- if (!inherits(swp, "try-error") && isTRUE(swp$hasatt)) swp$value else "x"

  if (anyNA(c(h, lon0, a, b))) return(NA_character_)
  sprintf("+proj=geos +h=%f +lon_0=%f +a=%f +b=%f +sweep=%s +no_defs",
          h, lon0, a, b, sweep)
}

subset_scene <- function(nc_path, cfg, keep_full = FALSE) {
  need_pkg("terra")

  r <- try(terra::rast(sprintf('NETCDF:"%s":CMI', nc_path)), silent = TRUE)
  if (inherits(r, "try-error")) {
    log_warn(TAG, "CMI nicht lesbar in %s", basename(nc_path))
    return(NULL)
  }

  if (is.na(terra::crs(r)) || !nzchar(terra::crs(r))) {
    fb <- goes_crs_fallback(nc_path)
    if (is.na(fb)) {
      log_warn(TAG, "keine Projektion ermittelbar: %s", basename(nc_path))
      return(NULL)
    }
    terra::crs(r) <- fb
    log_info(TAG, "  Projektion aus goes_imager_projection rekonstruiert")
  }

  box  <- terra::vect(ext_from_cfg(cfg), crs = "EPSG:4326")
  boxp <- try(terra::project(box, terra::crs(r)), silent = TRUE)
  if (inherits(boxp, "try-error")) {
    log_warn(TAG, "Reprojektion der Box fehlgeschlagen: %s", basename(nc_path))
    return(NULL)
  }

  scene <- try(terra::crop(r, terra::ext(boxp)), silent = TRUE)
  if (inherits(scene, "try-error") || terra::ncell(scene) == 0) {
    log_warn(TAG, "leerer Ausschnitt: %s", basename(nc_path))
    return(NULL)
  }

  out <- sub("\\.nc$", "_subset.tif", nc_path)
  terra::writeRaster(scene, out, overwrite = TRUE, filetype = "COG",
                     gdal = c("COMPRESS=DEFLATE", "PREDICTOR=2"))
  if (!keep_full) unlink(nc_path)
  out
}

# -----------------------------------------------------------------------------
download_goes <- function(start = NULL, end = NULL, hours = NULL,
                          subset = TRUE, keep_full = FALSE,
                          dry_run = FALSE, overwrite = FALSE) {
  cfg <- load_config()
  g   <- cfg$goes
  out_root <- resolve_path(cfg, "goes")

  start <- as.Date(if (is.null(start)) g$start_date else start)
  end   <- as.Date(if (is.null(end))   g$end_date   else end)
  hours <- as.integer(if (is.null(hours)) unlist(g$hours_utc) else hours)
  bands <- unlist(g$bands)

  do_subset <- isTRUE(subset)
  days      <- seq(start, end, by = "day")
  n_expect  <- length(days) * length(hours) * length(bands)

  log_info(TAG, "Zeitraum %s bis %s", start, end)
  log_info(TAG, "Stunden UTC %s, Kanäle %s",
           paste(hours, collapse = ", "), paste(bands, collapse = ", "))
  log_info(TAG, "bis zu %d Szenen%s", n_expect,
           if (do_subset) " (mit Zuschnitt)" else
             sprintf(" -- ohne Zuschnitt grob %.0f GB!", n_expect * 0.25))

  n_ok <- 0L; n_miss <- 0L

  for (day in days) {
    day     <- as.Date(day, origin = "1970-01-01")
    bucket  <- pick_bucket(cfg, day)
    day_dir <- file.path(out_root, format(day, "%Y%m%d"))

    for (hour in hours) for (band in bands) {
      keys <- try(scene_keys(bucket, g$product, day, hour, band,
                             isTRUE(g$first_scan_only)), silent = TRUE)
      if (inherits(keys, "try-error") || !length(keys)) {
        log_warn(TAG, "keine Szene: %s %02d UTC %s (%s)", day, hour, band, bucket)
        n_miss <- n_miss + 1L
        next
      }

      for (key in keys) {
        fname   <- basename(key)
        dest    <- file.path(day_dir, fname)
        sub_dst <- sub("\\.nc$", "_subset.tif", dest)

        if (isTRUE(dry_run)) {
          log_info(TAG, "[dry-run] s3://%s/%s", bucket, key)
          n_ok <- n_ok + 1L
          next
        }
        if (!isTRUE(overwrite) && (file.exists(sub_dst) || file.exists(dest))) {
          log_info(TAG, "übersprungen (vorhanden): %s", fname)
          n_ok <- n_ok + 1L
          next
        }

        url <- sprintf("https://%s.s3.amazonaws.com/%s", bucket, key)
        ok <- try(download_file_safe(url, dest, overwrite = isTRUE(overwrite),
                                     timeout = 900L, tag = TAG), silent = TRUE)
        if (inherits(ok, "try-error") || !isTRUE(ok)) {
          n_miss <- n_miss + 1L
          next
        }

        if (do_subset) {
          size_mb <- file.size(dest) / 1e6
          res <- subset_scene(dest, cfg, keep_full = isTRUE(keep_full))
          if (!is.null(res)) {
            log_info(TAG, "  zugeschnitten: %6.1f MB -> %.2f MB",
                     size_mb, file.size(res) / 1e6)
          } else {
            log_warn(TAG, "  Zuschnitt fehlgeschlagen, Vollszene bleibt liegen")
          }
        }
        n_ok <- n_ok + 1L
      }
    }
  }

  write_citation(out_root,
"GOES-R ABI Level 2 Cloud and Moisture Imagery
=============================================

NOAA / NESDIS, bezogen über die NOAA Open Data Dissemination auf AWS.
  https://registry.opendata.aws/noaa-goes/

GOES-19 ist seit 7. April 2025 operationeller GOES-East auf 75,2 Grad West
und löste GOES-16 ab. Für frühere Termine wird GOES-16 verwendet.

Gemeinfrei (US-Regierungsdaten). Quellenangabe dennoch üblich.

Nebeldetektion: BTD = BT(C13, 10,3 um) - BT(C07, 3,9 um). Positive Werte
über einige Kelvin kennzeichnen nachts tiefe Wasserwolken. Bei darüber
liegender höherer Bewölkung versagt das Verfahren -- Bodenvalidierung
ist deshalb kein Zusatz, sondern Voraussetzung.")

  log_info(TAG, "fertig -- %d Szenen, %d fehlend/fehlerhaft, Ablage: %s",
           n_ok, n_miss, out_root)
  invisible(out_root)
}

# Standardlauf beim source(); Varianten danach direkt aufrufen, z. B.
#   download_goes(dry_run = TRUE)
#   download_goes(start = "2024-07-01", end = "2024-07-31", hours = 6)
.a <- parse_args(list(dry_run = FALSE, overwrite = FALSE, no_subset = FALSE,
                      keep_full = FALSE, start = NULL, end = NULL, hours = NULL))
download_goes(
  start     = if (!is.null(.a$start) && !isTRUE(.a$start)) as.character(.a$start) else NULL,
  end       = if (!is.null(.a$end)   && !isTRUE(.a$end))   as.character(.a$end)   else NULL,
  hours     = if (!is.null(.a$hours) && !isTRUE(.a$hours))
    as.integer(strsplit(as.character(.a$hours), "[,;: ]+")[[1]]) else NULL,
  subset    = !isTRUE(.a$no_subset),
  keep_full = isTRUE(.a$keep_full),
  dry_run   = isTRUE(.a$dry_run),
  overwrite = isTRUE(.a$overwrite))
