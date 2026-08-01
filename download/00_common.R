# =============================================================================
# 00_common.R  --  gemeinsame Helfer der Galápagos-Nebel-Downloadpipeline
#
# Wird von allen 0x_*.R per source() eingebunden. Enthält Konfigurations-
# zugriff, Pfadauflösung, robusten Download und einheitliches Logging.
# =============================================================================

suppressPackageStartupMessages({
  library(yaml)
})

# -----------------------------------------------------------------------------
# Projektwurzel
# -----------------------------------------------------------------------------
# Funktioniert sowohl bei Rscript download/01_....R als auch bei
# source() aus dem Projektordner heraus.
find_root <- function() {
  candidates <- c(getwd(), file.path(getwd(), ".."), dirname(getwd()))
  for (p in candidates) {
    if (file.exists(file.path(p, "config.yml"))) return(normalizePath(p))
  }
  stop("config.yml nicht gefunden. Skript aus dem Projektordner heraus starten.")
}

ROOT <- find_root()

# -----------------------------------------------------------------------------
# Logging
# -----------------------------------------------------------------------------
.log <- function(level, tag, fmt, ...) {
  msg <- sprintf(fmt, ...)
  cat(sprintf("%s  %-7s %-10s %s\n",
              format(Sys.time(), "%H:%M:%S"), level, tag, msg))
  utils::flush.console()
}

log_info <- function(tag, fmt, ...) .log("INFO",    tag, fmt, ...)
log_warn <- function(tag, fmt, ...) .log("WARNUNG", tag, fmt, ...)
log_err  <- function(tag, fmt, ...) .log("FEHLER",  tag, fmt, ...)

# -----------------------------------------------------------------------------
# Konfiguration
# -----------------------------------------------------------------------------
load_config <- function(path = file.path(ROOT, "config.yml")) {
  if (!file.exists(path)) stop("config.yml nicht gefunden unter ", path)
  yaml::read_yaml(path)
}

resolve_path <- function(cfg, key) {
  out <- file.path(ROOT, cfg$paths[[key]])
  dir.create(out, showWarnings = FALSE, recursive = TRUE)
  normalizePath(out)
}

# -----------------------------------------------------------------------------
# Download
# -----------------------------------------------------------------------------
# Lädt in eine .part-Datei und benennt erst nach vollständigem Transfer um.
# Ein Abbruch hinterlässt damit keine halbe Datei, die beim nächsten Lauf
# fälschlich für fertig gehalten wird.
download_file_safe <- function(url, dest,
                               overwrite = FALSE,
                               retries   = 3L,
                               timeout   = 300L,
                               allow_404 = FALSE,
                               tag       = "download") {

  dir.create(dirname(dest), showWarnings = FALSE, recursive = TRUE)

  if (file.exists(dest) && !overwrite) {
    log_info(tag, "übersprungen (vorhanden): %s", basename(dest))
    return(TRUE)
  }

  tmp <- paste0(dest, ".part")
  old_timeout <- getOption("timeout")
  options(timeout = timeout)
  on.exit(options(timeout = old_timeout), add = TRUE)

  for (attempt in seq_len(retries)) {
    ok <- tryCatch({
      if (requireNamespace("curl", quietly = TRUE)) {
        curl::curl_download(url, tmp, quiet = TRUE, mode = "wb")
      } else {
        utils::download.file(url, tmp, mode = "wb", quiet = TRUE)
      }
      TRUE
    }, error = function(e) e)

    if (isTRUE(ok)) {
      file.rename(tmp, dest)
      log_info(tag, "geladen: %-45s %8.1f MB",
               basename(dest), file.size(dest) / 1e6)
      return(TRUE)
    }

    unlink(tmp)
    msg <- conditionMessage(ok)

    if (allow_404 && grepl("404", msg)) {
      return(FALSE)
    }
    if (attempt == retries) {
      log_err(tag, "fehlgeschlagen nach %d Versuchen: %s (%s)", retries, url, msg)
      if (allow_404) return(FALSE)
      stop(msg)
    }
    wait <- 2^attempt
    log_warn(tag, "Versuch %d/%d fehlgeschlagen (%s) -- warte %ds",
             attempt, retries, msg, wait)
    Sys.sleep(wait)
  }
  FALSE
}

write_citation <- function(dest_dir, text, filename = "CITATION.txt") {
  writeLines(trimws(text), file.path(dest_dir, filename), useBytes = TRUE)
}

# -----------------------------------------------------------------------------
# Geometrie
# -----------------------------------------------------------------------------
# Gibt c(lon_min, lat_min, lon_max, lat_max) zurück.
bbox_from_cfg <- function(cfg, focus = FALSE) {
  reg <- if (focus) cfg$region$focus else cfg$region
  c(lon_min = reg$lon_min, lat_min = reg$lat_min,
    lon_max = reg$lon_max, lat_max = reg$lat_max)
}

# terra-Extent aus der Konfiguration
ext_from_cfg <- function(cfg, focus = FALSE) {
  b <- bbox_from_cfg(cfg, focus)
  terra::ext(b[["lon_min"]], b[["lon_max"]], b[["lat_min"]], b[["lat_max"]])
}

# Der Copernicus CDS erwartet [Nord, West, Süd, Ost] -- klassische Fehlerquelle.
cds_area_from_cfg <- function(cfg, focus = FALSE) {
  b <- bbox_from_cfg(cfg, focus)
  c(b[["lat_max"]], b[["lon_min"]], b[["lat_min"]], b[["lon_max"]])
}

# -----------------------------------------------------------------------------
# Kleine Helfer
# -----------------------------------------------------------------------------
need_pkg <- function(...) {
  pkgs <- c(...)
  missing <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing)) {
    stop("Fehlende Pakete: ", paste(missing, collapse = ", "),
         "\n  ->  install.packages(c(",
         paste0('"', missing, '"', collapse = ", "), "))", call. = FALSE)
  }
  invisible(TRUE)
}

parse_args <- function(defaults = list()) {
  out <- defaults

  # 1) Werte, die download_all() gesetzt hat. Beim Sourcen aus der R-Konsole
  #    gibt es keine Kommandozeile -- das ist der Weg, trotzdem Optionen
  #    an die Einzelskripte durchzureichen.
  opt <- getOption("galapagos.args")
  if (is.list(opt)) for (k in names(opt)) out[[k]] <- opt[[k]]

  # 2) Kommandozeilenflags, falls doch jemand per Rscript startet
  args <- commandArgs(trailingOnly = TRUE)
  for (a in args) {
    if (grepl("^--[a-zA-Z0-9-]+=", a)) {
      kv <- sub("^--", "", a)
      key <- sub("=.*$", "", kv)
      val <- sub("^[^=]*=", "", kv)
      out[[gsub("-", "_", key)]] <- val
    } else if (grepl("^--", a)) {
      out[[gsub("-", "_", sub("^--", "", a))]] <- TRUE
    }
  }
  out
}

# -----------------------------------------------------------------------------
# Sourcen aus der R-Konsole
# -----------------------------------------------------------------------------
# Jedes Skript definiert eine Funktion mit normalen R-Argumenten und ruft sie
# am Ende einmal mit den Standardwerten auf. Damit gilt:
#
#   source("download/06_download_vegetation.R")   laeuft sofort durch
#   download_vegetation(all_islands = TRUE)       Variante danach aufrufen
#
# Wer lieber im Terminal arbeitet, kann dieselben Skripte mit Rscript und
# --flags starten -- parse_args() liest sie aus, ist in der Konsole aber leer.
source_sibling <- function(file) {
  base <- tryCatch(this_dir(), error = function(e) getwd())
  source(file.path(base, file))
}
