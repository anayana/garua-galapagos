# =============================================================================
# 02_fog_definition.R
#
# Nebeltage aus den CDF-Stationsdaten -- der Kern von Pane 1.
#
# Die Aussage, um die es geht, ist NICHT "so viele Nebeltage gab es".
# Sie lautet: "Nebeltag" ist keine gegebene Grösse, sondern eine methodische
# Entscheidung, und die Ereigniszahl hängt massiv davon ab, wo man die
# Schwellen setzt. Deshalb rechnet dieses Skript nicht eine Definition,
# sondern ein ganzes Gitter davon (sensitivity()).
#
# ---------------------------------------------------------------------------
# WAS DIE DATEN HERGEBEN -- UND WAS NICHT
# ---------------------------------------------------------------------------
# Geprüft am 2026-08-01:
#
#   Puerto Ayora   1964-12-31 .. 2026-06-03   22.376 Tage
#   Bellavista     1987-06-09 .. 2019-09-16   11.788 Tage
#
# DIE ZENTRALE EINSCHRÄNKUNG: Bellavista endet 2019. Die Garúa-Station, auf
# der die ganze Argumentation ruht, hört sieben Jahre vor heute auf. Jede
# Aussage "aktuell" oder "in den letzten Jahren" ist mit diesen Daten nicht
# belegbar. Das gemeinsame Fenster ist 1987-06 bis 2019-09, rund 32 Jahre --
# genug für Klimatologie, zu wenig für Trendaussagen bis in die Gegenwart.
#
# Abdeckung der für Nebel entscheidenden Feuchte:
#   Bellavista humidity 90,8 % -- aber in den 2010ern nur 76 %,
#   also genau in der Dekade mit der Stationsverlegung.
#
# BRUCHSTELLE: Bellavista wurde Ende 2015 um ca. 380 m nach NNW verlegt
# (Angabe des Betreibers). Vor/nach 2015 ist nicht dieselbe Messreihe.
# Das Skript setzt deshalb ein Flag statt die Reihe stillschweigend
# durchzuziehen -- bei Trends zwingend zu berücksichtigen.
#
# Bekannte Fehler, die hier behandelt werden:
#   - min_air_temp > max_air_temp: 3 Fälle Bellavista, 13 Puerto Ayora
#   - Puerto Ayora humidity == 0: an einer Küstenstation physikalisch unmöglich
#   - Puerto Ayora Minimumtemperaturen 2020-2021 gerätebedingt fehlerhaft
#     (Angabe des Betreibers, siehe CITATION.txt)
#
# ---------------------------------------------------------------------------
# WARUM DIE ERSTE FASSUNG ZWEI REGLER HATTE, DIE DERSELBE REGLER WAREN
# ---------------------------------------------------------------------------
# Ursprünglich spannte das Sensitivitätsgitter rh_min gegen dpd_max auf. Das
# sah nach zwei Freiheitsgraden aus, war aber einer:
#
#   Korrelation RH ~ Taupunktdifferenz an Bellavista: -0,998
#
# Kein Wunder -- die Taupunktdifferenz wird über die Magnus-Formel AUS der
# relativen Feuchte berechnet. Bei gegebener Temperatur ist sie dieselbe
# Information in anderen Einheiten. Sichtbar wurde das daran, dass bei
# dpd_max = 0,5 K alle rh_min-Werte von 85 bis 97 exakt dieselbe Ereigniszahl
# lieferten: die schärfere der beiden Bedingungen bindet, die andere ist
# wirkungslos.
#
# Die echte zweite Achse ist der BEDECKUNGSGRAD (Spalte clouds, Achtel):
#   Korrelation clouds ~ humidity  0,38 (Bellavista)  -- unabhängige Information
#   Abdeckung clouds 94 % vs. humidity 91 %           -- sogar die bessere Reihe
#
# Die dritte Bedingung ist ein Niederschlags-FENSTER statt einer Obergrenze.
# Garúa ist Nieselniederschlag: er muss messbar sein (> 0), aber gering.
# Eine reine Obergrenze zählt trockene Hochdrucktage mit.
#
# Wirkung der Umstellung, 1987-2019 (Kontrast = Bellavista / Puerto Ayora):
#
#   Definition                         Bella    PA   Kontrast  Saisonfaktor
#   DPD<=1,5 + P<=5      (erste Fsg.)  42,2 %  24,2 %   1,75       1,65
#   DPD<=1,0 + P<=5                    20,4 %   8,6 %   2,37       2,28
#   DPD<=1,5 + clouds>=7               36,0 %  12,9 %   2,78       2,24
#   DPD<=1,5 + clouds>=7 + P 0,1-5     21,8 %   7,3 %   2,99       3,65
#
# Der vertikale Feuchtegradient Küste -> Hochland ist die Kernaussage des
# Projekts. Eine Definition, die ihn auf Faktor 1,75 zusammendrückt, ist
# schlicht die schlechtere Definition.
#
# ---------------------------------------------------------------------------
# WARUM TAGESWERTE FÜR NEBEL EIGENTLICH ZU GROB SIND
# ---------------------------------------------------------------------------
# Garúa ist ein nächtliches bis morgendliches Phänomen. Ein Tagesmittel der
# relativen Feuchte glättet genau den Tagesgang weg, der die Nebelbildung
# ausmacht. Was hier berechnet wird, ist deshalb ehrlicherweise ein
# NEBELTAG-PROXY, keine Nebeldetektion.
#
# Das ist keine Schwäche der Analyse, sondern das Argument für A1: für echte
# Ereignisdetektion braucht es die Stundendaten des AWS-Netzes bzw. den
# Präsenzwettersensor der Supersite. Genau das steht in der App neben dem
# Ergebnis -- siehe Ehrlichkeitsregel 3 im Konzept.
#
# Aufruf (Arbeitsverzeichnis = Projektordner Galapagos):
#   source("analysis/02_fog_definition.R")
#   fog_definition(plot = TRUE)                    Monatsklimatologie
#   fog_definition(dpd_max = 1.0, cl_min = 8)      strenger
#   fog_definition(use_precip = FALSE)             ohne Niederschlagsfenster
#                                                  -> Saisonalität bricht ein
#   fog_definition(use_clouds = FALSE)             zurück zur ersten Fassung
#   fog_definition(min_coverage = 0.9)             strengerer Abdeckungsfilter
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

TAG <- "fog"

# Bellavista-Verlegung, Ende 2015 (Betreiberangabe)
BREAK_BELLAVISTA <- as.Date("2015-12-31")

# -----------------------------------------------------------------------------
# Taupunkt nach Magnus (Sonntag 1990, Koeffizienten über Wasser).
# Die Taupunktdifferenz T - Td ist das physikalisch saubere Nebelmass:
# sie geht gegen null, wenn die Luft gesättigt ist. Relative Feuchte allein
# ist temperaturabhängig und deshalb zwischen Stationen schlechter vergleichbar.
# -----------------------------------------------------------------------------
dewpoint <- function(temp_c, rh_pct) {
  b <- 17.62; cc <- 243.12
  rh <- pmin(pmax(rh_pct, 1), 100)          # log(0) vermeiden
  g  <- log(rh / 100) + (b * temp_c) / (cc + temp_c)
  cc * g / (b - g)
}

# -----------------------------------------------------------------------------
# Qualitätskontrolle. Repariert nur, was eindeutig ist, und protokolliert alles.
# Alles Zweifelhafte wird auf NA gesetzt, nicht geraten.
# -----------------------------------------------------------------------------
qc_station <- function(d, label) {
  n0 <- nrow(d)

  # 1. Vertauschte Extrema: min > max ist keine Interpretationsfrage.
  sw <- which(is.finite(d$min_air_temp) & is.finite(d$max_air_temp) &
              d$min_air_temp > d$max_air_temp)
  if (length(sw)) {
    tmp <- d$min_air_temp[sw]
    d$min_air_temp[sw] <- d$max_air_temp[sw]
    d$max_air_temp[sw] <- tmp
    log_warn(TAG, "%s: %d Tage mit min > max -- vertauscht", label, length(sw))
  }

  # 2. Relative Feuchte ausserhalb (0, 100]. 0 % ist an einer Insel-
  #    station physikalisch unmöglich, also Digitalisier- oder Sensorfehler.
  bad_rh <- which(is.finite(d$humidity) & (d$humidity <= 0 | d$humidity > 100))
  if (length(bad_rh)) {
    d$humidity[bad_rh] <- NA_real_
    log_warn(TAG, "%s: %d unmögliche Feuchtewerte -> NA", label, length(bad_rh))
  }

  # 3. Negativer Niederschlag
  bad_p <- which(is.finite(d$precipitation) & d$precipitation < 0)
  if (length(bad_p)) {
    d$precipitation[bad_p] <- NA_real_
    log_warn(TAG, "%s: %d negative Niederschläge -> NA", label, length(bad_p))
  }

  # 4. Tagesmitteltemperatur ergänzen, wo min und max vorliegen.
  #    (min+max)/2 ist eine Näherung, wird deshalb markiert.
  d$mean_est <- FALSE
  fill <- which(!is.finite(d$mean_air_temp) &
                is.finite(d$min_air_temp) & is.finite(d$max_air_temp))
  if (length(fill)) {
    d$mean_air_temp[fill] <- (d$min_air_temp[fill] + d$max_air_temp[fill]) / 2
    d$mean_est[fill] <- TRUE
    log_info(TAG, "%s: %d Tagesmittel aus (min+max)/2 ergänzt", label, length(fill))
  }

  log_info(TAG, "%s: %d Tage, Feuchte auf %.1f %% der Tage verfügbar",
           label, n0, 100 * mean(is.finite(d$humidity)))
  d
}

# -----------------------------------------------------------------------------
# Nebeltag-Proxy. Drei UNABHÄNGIGE Bedingungen:
#
#   dpd_max     Taupunktdifferenz höchstens ... K   -- Sättigungsnähe
#   cl_min      Bedeckungsgrad mindestens ... /8    -- tiefe Stratusdecke
#   precip_min  Niederschlag mindestens ... mm      -- Niesel ist messbar
#   precip_max  Niederschlag höchstens ... mm       -- aber kein Starkregen
#
# rh_min gibt es bewusst NICHT mehr als eigenen Regler -- siehe Kopf der Datei.
# Wer die Feuchteschwelle direkt setzen will, nimmt dpd_max: bei 20 °C
# entspricht RH 92 % etwa DPD 1,15 K, RH 95 % etwa 0,70 K.
#
# use_clouds / use_precip erlauben, die Achsen einzeln abzuschalten -- genau
# dafür sind sie da: In Pane 1 soll sichtbar werden, wie die Saisonalität
# kippt, wenn man das Niederschlagsfenster weglässt.
# -----------------------------------------------------------------------------
flag_fog <- function(d, dpd_max = 1.5, cl_min = 7,
                     precip_min = 0.1, precip_max = 5,
                     use_clouds = TRUE, use_precip = TRUE) {
  td  <- dewpoint(d$mean_air_temp, d$humidity)
  dpd <- d$mean_air_temp - td

  # ok = "dieser Tag ist überhaupt bewertbar". Jede zugeschaltete Bedingung
  # verlangt ihre eigene Messung; fehlt sie, ist der Tag unbekannt, nicht
  # nebelfrei. Deshalb wächst ok NICHT, sondern schrumpft mit jeder Achse.
  ok  <- is.finite(dpd)
  fog <- dpd <= dpd_max

  if (isTRUE(use_clouds)) {
    ok  <- ok  & is.finite(d$clouds)
    fog <- fog & d$clouds >= cl_min
  }
  if (isTRUE(use_precip)) {
    ok  <- ok  & is.finite(d$precipitation)
    fog <- fog & d$precipitation >= precip_min & d$precipitation <= precip_max
  }

  d$dewpoint <- td
  d$dpd      <- dpd
  # NA statt FALSE, wo die Eingangsgrössen fehlen: ein Tag ohne Messung ist
  # kein Nicht-Nebeltag, sondern ein unbekannter Tag. Der Unterschied zwischen
  # "kein Ereignis" und "keine Messung" entscheidet über jede Rate weiter unten.
  d$fog <- ifelse(ok, fog & ok, NA)
  d
}

# -----------------------------------------------------------------------------
# Sensitivitätsgitter -- das Herzstück von Pane 1.
# Liefert die Datengrundlage für die Regler: Nebeltage pro Jahr über
# rh_min x dpd_max. Wenn die Zahl zwischen den Ecken des Gitters um den
# Faktor 5 springt, ist genau das die Botschaft.
# -----------------------------------------------------------------------------
sensitivity <- function(d, label,
                        dpd_grid = seq(0.5, 3.0, by = 0.25),
                        cl_grid  = 5:8,
                        precip_min = 0.1, precip_max = 5,
                        use_clouds = TRUE, use_precip = TRUE) {
  yrs <- length(unique(format(d$observation_date, "%Y")))
  out <- expand.grid(dpd_max = dpd_grid, cl_min = cl_grid)
  out$n_fog <- NA_real_; out$n_bewertbar <- NA_real_; out$fog_per_yr <- NA_real_

  for (i in seq_len(nrow(out))) {
    f <- flag_fog(d, out$dpd_max[i], out$cl_min[i], precip_min, precip_max,
                  use_clouds, use_precip)
    out$n_fog[i]       <- sum(f$fog, na.rm = TRUE)
    out$n_bewertbar[i] <- sum(!is.na(f$fog))
    out$fog_per_yr[i]  <- out$n_fog[i] / yrs
  }
  out$station <- label

  rng <- range(out$fog_per_yr)
  log_info(TAG, "%s: Nebeltage/Jahr zwischen %.0f und %.0f -- Faktor %.1f",
           label, rng[1], rng[2],
           if (rng[1] > 0) rng[2] / rng[1] else Inf)
  out
}

# -----------------------------------------------------------------------------
# Monatsklimatologie. Garúa-Saison ist Jun-Dez -- wenn die Definition taugt,
# muss sich das hier von selbst zeigen. Tut es das nicht, stimmt die
# Definition nicht (und nicht die Jahreszeit).
# -----------------------------------------------------------------------------
monthly_climatology <- function(d, label) {
  m   <- as.integer(format(d$observation_date, "%m"))
  agg <- data.frame(
    monat     = 1:12,
    n_tage    = as.integer(table(factor(m, levels = 1:12))),
    fog_anteil = tapply(d$fog, factor(m, levels = 1:12),
                        function(x) mean(x, na.rm = TRUE)),
    rh_mittel  = tapply(d$humidity, factor(m, levels = 1:12),
                        function(x) mean(x, na.rm = TRUE)),
    niederschlag = tapply(d$precipitation, factor(m, levels = 1:12),
                          function(x) mean(x, na.rm = TRUE)),
    row.names = NULL
  )
  agg$station <- label
  agg$garua_saison <- agg$monat %in% 6:12

  gs <- mean(agg$fog_anteil[agg$garua_saison], na.rm = TRUE)
  ws <- mean(agg$fog_anteil[!agg$garua_saison], na.rm = TRUE)
  log_info(TAG, "%s: Nebelanteil Garúa-Saison %.1f %% vs. übrige %.1f %% (Faktor %.2f)",
           label, 100 * gs, 100 * ws, gs / ws)
  if (is.finite(gs) && is.finite(ws) && gs < ws) {
    log_warn(TAG, "%s: mehr 'Nebel' ausserhalb der Garúa-Saison --", label)
    log_warn(TAG, "  die Definition fängt vermutlich konvektiven Regen mit ein.")
    log_warn(TAG, "  Niederschlagsfenster prüfen (use_precip = TRUE).")
  }
  agg
}

# -----------------------------------------------------------------------------
# Jahreswerte MIT Abdeckungsfilter.
#
# Der Grund, warum es diese Funktion gibt -- Bellavista, Feuchteabdeckung:
#   2013: 100 %   Nebelanteil 59 %
#   2014:  16 %                51 %
#   2015:  20 %                36 %
#   2016:  57 %                78 %
#
# 2016 ist der auffälligste Wert der ganzen Reihe und beruht auf gut der
# Hälfte der Tage -- unmittelbar nach der Stationsverlegung, mitten in einer
# Abdeckungslücke. Wer daraus einen Sprung liest, liest ein Stichprobenartefakt.
# Jahre unter min_coverage werden deshalb ausgewiesen, aber als unbelastbar
# markiert statt stillschweigend mitgemittelt.
# -----------------------------------------------------------------------------
annual_series <- function(d, label, min_coverage = 0.8) {
  yr  <- format(d$observation_date, "%Y")
  agg <- data.frame(
    jahr       = as.integer(names(table(yr))),
    n_tage     = as.integer(table(yr)),
    n_bewertbar = as.integer(tapply(!is.na(d$fog), yr, sum)),
    fog_anteil = as.numeric(tapply(d$fog, yr, function(x) mean(x, na.rm = TRUE))),
    row.names  = NULL
  )
  agg$abdeckung <- agg$n_bewertbar / agg$n_tage
  agg$belastbar <- agg$abdeckung >= min_coverage
  agg$station   <- label

  n_bad <- sum(!agg$belastbar)
  if (n_bad) {
    log_warn(TAG, "%s: %d Jahre unter %.0f %% Abdeckung -- als unbelastbar markiert:",
             label, n_bad, 100 * min_coverage)
    b <- agg[!agg$belastbar, ]
    log_warn(TAG, "  %s", paste(sprintf("%d (%.0f %%)", b$jahr, 100 * b$abdeckung),
                                collapse = ", "))
  }
  agg
}

# -----------------------------------------------------------------------------
fog_definition <- function(dpd_max = 1.5, cl_min = 7,
                           precip_min = 0.1, precip_max = 5,
                           use_clouds = TRUE, use_precip = TRUE,
                           min_coverage = 0.8, plot = FALSE) {
  need_pkg("utils")

  cfg <- load_config()
  dir_st <- resolve_path(cfg, "stations")

  stations <- list(
    "Bellavista"   = file.path(dir_st, "climate_bellavista.csv"),
    "Puerto Ayora" = file.path(dir_st, "climate_puerto-ayora.csv")
  )

  daily <- list(); sens <- list(); clim <- list(); ann <- list()
  rates <- c()

  for (label in names(stations)) {
    p <- stations[[label]]
    if (!file.exists(p)) {
      log_err(TAG, "fehlt: %s -- erst download/01_download_cdf_stations.R", p)
      next
    }
    d <- utils::read.csv(p, stringsAsFactors = FALSE)
    d$observation_date <- as.Date(d$observation_date)
    d <- d[order(d$observation_date), ]

    d <- qc_station(d, label)

    # Bruchstelle markieren statt glätten.
    d$periode <- if (label == "Bellavista") {
      ifelse(d$observation_date <= BREAK_BELLAVISTA, "vor Verlegung", "nach Verlegung")
    } else "durchgehend"

    d <- flag_fog(d, dpd_max, cl_min, precip_min, precip_max,
                  use_clouds, use_precip)
    d$station <- label

    log_info(TAG, "%s: %s .. %s | Nebeltage %d von %d bewertbaren Tagen (%.1f %%)",
             label, min(d$observation_date), max(d$observation_date),
             sum(d$fog, na.rm = TRUE), sum(!is.na(d$fog)),
             100 * mean(d$fog, na.rm = TRUE))

    rates[label]   <- mean(d$fog, na.rm = TRUE)
    daily[[label]] <- d
    sens[[label]]  <- sensitivity(d, label, precip_min = precip_min,
                                  precip_max = precip_max,
                                  use_clouds = use_clouds, use_precip = use_precip)
    clim[[label]]  <- monthly_climatology(d, label)
    ann[[label]]   <- annual_series(d, label, min_coverage)
  }

  if (!length(daily)) stop("Keine Stationsdaten gefunden.")

  # Der vertikale Feuchtegradient ist die Kernaussage -- also wird er gemessen.
  # Eine Definition, die Küste und Hochland kaum trennt, taugt nicht, egal wie
  # plausibel ihre Schwellen klingen.
  if (all(c("Bellavista", "Puerto Ayora") %in% names(rates))) {
    k <- rates[["Bellavista"]] / rates[["Puerto Ayora"]]
    log_info(TAG, "Kontrast Hochland/Küste: %.2f  (Bellavista %.1f %% vs. Puerto Ayora %.1f %%)",
             k, 100 * rates[["Bellavista"]], 100 * rates[["Puerto Ayora"]])
    if (k < 2) {
      log_warn(TAG, "Kontrast unter 2 -- die Definition trennt die Höhenstufen schlecht.")
      log_warn(TAG, "  Referenz: DPD<=1,5 + clouds>=7 + P 0,1-5 mm liefert 2,99.")
    }
  }

  # Bellavista vor/nach Verlegung getrennt ausweisen -- der Vergleich sagt,
  # ob die Bruchstelle die Nebelstatistik überhaupt betrifft.
  b <- daily[["Bellavista"]]
  if (!is.null(b)) {
    for (p in unique(b$periode)) {
      s <- b[b$periode == p, ]
      log_info(TAG, "Bellavista %-16s %s .. %s  Nebelanteil %.1f %% (Abdeckung %.0f %%)",
               p, min(s$observation_date), max(s$observation_date),
               100 * mean(s$fog, na.rm = TRUE), 100 * mean(!is.na(s$fog)))
    }

    # Derselbe Vergleich, aber nur auf Jahren mit belastbarer Abdeckung.
    # Wenn der Sprung dabei zusammenschrumpft, war er ein Stichprobeneffekt
    # und keine Folge der Verlegung.
    a <- ann[["Bellavista"]]
    if (!is.null(a) && any(a$belastbar)) {
      g  <- a[a$belastbar, ]
      v  <- mean(g$fog_anteil[g$jahr <= 2015], na.rm = TRUE)
      nn <- mean(g$fog_anteil[g$jahr >  2015], na.rm = TRUE)
      log_info(TAG, "nur belastbare Jahre (>= %.0f %% Abdeckung): vor %.1f %% / nach %.1f %%",
               100 * min_coverage, 100 * v, 100 * nn)
    }

    log_warn(TAG, "Die beiden Perioden sind NICHT dieselbe Messreihe.")
    log_warn(TAG, "Trendaussagen über 2015 hinweg brauchen eine Homogenisierung.")
  }

  out_dir <- cfg$paths$processed
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

  keep <- c("station", "observation_date", "periode", "mean_air_temp",
            "humidity", "clouds", "precipitation", "dewpoint", "dpd",
            "fog", "mean_est")
  dd <- do.call(rbind, lapply(daily, function(x) x[, keep]))

  utils::write.csv(dd,                   file.path(out_dir, "fog_daily.csv"), row.names = FALSE)
  utils::write.csv(do.call(rbind, sens), file.path(out_dir, "fog_sensitivity.csv"), row.names = FALSE)
  utils::write.csv(do.call(rbind, clim), file.path(out_dir, "fog_climatology.csv"), row.names = FALSE)
  utils::write.csv(do.call(rbind, ann),  file.path(out_dir, "fog_annual.csv"), row.names = FALSE)
  log_info(TAG, "geschrieben: fog_daily.csv, fog_sensitivity.csv, fog_climatology.csv, fog_annual.csv")

  if (isTRUE(plot)) {
    op <- graphics::par(mfrow = c(2, 1), mar = c(4, 4, 3, 1))
    on.exit(graphics::par(op), add = TRUE)
    for (label in names(clim)) {
      cl <- clim[[label]]
      graphics::barplot(100 * cl$fog_anteil, names.arg = month.abb,
                        col = ifelse(cl$garua_saison, "grey30", "grey75"),
                        ylab = "Nebeltage (% der Tage)",
                        main = sprintf("%s -- DPD<=%g K, clouds>=%g/8, P %g-%g mm",
                                       label, dpd_max, cl_min, precip_min, precip_max))
      graphics::legend("topleft", c("Garúa-Saison Jun-Dez", "übrige Monate"),
                       fill = c("grey30", "grey75"), bty = "n", cex = 0.8)
    }
  }

  invisible(list(daily = dd, sensitivity = do.call(rbind, sens),
                 climatology = do.call(rbind, clim),
                 annual = do.call(rbind, ann)))
}

fog_definition()
