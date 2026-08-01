# =============================================================================
# 01_download_cdf_stations.R
#
# Lädt die Tagesklimareihen der Charles Darwin Foundation (dataZone):
#
#     Puerto Ayora     2 m ü. NN, seit 1965  -> trockenes Tiefland
#     Bellavista     223 m ü. NN, seit 1987  -> Garúa-Hochland
#
# Der Höhenkontrast dieser beiden Stationen auf Santa Cruz ist der Kern der
# Nebelklimatologie: gleiche Insel, ~7 km Abstand, 221 Höhenmeter, völlig
# verschiedenes Feuchteregime.
#
# Quelle:  https://datazone.darwinfoundation.org/en/climate
# Lizenz:  CC BY-NC-SA 4.0 -- Namensnennung Pflicht, keine kommerzielle Nutzung
#
# Spalten der CSV (geprüft August 2026):
#   observation_date, min_air_temp, max_air_temp, mean_air_temp,
#   sea_temp, humidity, precipitation, sunshine_hours, clouds
#
# `clouds` ist Bewölkung in Achteln (Okta 0-8) aus visueller Beobachtung.
# Zusammen mit humidity und precipitation ergibt das den plausibelsten
# Garúa-Proxy, den diese Reihe hergibt -- ganz ohne Satellit.
#
# Aufruf in der R-Konsole (Arbeitsverzeichnis = Projektordner Galapagos):
#   source("download/01_download_cdf_stations.R")   laeuft sofort
#   download_stations(with_raw = TRUE, overwrite = TRUE)
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

TAG <- "cdf"
NUMERIC_COLS <- c("min_air_temp", "max_air_temp", "mean_air_temp", "sea_temp",
                  "humidity", "precipitation", "sunshine_hours", "clouds")

# -----------------------------------------------------------------------------
# Qualitätsbericht direkt nach dem Download
# -----------------------------------------------------------------------------
# Bewusst hier und nicht erst in der Auswertung: Wer eine Zeitreihe lädt, ohne
# einmal hinzusehen, baut die Fehler später ins Modell ein.
inspect_csv <- function(path) {
  need_pkg("readr")
  df <- suppressWarnings(readr::read_csv(path, show_col_types = FALSE,
                                         progress = FALSE))
  if (!nrow(df)) {
    log_warn(TAG, "%s ist leer", basename(path))
    return(invisible(NULL))
  }

  d <- as.Date(df$observation_date)
  log_info(TAG, "  %s: %d Tage, %s bis %s", basename(path), nrow(df),
           min(d, na.rm = TRUE), max(d, na.rm = TRUE))

  for (col in intersect(NUMERIC_COLS, names(df))) {
    pct <- 100 * mean(is.na(df[[col]]))
    flag <- if (pct > 95) "  <-- Spalte praktisch leer" else ""
    log_info(TAG, "      %-16s %5.1f %% fehlend%s", col, pct, flag)
  }

  if (all(c("min_air_temp", "max_air_temp") %in% names(df))) {
    rev_n <- sum(df$min_air_temp > df$max_air_temp, na.rm = TRUE)
    if (rev_n > 0) {
      log_warn(TAG, paste("      %d Tage mit min_air_temp > max_air_temp",
                          "(Digitalisierungsfehler -- flaggen, nicht löschen)"),
               rev_n)
    }
  }

  # Lückenstruktur: nicht nur wie viel fehlt, sondern ob am Stück
  full <- seq(min(d, na.rm = TRUE), max(d, na.rm = TRUE), by = "day")
  gaps <- sort(as.Date(setdiff(as.character(full), as.character(d))))
  if (length(gaps)) {
    n_runs <- sum(c(TRUE, as.numeric(diff(gaps)) != 1))
    log_info(TAG, "      %d fehlende Kalendertage in %d zusammenhängenden Lücken",
             length(gaps), n_runs)
  }
  invisible(df)
}

# -----------------------------------------------------------------------------
download_stations <- function(overwrite = FALSE, with_raw = FALSE, inspect = TRUE) {
  cfg  <- load_config()
  out  <- resolve_path(cfg, "stations")
  base <- sub("/$", "", cfg$cdf$base_url)

  for (st in cfg$stations) {
    log_info(TAG, "%s (%s, %d m ü. NN)", st$label, st$zone, as.integer(st$elevation_m))

    dest <- file.path(out, sprintf("climate_%s.csv", st$slug))
    download_file_safe(sprintf("%s/climate_%s.csv", base, st$slug), dest,
                       overwrite = isTRUE(overwrite), tag = TAG)

    if (isTRUE(inspect)) inspect_csv(dest)

    if (isTRUE(with_raw) && !is.null(st$raw_xls)) {
      download_file_safe(sprintf("%s/%s", base, st$raw_xls),
                         file.path(out, st$raw_xls),
                         overwrite = isTRUE(overwrite),
                         allow_404 = TRUE, tag = TAG)
    }
  }

  write_citation(out, sprintf(
"Galápagos-Klimadaten der Bodenstationen
=======================================

%s

Lizenz: %s
        https://creativecommons.org/licenses/by-nc-sa/4.0/

Bedingungen: Namensnennung, keine kommerzielle Nutzung, Weitergabe unter
gleichen Bedingungen. Für eine öffentlich erreichbare Shiny-App heisst das:
Quelle sichtbar im Interface nennen.

Bekannte Einschränkungen laut Betreiber:
  - Puerto Ayora: Minimumtemperaturen 2020-2021 gerätebedingt fehlerhaft.
  - Bellavista: Station Ende 2015 um ca. 380 m nach NNW verlegt.
    Bruchstelle in der Reihe -- bei Trendanalysen zwingend berücksichtigen.
  - Beide: Werte wurden für den dataZone-Viewer durch die Digitalisierenden
    angepasst. Unbereinigte Rohdaten separat als XLS, zu holen mit
    download_stations(with_raw = TRUE)",
    cfg$cdf$citation, cfg$cdf$license))

  log_info(TAG, "fertig -- Ablage: %s", out)
  invisible(out)
}

# Standardlauf beim source(); Varianten danach direkt aufrufen, z. B.
#   download_stations(with_raw = TRUE, overwrite = TRUE)
.a <- parse_args(list(overwrite = FALSE, with_raw = FALSE, no_inspect = FALSE))
download_stations(overwrite = isTRUE(.a$overwrite),
                  with_raw  = isTRUE(.a$with_raw),
                  inspect   = !isTRUE(.a$no_inspect))
