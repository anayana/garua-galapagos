# =============================================================================
# 05_app_assets.R
#
# Die App fuer shinylive selbstversorgend machen.
#
# ---------------------------------------------------------------------------
# WARUM
# ---------------------------------------------------------------------------
# shinylive kompiliert die App nach WebAssembly. Im Browser gibt es kein
# uebergeordnetes Verzeichnis -- alles, was die App liest, muss INNERHALB des
# app/-Ordners liegen. Beim lokalen Lauf greift sie auf ../data/processed zu,
# im Browser faellt sie auf app/data/processed zurueck. Dieses Skript fuellt
# genau das.
#
# Zweiter Zweck: Groesse. fog_daily.csv hat ~34.000 Zeilen und 3,2 MB. Jede
# Datei landet im WASM-Bundle und muss vom Betrachter geladen werden. Deshalb
# wird hier auf die tatsaechlich benutzten Spalten reduziert und als RDS
# (xz-komprimiert) geschrieben -- typisch ein Zehntel der CSV-Groesse.
#
# Aufruf (Arbeitsverzeichnis = Projektordner Galapagos):
#   source("analysis/05_app_assets.R")
#
# Danach:
#   shinylive::export("app", "docs")
#   httpuv::runStaticServer("docs")        lokal pruefen
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

TAG <- "assets"

# Spalten, die app.R tatsaechlich anfasst. Alles andere fliegt raus.
DAILY_KEEP <- c("station", "observation_date", "mean_air_temp", "humidity",
                "clouds", "precipitation", "dpd")

app_assets <- function(app_dir = "app") {
  cfg  <- load_config()
  src  <- cfg$paths$processed
  dest <- file.path(app_dir, "data", "processed")
  dir.create(dest, recursive = TRUE, showWarnings = FALSE)

  if (!dir.exists(src)) stop("Kein ", src, " -- erst analysis/01..04 laufen lassen.")

  # --- Tageswerte: Spalten reduzieren, als RDS -------------------------------
  f <- file.path(src, "fog_daily.csv")
  if (!file.exists(f)) stop("fog_daily.csv fehlt -- erst 02_fog_definition.R")
  d <- utils::read.csv(f, stringsAsFactors = FALSE)
  fehlt <- setdiff(DAILY_KEEP, names(d))
  if (length(fehlt)) stop("Spalten fehlen in fog_daily.csv: ",
                          paste(fehlt, collapse = ", "))
  d <- d[, DAILY_KEEP]
  d$observation_date <- as.Date(d$observation_date)
  saveRDS(d, file.path(dest, "fog_daily.rds"), compress = "xz")
  log_info(TAG, "fog_daily: %d Zeilen, %.2f MB CSV -> %.2f MB RDS",
           nrow(d), file.size(f) / 1e6,
           file.size(file.path(dest, "fog_daily.rds")) / 1e6)

  # --- Kleinkram unveraendert uebernehmen ------------------------------------
  for (nm in c("fog_annual.csv", "homogeneity_breaks.csv",
               "zonal_vegetation_dem_SantaCruz.csv")) {
    p <- file.path(src, nm)
    if (file.exists(p)) {
      file.copy(p, file.path(dest, nm), overwrite = TRUE)
      log_info(TAG, "kopiert: %-38s %6.1f kB", nm, file.size(p) / 1e3)
    } else {
      log_warn(TAG, "fehlt: %s", nm)
    }
  }

  # --- Kartenraster ----------------------------------------------------------
  p <- file.path(src, "maps_SantaCruz.rds")
  if (file.exists(p)) {
    m <- readRDS(p)
    m$lulc <- NULL          # nicht benutzt, spart Platz
    saveRDS(m, file.path(dest, "maps_SantaCruz.rds"), compress = "xz")
    log_info(TAG, "kopiert: %-38s %6.1f kB", "maps_SantaCruz.rds",
             file.size(file.path(dest, "maps_SantaCruz.rds")) / 1e3)
  } else {
    log_warn(TAG, "maps_SantaCruz.rds fehlt -- Karten-Tab bleibt leer.")
  }

  ges <- sum(file.size(list.files(dest, full.names = TRUE)))
  log_info(TAG, "Bundle-Daten gesamt: %.2f MB", ges / 1e6)
  if (ges > 20e6) {
    log_warn(TAG, "Ueber 20 MB -- der Betrachter laedt das beim ersten Aufruf.")
  }

  log_info(TAG, "naechster Schritt:")
  log_info(TAG, "  shinylive::export(\"%s\", \"docs\")", app_dir)
  log_info(TAG, "  httpuv::runStaticServer(\"docs\")")
  invisible(dest)
}

app_assets()
