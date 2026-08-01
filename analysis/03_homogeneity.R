# =============================================================================
# 03_homogeneity.R
#
# Bruchpunkte in den Stationsreihen datieren, statt sie zu vermuten.
#
# ---------------------------------------------------------------------------
# WARUM DIESE DATEI EXISTIERT
# ---------------------------------------------------------------------------
# Der Betreiber warnt vor einer Stelle: Bellavista wurde Ende 2015 um ca. 380 m
# nach NNW verlegt. Die Daten sagen etwas anderes.
#
# Bellavista, Nebelanteil je Jahr bei durchweg 99 % Datenabdeckung:
#     2004  21,8 %
#     2005   1,1 %   <- Sturz um Faktor 20 binnen eines Jahres
#     2006   3,3 %
#     2007   6,4 %
#     2008  10,2 %
#     ...    Erholung bis 2013 auf 34,9 %
#
# Und der Sprung nach 2015 taucht auch an Puerto Ayora auf -- einer Station,
# die NIE verlegt wurde:
#     Puerto Ayora  1987-2015   7,8 %
#                   2016-2019  15,1 %
#                   2020-2026  13,7 %
#
# Zwei Schlüsse:
#   1. Der 2015er-Bruch ist nicht die Verlegung, sondern etwas, das BEIDE
#      Stationen betrifft -- vermutlich geänderte Beobachtungs- oder
#      Digitalisierungspraxis. Beide Reihen kommen von derselben Organisation.
#   2. Der grössere Bruch liegt um 2005 und ist nirgends dokumentiert.
#
# Solange das nicht geklärt ist, ist JEDE Trendaussage aus diesen Reihen
# wertlos. Diese Datei macht aus dem Augenschein ein Testergebnis.
#
# ---------------------------------------------------------------------------
# METHODEN
# ---------------------------------------------------------------------------
# Pettitt (1979)        -- verteilungsfreier Test auf EINEN Bruchpunkt in der
#                          Lage. Robust gegen Ausreisser, braucht keine
#                          Normalverteilung. Gibt Zeitpunkt und Näherungs-p.
#
# SNHT (Alexandersson)  -- Standard Normal Homogeneity Test. Empfindlicher an
#                          den Rändern der Reihe als Pettitt, dafür anfälliger
#                          für Ausreisser. Zwei Tests, die dieselbe Stelle
#                          finden, sind ein starkes Indiz.
#
# DIFFERENZREIHE        -- der eigentlich saubere Weg. Beide Stationen liegen
#                          20 km auseinander unter derselben Wetterlage. Das
#                          gemeinsame Klimasignal steckt in beiden Reihen;
#                          in der Differenz Bellavista - Puerto Ayora kürzt es
#                          sich weg. Was übrig bleibt, ist Stationseffekt.
#                          Ein Bruch NUR in der Differenzreihe ist ein
#                          Stationsproblem. Ein Bruch in beiden Einzelreihen,
#                          aber nicht in der Differenz, ist echtes Klima --
#                          oder ein Problem des gesamten Messnetzes.
#
# Doppelmassenkurve     -- kumulierte Bellavista-Werte gegen kumulierte
#                          Puerto-Ayora-Werte. Knicke = Bruchpunkte. Alt,
#                          simpel, und man sieht es sofort.
#
# BINÄRE SEGMENTIERUNG -- weil ein Bruchtest nicht reicht.
#
#     Erster Lauf auf Jahreswerten, 2026-08-01:
#       Bellavista    Pettitt p = 0,31   SNHT T0 = 5,7 (krit. 8,8)   n.s.
#
#     Dieser Nullbefund ist WERTLOS, aus zwei Gründen:
#
#     1. Pettitt und SNHT suchen GENAU EINEN Bruch. Bellavista hat sichtbar
#        zwei in entgegengesetzter Richtung -- Einbruch 2005, Anstieg nach
#        2016. In einem Einzelbruch-Test heben die sich gegenseitig auf.
#     2. Der Abdeckungsfilter hatte 2014, 2015 und 2016 verworfen -- genau
#        die Jahre um den vermuteten Bruch. Der Test konnte ihn nicht sehen.
#
#     Deshalb: rekursive Segmentierung (Bruch suchen, an der Fundstelle
#     teilen, in beiden Hälften weitersuchen), bis kein Abschnitt mehr
#     signifikant ist oder die Mindestlänge unterschritten wird.
#
# MONATSWERTE STATT JAHRESWERTEN.
#     30 Jahreswerte sind für Bruchtests wenig. Monatswerte geben rund 360
#     Punkte. Preis: die Saisonalität dominiert alles -- ein Nebelanteil von
#     41 % im August und 3 % im März ist kein Bruch, sondern Sommer. Deshalb
#     wird vorher die Monatsklimatologie abgezogen (Saisonbereinigung); die
#     Tests laufen auf ANOMALIEN.
#
# VORAUSSETZUNG: analysis/02_fog_definition.R muss gelaufen sein
#                (liefert fog_daily.csv und fog_annual.csv).
#
# Aufruf (Arbeitsverzeichnis = Projektordner Galapagos):
#   source("analysis/03_homogeneity.R")
#   homogeneity(plot = TRUE)
#   homogeneity(resolution = "annual")     alte Fassung, Jahreswerte
#   homogeneity(min_days = 20)             strengere Monatsabdeckung
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

TAG <- "homog"

# -----------------------------------------------------------------------------
# Pettitt-Test.
#
# U_t = Summe der Vorzeichen aller Paarvergleiche zwischen den ersten t und
# den restlichen Werten. Wo |U_t| maximal wird, liegt der wahrscheinlichste
# Bruch. Die p-Näherung stammt aus Pettitt (1979) und ist für n > 10 brauchbar.
# -----------------------------------------------------------------------------
pettitt_test <- function(x, labels) {
  ok <- is.finite(x); x <- x[ok]; labels <- labels[ok]
  n <- length(x)
  if (n < 10) return(NULL)

  # outer() statt Doppelschleife -- bei n ~ 30 egal, aber lesbarer
  S <- sign(outer(x, x, "-"))
  U <- vapply(seq_len(n - 1), function(t) sum(S[seq_len(t), (t + 1):n]), numeric(1))

  K   <- max(abs(U))
  pos <- which.max(abs(U))
  p   <- 2 * exp(-6 * K^2 / (n^3 + n^2))

  list(methode = "Pettitt", bruch = labels[pos], K = K,
       p = min(p, 1), n = n,
       richtung = if (U[pos] < 0) "Anstieg nach dem Bruch" else "Abfall nach dem Bruch")
}

# -----------------------------------------------------------------------------
# SNHT nach Alexandersson (1986).
#
# Die Reihe wird standardisiert; für jede Position a wird geprüft, wie stark
# sich die Mittel vor und nach a unterscheiden. T0 = max über alle a.
#
# Kritische Werte sind tabelliert, nicht analytisch. Die Werte unten sind die
# gebräuchlichen 95-%-Schwellen (Khaliq & Ouarda 2007) für die jeweilige
# Reihenlänge; dazwischen wird linear interpoliert. Das ist eine Näherung --
# deshalb wird T0 immer mit ausgewiesen und nicht nur ein Sternchen vergeben.
# -----------------------------------------------------------------------------
snht_test <- function(x, labels) {
  ok <- is.finite(x); x <- x[ok]; labels <- labels[ok]
  n <- length(x)
  if (n < 10) return(NULL)

  z <- (x - mean(x)) / stats::sd(x)
  Tv <- vapply(seq_len(n - 1), function(a) {
    a * mean(z[seq_len(a)])^2 + (n - a) * mean(z[(a + 1):n])^2
  }, numeric(1))

  T0  <- max(Tv)
  pos <- which.max(Tv)

  nn  <- c(10, 20, 30, 40, 50, 70, 100)
  cv  <- c(7.0, 8.2, 8.8, 9.2, 9.4, 9.8, 10.2)   # 95-%-Schwellen
  crit <- stats::approx(nn, cv, xout = min(max(n, 10), 100))$y

  list(methode = "SNHT", bruch = labels[pos], T0 = T0, krit95 = crit, n = n,
       signifikant = T0 > crit)
}

# -----------------------------------------------------------------------------
report_break <- function(res, serie) {
  if (is.null(res)) {
    log_warn(TAG, "%s: zu wenige Jahre für einen Test", serie)
    return(invisible(NULL))
  }
  if (res$methode == "Pettitt") {
    log_info(TAG, "  Pettitt  %-28s Bruch %s  p = %.4f %s",
             serie, res$bruch, res$p,
             if (res$p < 0.05) "**" else "(n.s.)")
    log_info(TAG, "           %s", res$richtung)
  } else {
    log_info(TAG, "  SNHT     %-28s Bruch %s  T0 = %.1f (krit. %.1f) %s",
             serie, res$bruch, res$T0, res$krit95,
             if (isTRUE(res$signifikant)) "**" else "(n.s.)")
  }
  invisible(res)
}

# -----------------------------------------------------------------------------
# Monatsreihe der Nebelanteile, saisonbereinigt.
#
# min_days: ein Monat mit 3 bewertbaren Tagen liefert eine Rate von 0 oder 100 %
# und würde jeden Bruchtest zerschiessen. Solche Monate fliegen raus -- aber
# als GANZE Monate, nicht als einzelne Jahre. Das ist der Unterschied zum
# Jahresfilter, der 2014-2016 komplett gelöscht und damit die interessante
# Stelle unsichtbar gemacht hat.
# -----------------------------------------------------------------------------
monthly_anomaly <- function(dd, station, min_days = 15) {
  d <- dd[dd$station == station & !is.na(dd$fog), ]
  if (!nrow(d)) return(NULL)
  d$ym <- format(as.Date(d$observation_date), "%Y-%m")
  d$m  <- as.integer(substr(d$ym, 6, 7))

  n   <- tapply(d$fog, d$ym, length)
  rate <- tapply(d$fog, d$ym, mean)
  mon <- as.integer(substr(names(rate), 6, 7))

  keep <- n >= min_days
  rate <- rate[keep]; mon <- mon[keep]

  # Saisonbereinigung: Monatsklimatologie abziehen
  clim <- tapply(rate, mon, mean)
  anom <- as.numeric(rate) - as.numeric(clim[as.character(mon)])

  list(label = names(rate), anom = anom, n_verworfen = sum(!keep))
}

# -----------------------------------------------------------------------------
# Binäre Segmentierung: rekursiv Brüche suchen.
# -----------------------------------------------------------------------------
# WICHTIGE EINSCHRÄNKUNG, die neben jedem Ergebnis stehen muss:
# Die Rekursion testet wiederholt auf denselben Daten, ohne Korrektur für
# Mehrfachtestung, und die SNHT-Schwellen gelten für EINEN Test. Die Zahl der
# gefundenen Brüche ist deshalb eher zu hoch. Signifikanz allein taugt hier
# nicht als Auswahlkriterium.
#
# Deshalb wird zu jedem Bruch die SPRUNGHÖHE mitgeliefert -- die Differenz der
# Mittelwerte links und rechts davon. Ein statistisch signifikanter Sprung von
# 0,5 Prozentpunkten ist für die Fragestellung belanglos; einer von 15 Punkten
# entwertet jede Trendaussage. Die Grösse entscheidet, nicht das Sternchen.
segment_breaks <- function(x, labels, min_seg = 24, depth = 0, max_depth = 4) {
  if (length(x) < 2 * min_seg || depth >= max_depth) return(NULL)
  r <- snht_test(x, labels)
  if (is.null(r) || !isTRUE(r$signifikant)) return(NULL)

  pos <- match(r$bruch, labels)
  if (is.na(pos) || pos < min_seg || (length(x) - pos) < min_seg) return(NULL)

  hier <- data.frame(
    bruch  = r$bruch,
    T0     = r$T0,
    sprung = mean(x[(pos + 1):length(x)]) - mean(x[seq_len(pos)]),
    n_links = pos, n_rechts = length(x) - pos,
    stringsAsFactors = FALSE
  )

  rbind(
    segment_breaks(x[seq_len(pos)], labels[seq_len(pos)], min_seg, depth + 1, max_depth),
    hier,
    segment_breaks(x[(pos + 1):length(x)], labels[(pos + 1):length(labels)],
                   min_seg, depth + 1, max_depth)
  )
}

# Brüche nach Sprunghöhe sortiert ausgeben, in Prozentpunkten.
report_segments <- function(br, serie) {
  if (is.null(br) || !nrow(br)) {
    log_info(TAG, "  Segmentierung %-22s kein signifikanter Bruch", serie)
    return(invisible(NULL))
  }
  br <- br[order(-abs(br$sprung)), ]
  log_info(TAG, "  Segmentierung %-22s %d Brüche, nach Sprunghöhe:", serie, nrow(br))
  for (i in seq_len(nrow(br))) {
    log_info(TAG, "      %s  %+6.1f Pp   T0 = %5.1f   (n %d|%d)",
             br$bruch[i], 100 * br$sprung[i], br$T0[i],
             br$n_links[i], br$n_rechts[i])
  }
  invisible(br)
}

# -----------------------------------------------------------------------------
homogeneity <- function(variable = "fog_anteil", min_coverage = 0.8,
                        resolution = c("monthly", "annual"),
                        min_days = 15, min_seg = 24, plot = FALSE) {
  resolution <- match.arg(resolution)
  cfg <- load_config()

  # --- Monatsauflösung: der eigentliche Test ---------------------------------
  if (resolution == "monthly") {
    src <- file.path(cfg$paths$processed, "fog_daily.csv")
    if (!file.exists(src)) {
      stop("fog_daily.csv fehlt -- erst source(\"analysis/02_fog_definition.R\")")
    }
    dd <- utils::read.csv(src, stringsAsFactors = FALSE)
    dd$fog <- as.logical(dd$fog)

    log_info(TAG, "Monatsanomalien, min. %d bewertbare Tage je Monat", min_days)
    ms <- list()
    for (s in unique(dd$station)) {
      m <- monthly_anomaly(dd, s, min_days)
      if (is.null(m)) next
      ms[[s]] <- m
      log_info(TAG, "%s: %d Monate (%s .. %s), %d wegen Datenlücke verworfen",
               s, length(m$anom), m$label[1], m$label[length(m$label)], m$n_verworfen)
      report_break(pettitt_test(m$anom, m$label), s)
      report_break(snht_test(m$anom, m$label), s)
      report_segments(segment_breaks(m$anom, m$label, min_seg), s)
    }

    # Differenzreihe auf Monatsbasis
    if (length(ms) >= 2) {
      A <- ms[[1]]; B <- ms[[2]]
      ym <- intersect(A$label, B$label)
      if (length(ym) >= 2 * min_seg) {
        dif <- A$anom[match(ym, A$label)] - B$anom[match(ym, B$label)]
        log_info(TAG, "--- Differenzreihe %s - %s (%d gemeinsame Monate) ---",
                 names(ms)[1], names(ms)[2], length(ym))
        report_break(pettitt_test(dif, ym), "Differenz")
        report_break(snht_test(dif, ym), "Differenz")
        br <- segment_breaks(dif, ym, min_seg)
        report_segments(br, "Differenz")
        log_info(TAG, "  Brüche HIER sind Stationseffekte. Brüche nur in den")
        log_info(TAG, "  Einzelreihen sind Klima -- oder betreffen das ganze Netz.")

        if (!is.null(br) && nrow(br)) {
          gr <- br[abs(br$sprung) >= 0.05, ]
          log_info(TAG, "  davon mit Sprung >= 5 Prozentpunkten: %d", nrow(gr))
          utils::write.csv(br, file.path(cfg$paths$processed, "homogeneity_breaks.csv"),
                           row.names = FALSE)
          log_info(TAG, "  geschrieben: homogeneity_breaks.csv")
        }

        if (isTRUE(plot)) {
          op <- graphics::par(mar = c(4, 4, 3, 1)); on.exit(graphics::par(op), add = TRUE)
          tt <- as.numeric(substr(ym, 1, 4)) + (as.numeric(substr(ym, 6, 7)) - 0.5) / 12
          graphics::plot(tt, dif, type = "l", col = "grey40",
                         xlab = "", ylab = "Anomaliedifferenz",
                         main = sprintf("%s - %s, saisonbereinigt", names(ms)[1], names(ms)[2]))
          graphics::abline(h = 0, lty = 2)
          graphics::lines(tt, stats::filter(dif, rep(1/25, 25), sides = 2), lwd = 2)
          if (!is.null(br)) {
            bt <- as.numeric(substr(br$bruch, 1, 4)) +
                  (as.numeric(substr(br$bruch, 6, 7)) - 0.5) / 12
            # Linienstärke nach Sprunghöhe -- die grossen Brüche sollen ins Auge fallen
            graphics::abline(v = bt, col = "red",
                             lwd = 1 + 4 * abs(br$sprung) / max(abs(br$sprung)))
            graphics::text(bt, graphics::par("usr")[4],
                           sprintf("%+.0f", 100 * br$sprung),
                           pos = 1, cex = 0.7, col = "red")
          }
        }
      }
    }
    log_info(TAG, "--- Konsequenz ---")
    log_info(TAG, "Für die App gilt bis zur Homogenisierung: Klimatologie ja, Trend nein.")
    return(invisible(ms))
  }

  # --- Jahresauflösung: die alte, schwächere Fassung -------------------------
  src <- file.path(cfg$paths$processed, "fog_annual.csv")
  if (!file.exists(src)) {
    stop("fog_annual.csv fehlt -- erst source(\"analysis/02_fog_definition.R\")")
  }

  a <- utils::read.csv(src, stringsAsFactors = FALSE)
  a$belastbar <- as.logical(a$belastbar)
  a <- a[!is.na(a$belastbar) & a$belastbar & a$abdeckung >= min_coverage, ]
  if (!variable %in% names(a)) stop("Spalte nicht vorhanden: ", variable)
  log_warn(TAG, "Jahresauflösung: nur ~30 Werte, und der Abdeckungsfilter")
  log_warn(TAG, "löscht 2014-2016 -- also genau die zu prüfende Stelle.")

  st <- unique(a$station)
  log_info(TAG, "Variable %s, %d Stationen, Jahre mit Abdeckung >= %.0f %%",
           variable, length(st), 100 * min_coverage)

  out <- list()

  # --- 1. Einzelreihen -------------------------------------------------------
  log_info(TAG, "--- Einzelreihen (enthalten Klima UND Stationseffekt) ---")
  series <- list()
  for (s in st) {
    d <- a[a$station == s, ]
    d <- d[order(d$jahr), ]
    series[[s]] <- stats::setNames(d[[variable]], d$jahr)
    log_info(TAG, "%s: %d Jahre (%d-%d)", s, nrow(d), min(d$jahr), max(d$jahr))
    out[[paste(s, "pettitt")]] <- report_break(pettitt_test(d[[variable]], d$jahr), s)
    out[[paste(s, "snht")]]    <- report_break(snht_test(d[[variable]], d$jahr), s)
  }

  # --- 2. Differenzreihe -----------------------------------------------------
  # Der aussagekräftigste Test: gemeinsames Klimasignal kürzt sich weg.
  if (length(st) >= 2) {
    A <- series[[st[1]]]; B <- series[[st[2]]]
    yr <- intersect(names(A), names(B))
    if (length(yr) >= 10) {
      diff <- A[yr] - B[yr]
      log_info(TAG, "--- Differenzreihe %s - %s (%d gemeinsame Jahre) ---",
               st[1], st[2], length(yr))
      log_info(TAG, "    Bruch hier = Stationseffekt. Kein Bruch hier, aber in")
      log_info(TAG, "    beiden Einzelreihen = echtes Klima oder Netzproblem.")
      lbl <- as.integer(yr)
      out[["differenz pettitt"]] <- report_break(pettitt_test(as.numeric(diff), lbl), "Differenz")
      out[["differenz snht"]]    <- report_break(snht_test(as.numeric(diff), lbl), "Differenz")

      # --- 3. Doppelmassenkurve ---------------------------------------------
      # Knick = Bruch. Gemessen als Steigungsänderung zwischen erster und
      # zweiter Hälfte der kumulierten Reihen.
      cA <- cumsum(A[yr]); cB <- cumsum(B[yr])
      h  <- floor(length(yr) / 2)
      s1 <- stats::coef(stats::lm(cA[1:h] ~ cB[1:h]))[2]
      s2 <- stats::coef(stats::lm(cA[(h + 1):length(yr)] ~ cB[(h + 1):length(yr)]))[2]
      log_info(TAG, "  Doppelmasse Steigung 1. Hälfte %.2f / 2. Hälfte %.2f (Verhältnis %.2f)",
               s1, s2, s2 / s1)
      if (abs(s2 / s1 - 1) > 0.2) {
        log_warn(TAG, "  Steigungsänderung > 20 %% -- die Reihen laufen auseinander.")
      }

      if (isTRUE(plot)) {
        op <- graphics::par(mfrow = c(2, 1), mar = c(4, 4, 3, 1))
        on.exit(graphics::par(op), add = TRUE)
        graphics::plot(lbl, as.numeric(diff), type = "b", pch = 19,
                       xlab = "", ylab = sprintf("%s - %s", st[1], st[2]),
                       main = "Differenzreihe: Bruch hier = Stationseffekt")
        graphics::abline(h = mean(diff), lty = 2, col = "grey50")
        pt <- out[["differenz pettitt"]]
        if (!is.null(pt)) graphics::abline(v = as.integer(pt$bruch), col = "red", lwd = 2)
        graphics::plot(cB, cA, type = "b", pch = 19,
                       xlab = sprintf("kumuliert %s", st[2]),
                       ylab = sprintf("kumuliert %s", st[1]),
                       main = "Doppelmassenkurve -- Knick = Bruchpunkt")
        graphics::text(cB, cA, labels = lbl, pos = 4, cex = 0.6, col = "grey40")
      }
    }
  }

  # --- Fazit -----------------------------------------------------------------
  log_info(TAG, "--- Konsequenz ---")
  log_info(TAG, "Jeder signifikante Bruch in der DIFFERENZreihe heisst: die Stationen")
  log_info(TAG, "sind nicht untereinander homogen. Trendaussagen erst nach")
  log_info(TAG, "Homogenisierung (Anpassung der Teilperioden an die jüngste).")
  log_info(TAG, "Für die App gilt bis dahin: Klimatologie ja, Trend nein.")

  invisible(out)
}

homogeneity()
