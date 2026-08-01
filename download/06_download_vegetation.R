# =============================================================================
# 06_download_vegetation.R
#
# Vegetationskarte Galápagos v.2016 (A_ECOSISTEMAS_NATIVOS_2016) vom
# öffentlichen ArcGIS-FeatureServer des Instituto de Geografía der
# Universidad San Francisco de Quito. Kein Login.
#
# Warum diese Karte das Wald-Modul überhaupt möglich macht:
#   Sie enthält die Klasse "Evergreen Forest and Shrubland" -- das ist die
#   Scalesia-Zone -- und, davon getrennt, eine Klasse "Invasive Species".
#   Erst dieser Gegensatz erlaubt die ehrliche Aussage: die akute Bedrohung
#   von Scalesia pedunculata ist heute die Invasion (Rubus niveus,
#   Cestrum auriculatum, Tradescantia fluminensis), der Nebelrückgang ist
#   der langsamere, zweite Stressor auf einem bereits geschwächten Rest.
#
# ---------------------------------------------------------------------------
# DIE FALLE, DERETWEGEN DIESES SKRIPT MEHR IST ALS EIN st_read()
# ---------------------------------------------------------------------------
#   Der Dienst führt 20106 Polygone, sein maxRecordCount liegt aber bei 2000.
#   Eine einzelne Abfrage liefert stillschweigend die ersten 2000 Features --
#   ohne Fehler, ohne Warnung. Eine Flächenbilanz darauf wäre stumm falsch,
#   und zwar so, dass es niemandem auffällt.
#
#   Deshalb: Paginierung über resultOffset, danach Abgleich der geladenen
#   Feature-Zahl gegen returnCountOnly. Stimmt das nicht überein, bricht das
#   Skript ab.
#
# Geprüft am 2026-08-01:
#   20106 Features gesamt, 15 Klassen, Geometrie EPSG:3857,
#   Felder FID / OBJECTID / Ecosis_Nat / Isla / Shape_Leng / Shape_Area / Area_Ha
#
#   Santa Cruz allein: 1437 Features -- die passen in eine Seite. Beim
#   Standardlauf sieht man deshalb nur "Seite 1" und wundert sich vielleicht
#   über den Aufwand. Er zahlt sich bei all_islands = TRUE aus (11 Seiten),
#   und die Vollständigkeitsprüfung greift in beiden Fällen.
#
# Grenze, die auch in der App stehen muss:
#   30 m Auflösung, Maßstab 1:60.000, Landsat-8/OLI-Klassifikation.
#   Los Gemelos (~140 ha) ist damit rund 15 Pixel breit. Tauglich für Zonen-
#   und Flächenanteilsaussagen, NICHT für Bestandes- oder Einzelbaumebene.
#
# Aufruf in der R-Konsole (Arbeitsverzeichnis = Projektordner Galapagos):
#   source("download/06_download_vegetation.R")     laeuft sofort (Santa Cruz)
#   download_vegetation(all_islands = TRUE)         ganzes Archipel
#   download_vegetation(overwrite = TRUE)
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

TAG <- "vegetation"

# -----------------------------------------------------------------------------
# ArcGIS-REST-Helfer
# -----------------------------------------------------------------------------
esri_query_url <- function(service_url, params) {
  req <- httr2::request(paste0(sub("/$", "", service_url), "/query"))
  req <- httr2::req_url_query(req, !!!params)
  req <- httr2::req_retry(req, max_tries = 3)
  httr2::req_timeout(req, 120)
}

esri_count <- function(service_url, where) {
  resp <- httr2::req_perform(esri_query_url(service_url, list(
    where = where, returnCountOnly = "true", f = "json"
  )))
  as.integer(jsonlite::fromJSON(httr2::resp_body_string(resp))$count)
}

# Eine Seite als sf einlesen. sf::st_read verdaut den GeoJSON-Text direkt.
esri_page <- function(service_url, where, fields, offset, page_size) {
  resp <- httr2::req_perform(esri_query_url(service_url, list(
    where              = where,
    outFields          = paste(fields, collapse = ","),
    returnGeometry     = "true",
    outSR              = "4326",
    resultOffset       = as.character(offset),
    resultRecordCount  = as.character(page_size),
    f                  = "geojson"
  )))
  txt <- httr2::resp_body_string(resp)

  # Der Dienst antwortet auf Fehler mit Status 200 und einem error-Objekt
  if (grepl('"error"', substr(txt, 1, 400), fixed = TRUE)) {
    stop("FeatureServer meldet einen Fehler: ", substr(txt, 1, 300))
  }

  # check_ring_dir = TRUE: ArcGIS exportiert GeoJSON mit ESRI-Ringorientierung
  # (äussere Ringe im Uhrzeigersinn, Löcher gegen den Uhrzeigersinn -- umgekehrt
  # zur OGC-Konvention). Vorsichtshalber gesetzt; es ändert an diesem Datensatz
  # allerdings nichts, siehe die Notiz zur Datenqualität weiter unten.
  sf::st_read(txt, quiet = TRUE, check_ring_dir = TRUE)
}

fetch_all <- function(service_url, where, fields, page_size) {
  expected <- esri_count(service_url, where)
  log_info(TAG, "Dienst meldet %d Features für where = %s", expected, where)

  if (expected == 0L) stop("Filter liefert null Features -- where-Ausdruck prüfen.")

  pages  <- list()
  offset <- 0L
  n_page <- 0L

  # Sicherheitsnetz gegen Endlosschleifen bei kaputter Paginierung
  max_pages <- ceiling(expected / page_size) + 2L

  while (offset < expected && n_page < max_pages) {
    pg <- esri_page(service_url, where, fields, offset, page_size)
    if (!nrow(pg)) break
    n_page <- n_page + 1L
    pages[[n_page]] <- pg
    offset <- offset + nrow(pg)
    log_info(TAG, "  Seite %2d: %5d Features  (kumuliert %5d / %d)",
             n_page, nrow(pg), offset, expected)
  }

  out <- do.call(rbind, pages)

  # Der eigentliche Zweck der Übung: Vollständigkeit beweisen, nicht annehmen.
  if (nrow(out) != expected) {
    stop(sprintf(paste("Paginierung unvollständig: %d von %d Features geladen.",
                       "Ergebnis NICHT verwenden."), nrow(out), expected))
  }
  log_info(TAG, "vollständig: %d Features in %d Seiten", nrow(out), n_page)
  out
}

# -----------------------------------------------------------------------------
# Flächenbilanz
# -----------------------------------------------------------------------------
# BEFUND VOM 2026-08-01, korrigiert am selben Tag -- bitte vollständig lesen.
#
# ERSTE, FALSCHE DIAGNOSE
#   Summe Area_Ha (Attribut)    100.907 ha
#   Summe st_area (Geometrie)   141.836 ha
#   Santa Cruz + Baltra real   ~100.700 ha
#   Schluss damals: "die Klassen überlappen sich, vor Flächenanteilen mit
#   st_intersection auflösen". Das war falsch.
#
# NACHPRÜFUNG -- die Überlappung ist exakt null
#   Summe der Einzelpolygone == Union, klassenintern wie klassenübergreifend.
#   Evergreen Forest and Shrubland x Invasive Species = 0,0 ha.
#   Die Karte IST eine überschneidungsfreie Aufteilung. Es braucht weder eine
#   Prioritätsregel noch st_intersection zwischen den Klassen.
#
# DIE ECHTE URSACHE: der Attributfilter Isla
#   Alle 1437 Polygone mit Isla='Santa Cruz' tragen diesen Wert -- ihre
#   Geometrien spannen aber -91,36..-89,25 Länge und -1,00..+0,59 Breite,
#   also den halben Archipel. 225 Polygone (44.128 ha) liegen ausserhalb.
#   Das grösste "Santa-Cruz"-Polygon ist ein Deciduous Forest mit 57.119 ha;
#   die Insel selbst misst ~98.600 ha.
#   Nach geometrischem Clip: 100.695 ha, 1219 Polygone, Überlappung 0 ha.
#
# WAS BLEIBT: Area_Ha ist polygonweise unbrauchbar
#   Ein Agricultural-Lands-Polygon führt 0,65 ha im Attribut und misst
#   8.342 ha. Dass die Attributsumme zufällig nahe der Inselfläche lag, war
#   Koinzidenz -- kein Hinweis auf eine frühere, bereinigte Fassung.
#   REGEL: Flächen immer aus der Geometrie, Area_Ha nur als Kontrastwert.
#
# Der Bericht meldet deshalb beide Zahlen nebeneinander, prüft die
# Überlappung explizit und markiert die Polygone, bei denen Attribut und
# Geometrie auseinanderlaufen. Er wählt bewusst keinen Wert für Sie aus.
area_report <- function(veg, target_crs) {
  veg_m <- sf::st_transform(veg, target_crs)

  # Ungültige Geometrien (Selbstüberschneidungen) liefern unbrauchbare Flächen.
  bad <- !sf::st_is_valid(veg_m)
  if (any(bad, na.rm = TRUE)) {
    log_warn(TAG, "%d ungültige Geometrie(n) -- werden mit st_make_valid repariert",
             sum(bad, na.rm = TRUE))
    veg_m <- sf::st_make_valid(veg_m)
  }

  geom_ha <- as.numeric(sf::st_area(veg_m)) / 1e4

  df <- data.frame(
    klasse    = veg[["Ecosis_Nat"]],
    attr_ha   = if ("Area_Ha" %in% names(veg)) as.numeric(veg[["Area_Ha"]]) else NA_real_,
    geom_ha   = geom_ha,
    stringsAsFactors = FALSE
  )

  agg <- aggregate(cbind(attr_ha, geom_ha) ~ klasse, data = df,
                   FUN = sum, na.rm = TRUE, na.action = na.pass)
  n   <- as.data.frame(table(df$klasse), stringsAsFactors = FALSE)
  names(n) <- c("klasse", "n")
  agg <- merge(agg, n, by = "klasse")
  agg <- agg[order(-agg$geom_ha), ]

  total <- sum(agg$geom_ha, na.rm = TRUE)
  log_info(TAG, "Flächenbilanz (%s):", target_crs)
  log_info(TAG, "  %-38s %6s %10s %10s %7s", "Klasse", "n", "Attribut/ha", "Geom/ha", "Anteil")
  for (i in seq_len(nrow(agg))) {
    log_info(TAG, "  %-38s %6d %10.1f %10.1f %6.1f%%",
             agg$klasse[i], agg$n[i], agg$attr_ha[i], agg$geom_ha[i],
             100 * agg$geom_ha[i] / total)
  }

  attr_total <- sum(agg$attr_ha, na.rm = TRUE)
  log_info(TAG, "  %-38s %6s %10.1f %10.1f", "SUMME", "", attr_total, total)

  # Polygonweise Konsistenz -- das ist der eigentlich aussagekräftige Test.
  ok  <- is.finite(df$attr_ha) & df$attr_ha > 0 & is.finite(df$geom_ha)
  rat <- df$geom_ha[ok] / df$attr_ha[ok]
  n_bad <- sum(rat > 2 | rat < 0.5)
  if (n_bad > 0) {
    log_warn(TAG, "%d von %d Polygonen (%.1f %%): Geometrie und Area_Ha weichen um mehr",
             n_bad, sum(ok), 100 * n_bad / sum(ok))
    log_warn(TAG, "als Faktor 2 voneinander ab -- Area_Ha ist polygonweise unzuverlässig.")
    worst <- order(-rat)[1:min(5, length(rat))]
    for (i in worst) {
      log_warn(TAG, "  %-36s Area_Ha=%9.2f  Geometrie=%10.1f  Faktor %.0f",
               df$klasse[ok][i], df$attr_ha[ok][i], df$geom_ha[ok][i], rat[i])
    }
  }

  # Überlappungstest. Erwartung nach dem Clip: Summe == Union.
  # Weicht das ab, sind es echte Überlappungen -- dann und nur dann braucht es
  # eine Prioritätsregel. Beim Stand 2026-08-01 ist die Differenz exakt null.
  union_ha <- tryCatch(
    as.numeric(sf::st_area(sf::st_union(veg_m))) / 1e4,
    error = function(e) NA_real_)
  if (is.finite(union_ha)) {
    log_info(TAG, "Vereinigungsfläche aller Polygone: %.1f ha (Summe %.1f ha)",
             union_ha, total)
    if (total / union_ha > 1.05) {
      log_warn(TAG, "Summe ist das %.2f-fache der Vereinigung -- echte Überlappung.",
               total / union_ha)
      log_warn(TAG, "Vor Flächenanteilen mit st_intersection auflösen.")
    } else {
      log_info(TAG, "überschneidungsfrei (Faktor %.4f) -- Flächenanteile direkt nutzbar",
               total / union_ha)
    }
  }

  dev <- abs(attr_total - total) / total
  if (is.finite(dev) && dev > 0.05) {
    log_warn(TAG, "Attribut- und Geometriesumme weichen um %.1f %% ab -- siehe Kommentar",
             100 * dev)
    log_warn(TAG, "im Kopf von area_report(). Keine der beiden Zahlen ungeprüft verwenden.")
  }
  agg
}

# -----------------------------------------------------------------------------
# Geometrischer Zuschnitt -- der Schritt, ohne den alle Flächenzahlen falsch sind.
#
# Der Attributfilter Isla ist eine Vorauswahl und kein Zuschnitt (siehe Kopf
# von area_report()). Erst dieser Clip macht aus "Polygone, die behaupten, auf
# Santa Cruz zu liegen" die Menge "Polygonteile, die tatsächlich dort liegen".
#
# st_intersection statt st_crop: Polygone, die über die Bbox hinausragen,
# werden abgeschnitten statt ganz übernommen oder ganz verworfen.
clip_to_bbox <- function(veg, bbox) {
  if (is.null(bbox)) {
    log_warn(TAG, "kein clip_bbox in config.yml -- KEIN geometrischer Zuschnitt.")
    log_warn(TAG, "Flächenzahlen sind dann nicht belastbar. Siehe area_report().")
    return(veg)
  }

  box <- sf::st_as_sfc(sf::st_bbox(c(
    xmin = as.numeric(bbox$lon_min), ymin = as.numeric(bbox$lat_min),
    xmax = as.numeric(bbox$lon_max), ymax = as.numeric(bbox$lat_max)
  ), crs = sf::st_crs(veg)))

  n_before <- nrow(veg)
  if (any(!sf::st_is_valid(veg), na.rm = TRUE)) veg <- sf::st_make_valid(veg)

  # st_intersection warnt bei Attributen, die nicht konstant sind -- hier
  # unkritisch, die Klassenzuordnung bleibt beim Zuschneiden erhalten.
  veg <- suppressWarnings(sf::st_intersection(veg, box))
  veg <- veg[!sf::st_is_empty(veg), ]

  log_info(TAG, "geometrischer Clip: %d -> %d Polygone (%d verworfen/zugeschnitten)",
           n_before, nrow(veg), n_before - nrow(veg))
  veg
}

# -----------------------------------------------------------------------------
download_vegetation <- function(overwrite = FALSE, all_islands = FALSE) {
  need_pkg("sf", "httr2", "jsonlite")

  cfg <- load_config()
  v   <- cfg$vegetation
  out <- resolve_path(cfg, "vegetation")

  island <- if (isTRUE(all_islands)) NULL else v$island
  where  <- if (is.null(island)) "1=1" else sprintf("Isla='%s'", island)
  suffix <- if (is.null(island)) "archipel" else gsub("[^A-Za-z]", "", island)

  dest_gpkg <- file.path(out, sprintf("ecosistemas_nativos_2016_%s.gpkg", suffix))
  dest_csv  <- file.path(out, sprintf("flaechenbilanz_%s.csv", suffix))

  if (file.exists(dest_gpkg) && !isTRUE(overwrite)) {
    log_info(TAG, "übersprungen (vorhanden): %s", basename(dest_gpkg))
    veg <- sf::st_read(dest_gpkg, quiet = TRUE)

    # Bestandsdateien aus Läufen vor dem 2026-08-01 sind ungeclippt. Der Clip
    # ist idempotent, deshalb hier gefahrlos nachgeholt -- und die Datei wird
    # einmalig in den korrigierten Zustand überführt.
    if (!is.null(island)) {
      n0  <- nrow(veg)
      veg <- clip_to_bbox(veg, v$clip_bbox)
      if (nrow(veg) != n0) {
        sf::st_write(veg, dest_gpkg, delete_dsn = TRUE, quiet = TRUE)
        log_info(TAG, "Bestandsdatei nachträglich geclippt und neu geschrieben")
      }
    }
  } else {
    veg <- fetch_all(v$service_url, where, unlist(v$fields),
                     as.integer(v$page_size))

    # Klassenabgleich: meldet neue oder verschwundene Klassen gegen config.yml
    known <- unlist(v$classes)
    seen  <- sort(unique(veg[["Ecosis_Nat"]]))
    if (length(setdiff(seen, known))) {
      log_warn(TAG, "Klassen im Dienst, aber nicht in config.yml: %s",
               paste(setdiff(seen, known), collapse = ", "))
    }
    log_info(TAG, "%d Klassen im Ausschnitt (config.yml kennt %d)",
             length(seen), length(known))

    # Zuschnitt nur bei Insel-Auswahl; beim Archipellauf gibt es nichts zu clippen.
    if (!is.null(island)) veg <- clip_to_bbox(veg, v$clip_bbox)

    sf::st_write(veg, dest_gpkg, delete_dsn = TRUE, quiet = TRUE)
    log_info(TAG, "geschrieben: %s  (%.1f MB)",
             basename(dest_gpkg), file.size(dest_gpkg) / 1e6)
  }

  agg <- area_report(veg, v$target_crs)
  utils::write.csv(agg, dest_csv, row.names = FALSE)
  log_info(TAG, "Flächenbilanz gespeichert: %s", basename(dest_csv))

  # Die beiden Zahlen, um die es in Pane 2 geht
  fc <- v$focus_classes
  for (nm in names(fc)) {
    row <- agg[agg$klasse == fc[[nm]], ]
    if (nrow(row)) {
      log_info(TAG, ">> %-12s %-38s %9.1f ha", nm, fc[[nm]], row$geom_ha[1])
    } else {
      log_warn(TAG, ">> %-12s Klasse '%s' im Ausschnitt nicht vorhanden", nm, fc[[nm]])
    }
  }

  write_citation(out, sprintf(
"Vegetationskarte Galápagos v.2016
=================================

%s

Dienst: %s
Bezogen über den öffentlichen ArcGIS-FeatureServer, ohne Login.

Eigenschaften: Landsat-8/OLI-Klassifikation, 30 m Auflösung,
Maßstab 1:60.000, Bezugsjahr 2016. Geometrie im Dienst EPSG:3857,
hier abgelegt in EPSG:4326.

GRENZE, die neben jedem Ergebnis stehen muss:
  Bei 30 m und 1:60.000 ist der Bestand Los Gemelos (~140 ha) rund
  15 Pixel breit. Tauglich für Zonen- und Flächenanteilsaussagen,
  nicht für Bestandes- oder Einzelbaumebene.

Für die vollständigen Shapefiles inklusive der Invasiven-Einheiten in
Originalauflösung ist die Anfrage beim Institut der saubere Weg
(Instituto de Geografía, USFQ).", v$citation, v$service_url))

  log_info(TAG, "fertig -- Ablage: %s", out)
  invisible(veg)
}

# Standardlauf beim source(); Varianten danach direkt aufrufen, z. B.
#   download_vegetation(all_islands = TRUE, overwrite = TRUE)
.a <- parse_args(list(overwrite = FALSE, all_islands = FALSE))
download_vegetation(overwrite   = isTRUE(.a$overwrite),
                    all_islands = isTRUE(.a$all_islands))
