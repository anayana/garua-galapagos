# =============================================================================
# 04_download_era5.R
#
# ERA5-Reanalyse für den Galápagos-Ausschnitt über den Copernicus Climate
# Data Store, per ecmwfr.
#
# Warum ERA5 in einem Nebelprojekt?
#   Die Garúa ist kein lokales Phänomen, sondern das Bodenprodukt einer
#   Passatinversion über kaltem Auftriebswasser. Ob sie in der Vegetations-
#   zone ankommt, entscheidet die Höhe der Wolkenuntergrenze relativ zum
#   Gelände. Beides lässt sich aus ERA5 diagnostizieren:
#
#     LTS = theta(700 hPa) - theta(1000 hPa)   Inversionsstärke
#     LCL aus T2m und Td2m                     Kondensationsniveau
#     blh                                      Grenzschichthöhe
#     lcc                                      tiefe Bewölkung
#
#   Damit wird aus "es war neblig" die Frage "unter welchen synoptischen
#   Bedingungen war es neblig" -- die Voraussetzung dafür, das Ganze auf
#   Klimaszenarien zu übertragen.
#
# Einrichtung (einmalig)
#   1. Kostenloser Account: https://cds.climate.copernicus.eu
#   2. Lizenzbedingungen des Datensatzes im Webinterface akzeptieren.
#      HÄUFIGSTE FEHLERQUELLE: sonst antwortet jede Anfrage mit 403,
#      ohne dass der Grund erkennbar wäre.
#   3. Schlüssel hinterlegen:
#        ecmwfr::wf_set_key(key = "<persönlicher Token>")
#      oder Umgebungsvariable CDSAPI_KEY setzen (auch für GitHub Actions).
#
# Wartezeit
#   CDS-Anfragen laufen über eine Warteschlange, ein Jahresrequest kann
#   Minuten bis Stunden dauern. Deshalb je Jahr und Datensatz eine eigene
#   Datei -- ein Abbruch kostet dann höchstens ein Jahr.
#
# Aufruf in der R-Konsole (Arbeitsverzeichnis = Projektordner Galapagos):
#   source("download/04_download_era5.R")           laeuft sofort
#   download_era5(years = 2023:2024)
#   download_era5(years = 2024, only = "pressure", focus = TRUE)
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

TAG <- "era5"
ALL_MONTHS <- sprintf("%02d", 1:12)
ALL_DAYS   <- sprintf("%02d", 1:31)

ensure_key <- function() {
  key <- Sys.getenv("CDSAPI_KEY", "")
  if (nzchar(key)) {
    ecmwfr::wf_set_key(key = key)
    log_info(TAG, "Schlüssel aus CDSAPI_KEY übernommen")
    return(invisible(TRUE))
  }
  ok <- tryCatch({ ecmwfr::wf_get_key(); TRUE }, error = function(e) FALSE)
  if (!ok) {
    log_err(TAG, paste("Kein CDS-Schlüssel gefunden. Entweder",
                       "ecmwfr::wf_set_key(key = \"...\") ausführen oder",
                       "CDSAPI_KEY als Umgebungsvariable setzen."))
    quit(status = 1L)
  }
  invisible(TRUE)
}

retrieve_year <- function(dataset, variables, year, times, area, dest,
                          levels = NULL, overwrite = FALSE) {
  if (file.exists(dest) && !overwrite) {
    log_info(TAG, "übersprungen (vorhanden): %s", basename(dest))
    return(invisible(dest))
  }

  request <- list(
    dataset_short_name = dataset,
    product_type    = "reanalysis",
    variable        = variables,
    year            = as.character(year),
    month           = ALL_MONTHS,
    day             = ALL_DAYS,
    time            = times,
    area            = area,          # [Nord, West, Süd, Ost]
    data_format     = "netcdf",
    download_format = "unarchived",
    target          = basename(dest)
  )
  if (!is.null(levels)) request$pressure_level <- levels

  log_info(TAG, "Anfrage %s %d -- Wartezeit in der CDS-Queue möglich ...", dataset, year)
  ecmwfr::wf_request(request = request, transfer = TRUE,
                     path = dirname(dest), verbose = FALSE)

  if (file.exists(dest)) {
    log_info(TAG, "geladen: %-40s %7.1f MB", basename(dest), file.size(dest) / 1e6)
  } else {
    log_warn(TAG, "Datei nach dem Transfer nicht gefunden: %s", dest)
  }
  invisible(dest)
}

download_era5 <- function(years = NULL, only = NULL,
                          focus = FALSE, overwrite = FALSE) {
  need_pkg("ecmwfr")

  cfg   <- load_config()
  out   <- resolve_path(cfg, "era5")
  area  <- cds_area_from_cfg(cfg, focus = isTRUE(focus))
  times <- unlist(cfg$era5$times)

  if (is.null(years)) years <- unlist(cfg$era5$years)
  years <- as.integer(years)

  log_info(TAG, "Ausschnitt [N, W, S, O] = %s", paste(area, collapse = ", "))
  log_info(TAG, "Jahre %s", paste(years, collapse = ", "))
  log_info(TAG, "Termine %s", paste(times, collapse = ", "))

  ensure_key()
  sl <- cfg$era5$single_levels
  pl <- cfg$era5$pressure_levels
  only <- if (is.null(only)) NA_character_ else as.character(only)

  for (year in years) {
    if (!identical(only, "pressure")) {
      retrieve_year(sl$dataset, unlist(sl$variables), year, times, area,
                    file.path(out, sprintf("era5_single_%d.nc", year)),
                    overwrite = isTRUE(overwrite))
    }
    if (!identical(only, "single")) {
      retrieve_year(pl$dataset, unlist(pl$variables), year, times, area,
                    file.path(out, sprintf("era5_plev_%d.nc", year)),
                    levels = unlist(pl$levels),
                    overwrite = isTRUE(overwrite))
    }
  }

  write_citation(out,
"ERA5-Reanalyse
==============

Hersbach, H. et al. (2023): ERA5 hourly data on single levels /
on pressure levels from 1940 to present. Copernicus Climate Change
Service (C3S) Climate Data Store (CDS).

Nutzungsbedingungen: Licence to use Copernicus Products.
Pflichthinweis: 'Generated using Copernicus Climate Change Service
information [Jahr]'. Weder die Europäische Kommission noch ECMWF haften
für die hier vorgenommene Weiterverarbeitung.")

  log_info(TAG, "fertig -- Ablage: %s", out)
  invisible(out)
}

# Standardlauf beim source(); Variante z. B.
#   download_era5(years = 2023:2024, only = "pressure")
.a <- parse_args(list(focus = FALSE, overwrite = FALSE, years = NULL, only = NULL))
download_era5(
  years = if (!is.null(.a$years) && !isTRUE(.a$years))
    as.integer(strsplit(as.character(.a$years), "[,;: ]+")[[1]]) else NULL,
  only  = if (!is.null(.a$only) && !isTRUE(.a$only)) as.character(.a$only) else NULL,
  focus = isTRUE(.a$focus), overwrite = isTRUE(.a$overwrite))
