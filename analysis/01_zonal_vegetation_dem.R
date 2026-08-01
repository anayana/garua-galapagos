# =============================================================================
# 01_zonal_vegetation_dem.R
#
# Zonale Statistik: Vegetationsklasse x Höhenband.
# Liefert die Kerngrafik von Pane 2 -- die Höhenverteilung der humiden
# Immergrün-Zone gegen die Invasiven- und die Landwirtschaftszone.
#
# ---------------------------------------------------------------------------
# WARUM RASTERBASIERT UND NICHT ÜBER ZENTROIDE
# ---------------------------------------------------------------------------
# Die naheliegende Abkürzung ist: je Polygon den Zentroid nehmen, dort die
# DEM-Höhe abfragen, die ganze Polygonfläche diesem Höhenband zuschlagen.
# Das ist schnell und in diesem Datensatz nachweislich falsch.
#
# Vergleich für "Evergreen Forest and Shrubland", Santa Cruz (ha):
#
#   Höhenband     Zentroid-Näherung     zonal (korrekt)
#   100-200 m              1.936              1.527
#   200-300 m                 82                176
#   500-600 m                161                842
#   600-700 m                 37              1.232
#   700-900 m              2.305                186
#
# Die Zentroid-Näherung verlegt 2.305 ha in die Gipfellage, wo tatsächlich
# nur 186 ha liegen, und übersieht den zweiten Schwerpunkt bei 600-700 m
# fast vollständig. Grund: ein Polygon, das von 550 bis 850 m reicht, hat
# seinen Zentroid bei ~700 m -- und wird komplett dorthin gebucht.
#
# Ein Polygon ist keine Punktmessung. Diese Datei existiert, damit die
# Abkürzung nicht doch irgendwann genommen wird.
#
# ---------------------------------------------------------------------------
# VORAUSSETZUNG
# ---------------------------------------------------------------------------
#   download/03_download_dem.R          -> data/raw/dem/*.tif
#   download/06_download_vegetation.R   -> data/raw/vegetation/*.gpkg
#
# Das Vegetations-GPKG muss GEOMETRISCH GECLIPPT sein. Der Attributfilter
# Isla reicht nicht -- siehe Kopf von 06_download_vegetation.R. Ungeclippt
# sind alle Zahlen hier bis zu 41 % zu hoch.
#
# Aufruf (Arbeitsverzeichnis = Projektordner Galapagos):
#   source("analysis/01_zonal_vegetation_dem.R")
#   zonal_vegetation_dem(plot = TRUE)
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

TAG <- "zonal"

# -----------------------------------------------------------------------------
zonal_vegetation_dem <- function(island = "SantaCruz", plot = FALSE) {
  need_pkg("sf", "terra")

  cfg <- load_config()
  v   <- cfg$vegetation

  veg_path <- file.path(resolve_path(cfg, "vegetation"),
                        sprintf("ecosistemas_nativos_2016_%s.gpkg", island))
  dem_dir  <- resolve_path(cfg, "dem")
  dem_path <- list.files(dem_dir, pattern = "\\.tif$", full.names = TRUE)[1]

  if (!file.exists(veg_path)) stop("Vegetationskarte fehlt: ", veg_path)
  if (is.na(dem_path))        stop("Kein DEM in ", dem_dir)

  veg <- sf::st_read(veg_path, quiet = TRUE)
  dem <- terra::rast(dem_path)
  log_info(TAG, "Vegetation: %d Polygone | DEM: %s", nrow(veg),
           paste(dim(dem)[1:2], collapse = " x "))

  # --- Plausibilitätswächter -------------------------------------------------
  # Ungeclippte Bestandsdateien sind der wahrscheinlichste Fehler an dieser
  # Stelle. Santa Cruz + Baltra misst ~100.700 ha; alles deutlich darüber
  # heisst, dass Polygone anderer Inseln mitlaufen.
  ha_total <- sum(as.numeric(sf::st_area(sf::st_transform(veg, v$target_crs)))) / 1e4
  if (ha_total > 115000) {
    stop(sprintf(paste("Vegetationskarte umfasst %.0f ha -- Santa Cruz misst ~100.700 ha.",
                       "\nDie Datei ist offenbar nicht geometrisch geclippt.",
                       "\nAbhilfe: download_vegetation(overwrite = TRUE)"), ha_total))
  }
  log_info(TAG, "Flächenprüfung: %.0f ha -- plausibel", ha_total)

  # --- DEM auf den Vegetationsausschnitt begrenzen ----------------------------
  dem <- terra::crop(dem, terra::ext(terra::vect(sf::st_transform(veg, sf::st_crs(dem)))))

  # --- Rasterisieren ----------------------------------------------------------
  # Die Klassen auf das DEM-Gitter bringen, statt das DEM je Polygon zu sampeln:
  # so bekommt jede Rasterzelle genau eine Klasse und genau eine Höhe.
  vv  <- terra::vect(sf::st_transform(veg, terra::crs(dem)))
  lev <- sort(unique(veg[["Ecosis_Nat"]]))
  vv$.cid <- match(vv$Ecosis_Nat, lev)
  cls <- terra::rasterize(vv, dem, field = ".cid")

  # --- Höhenbänder ------------------------------------------------------------
  br  <- unlist(cfg$vegetation$elev_breaks)
  if (is.null(br)) br <- c(0, 100, 200, 300, 400, 500, 600, 700, 900)

  # others = NA ist hier NICHT optional.
  #
  # terra::classify() lässt Zellen, die in keinen Bereich der Matrix fallen,
  # standardmässig UNVERÄNDERT stehen -- es setzt sie nicht auf NA. Das DEM
  # enthält Küstenzellen mit negativen Höhen (-1 m und tiefer). Ohne others = NA
  # überleben die als Rohwert und werden weiter unten zu negativen Indizes
  # in br[...], was R mit
  #   "nur Nullen dürfen mit negativen Indizes gemischt werden"
  # quittiert. Fehler beobachtet am 2026-08-01.
  bnd <- terra::classify(dem,
                         cbind(br[-length(br)], br[-1], seq_len(length(br) - 1)),
                         include.lowest = TRUE, others = NA)

  # --- Zellfläche: am Äquator zwar fast konstant, aber nicht exakt ------------
  # cellSize() rechnet die tatsächliche Fläche je Zelle, unabhängig davon ob
  # das DEM geographisch oder metrisch vorliegt.
  ar <- terra::cellSize(dem, unit = "ha")

  st <- c(cls, bnd, ar)
  names(st) <- c("cid", "band", "ha")
  df <- terra::as.data.frame(st, na.rm = TRUE)
  df <- df[is.finite(df$cid) & is.finite(df$band), ]

  agg <- stats::aggregate(ha ~ cid + band, data = df, FUN = sum)

  # Sicherheitsnetz: nach others = NA dürfen hier nur noch 1..length(br)-1
  # stehen. Wenn doch nicht, lieber laut abbrechen als still falsch rechnen.
  ok <- agg$band %in% seq_len(length(br) - 1L)
  if (!all(ok)) {
    stop(sprintf("Unerwartete Höhenband-Codes: %s -- classify() prüfen.",
                 paste(unique(agg$band[!ok]), collapse = ", ")))
  }

  agg$klasse <- lev[agg$cid]
  agg$band   <- sprintf("%d-%d m", br[agg$band], br[agg$band + 1L])
  agg <- agg[, c("klasse", "band", "ha")]

  # --- Ausgabe ----------------------------------------------------------------
  ord  <- sprintf("%d-%d m", br[-length(br)], br[-1])
  # xtabs statt reshape: füllt fehlende Kombinationen von selbst mit 0 und
  # kommt ohne Spaltennamen-Kosmetik aus.
  wide <- as.data.frame.matrix(stats::xtabs(ha ~ band + klasse, data = agg))
  wide <- wide[match(ord, rownames(wide)), , drop = FALSE]
  wide[is.na(wide)] <- 0
  wide <- cbind(band = ord, wide)

  foc  <- unlist(v$focus_classes)
  show <- intersect(c(foc, "Humid Tallgrass"), names(wide))
  tbl  <- wide[, c("band", show), drop = FALSE]
  # nicht format(digits = 0) -- das ist kein gültiges Argument und wirft
  # "invalid 'digits' argument". Ganzzahlig runden reicht hier ohnehin.
  tbl[show] <- lapply(tbl[show], function(x) round(as.numeric(x)))
  log_info(TAG, "Zonale Statistik (ha je Höhenband):")
  print(tbl, row.names = FALSE)

  out_dir <- file.path(cfg$paths$processed)
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  dest <- file.path(out_dir, sprintf("zonal_vegetation_dem_%s.csv", island))
  utils::write.csv(agg, dest, row.names = FALSE)
  log_info(TAG, "geschrieben: %s", dest)

  # Kontrolle: die zonale Summe muss die Vektorfläche treffen. Abweichungen
  # über ~1 % sind Rasterisierungsartefakte an schmalen Polygonen -- oder ein
  # Fehler. In beiden Fällen will man es wissen.
  dev <- abs(sum(agg$ha) - ha_total) / ha_total
  log_info(TAG, "zonal %.0f ha vs. vektoriell %.0f ha (%.2f %% Abweichung)",
           sum(agg$ha), ha_total, 100 * dev)
  if (dev > 0.01) log_warn(TAG, "Abweichung > 1 %% -- schmale Polygone prüfen")

  if (isTRUE(plot)) {
    op <- graphics::par(mar = c(4, 9, 3, 1))
    on.exit(graphics::par(op), add = TRUE)
    m <- t(as.matrix(wide[, intersect(foc, names(wide))]))
    colnames(m) <- wide$band
    graphics::barplot(m, beside = TRUE, horiz = TRUE, las = 1,
                      xlab = "Fläche (ha)",
                      main = "Vegetationsklassen über Höhe -- Santa Cruz",
                      legend.text = rownames(m),
                      args.legend = list(x = "bottomright", cex = 0.8, bty = "n"))
  }

  invisible(agg)
}

zonal_vegetation_dem()
