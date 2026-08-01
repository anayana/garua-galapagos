# =============================================================================
# download_all.R
#
# Startet die Downloadschritte in sinnvoller Reihenfolge: erst das Kleine und
# Sichere (Stationen, ENSO, DEM, Vegetation), dann das Grosse und
# Kontenpflichtige (ERA5, GOES).
#
# In der R-Konsole, Arbeitsverzeichnis = Projektordner Galapagos:
#
#   source("download/download_all.R")                    # die schnellen vier
#   download_all(with_era5 = TRUE)                       # zusätzlich ERA5
#   download_all(with_goes = TRUE)                       # zusätzlich GOES
#   download_all(all = TRUE, overwrite = TRUE)
#   download_all(with_analysis = FALSE)                  # nur laden, nicht rechnen
#
# Im Anschluss an die Downloads läuft standardmässig analysis/01_zonal_vegetation_dem.R.
#
# Jeder Schritt läuft in seinem eigenen tryCatch. Ein Fehler bricht die Kette
# nicht ab, sondern wird am Ende zusammengefasst -- praktisch, wenn etwa nur
# der CDS-Schlüssel fehlt.
# =============================================================================

this_dir <- function() {
  a <- commandArgs(trailingOnly = FALSE)
  m <- grep("^--file=", a, value = TRUE)
  if (length(m)) return(dirname(normalizePath(sub("^--file=", "", m[1]))))
  fr <- sys.frames()
  if (length(fr) && !is.null(fr[[1]]$ofile)) return(dirname(normalizePath(fr[[1]]$ofile)))
  getwd()
}
HERE <- this_dir()
source(file.path(HERE, "00_common.R"))

TAG <- "all"

run_step <- function(label, script, dir = HERE) {
  log_info(TAG, "--- %s", label)
  tryCatch({
    # bewusst in den globalen Env: danach stehen download_stations(),
    # download_vegetation() usw. für eigene Aufrufe zur Verfügung
    source(file.path(dir, script))
    TRUE
  }, error = function(e) {
    log_err(TAG, "%s: %s", script, conditionMessage(e))
    FALSE
  })
}

download_all <- function(with_era5 = FALSE, with_goes = FALSE,
                         all = FALSE, overwrite = FALSE,
                         with_analysis = TRUE) {

  # Die Einzelskripte lesen ihre Optionen über parse_args(). Beim Sourcen aus
  # der Konsole gibt es keine Kommandozeile -- deshalb der Umweg über eine
  # Option, die parse_args() in 00_common.R ausliest.
  old <- options(galapagos.args = list(overwrite = isTRUE(overwrite)))
  on.exit(options(old), add = TRUE)

  results <- list()
  results[["Stationen (CDF)"]]         <- run_step("Stationen (CDF)",
                                                   "01_download_cdf_stations.R")
  results[["ENSO (NOAA)"]]             <- run_step("ENSO (NOAA)",
                                                   "02_download_enso.R")
  results[["DEM (Copernicus GLO-30)"]] <- run_step("DEM (Copernicus GLO-30)",
                                                   "03_download_dem.R")
  results[["Vegetation (USFQ)"]]       <- run_step("Vegetation (USFQ)",
                                                   "06_download_vegetation.R")

  if (isTRUE(with_era5) || isTRUE(all))
    results[["ERA5 (CDS)"]] <- run_step("ERA5 (CDS)", "04_download_era5.R")

  if (isTRUE(with_goes) || isTRUE(all))
    results[["GOES ABI (AWS)"]] <- run_step("GOES ABI (AWS)", "05_download_goes.R")

  # Auswertung direkt hinterher -- braucht DEM (03) und Vegetation (06),
  # die beide oben gelaufen sind.
  if (isTRUE(with_analysis)) {
    ana <- file.path(dirname(HERE), "analysis")
    results[["Zonale Statistik"]] <- run_step("Zonale Statistik (Pane 2)",
                                              "01_zonal_vegetation_dem.R", dir = ana)
  }

  cat(strrep("=", 58), "\n")
  for (nm in names(results)) {
    cat(sprintf("%-34s %s\n", nm, if (isTRUE(results[[nm]])) "ok" else "FEHLER"))
  }
  cat(strrep("=", 58), "\n")

  invisible(results)
}

# Standardlauf beim source()
.a <- parse_args(list(with_era5 = FALSE, with_goes = FALSE,
                      all = FALSE, overwrite = FALSE, with_analysis = TRUE))
download_all(with_era5     = isTRUE(.a$with_era5),
             with_goes     = isTRUE(.a$with_goes),
             all           = isTRUE(.a$all),
             overwrite     = isTRUE(.a$overwrite),
             with_analysis = isTRUE(.a$with_analysis))
