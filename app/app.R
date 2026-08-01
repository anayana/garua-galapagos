# =============================================================================
# app.R -- "Garúa & Scalesia": methodische Vorstudie Galápagos
#
# Zwei Panes, beide auf realen, offen verfügbaren Daten:
#   Pane 1  Nebelklimatologie  -- CDF-Stationsdaten Puerto Ayora / Bellavista
#   Pane 2  Der Wald           -- USFQ-Vegetationskarte x Copernicus GLO-30
#
# Bewusste Entscheidungen:
#   - Nur Basis-Grafik, kein ggplot2/leaflet. Weniger Abhängigkeiten heisst
#     zuverlässigere shinylive-Kompilierung (WebAssembly, läuft ohne Server).
#   - Alle Eingangsdaten sind vorberechnete CSV aus analysis/. Die App rechnet
#     nur noch Schwellen um -- sie lädt nichts nach und braucht kein Netz.
#   - Datenherkunft und Grenzen stehen im Interface, nicht im Kleingedruckten.
#
# Voraussetzung: analysis/02_fog_definition.R und 03_homogeneity.R sind
# gelaufen, analysis/01_zonal_vegetation_dem.R ebenfalls.
#
# Start (Arbeitsverzeichnis = Projektordner Galapagos):
#   shiny::runApp("app")
# =============================================================================

library(shiny)

# --- Daten einmalig laden -----------------------------------------------------
# Lokal liegen die Daten im Projektordner, im shinylive-Bundle unterhalb von
# app/ -- im Browser gibt es kein uebergeordnetes Verzeichnis.
# app/data/processed wird von analysis/05_app_assets.R gefuellt.
PROC <- file.path("..", "data", "processed")
if (!dir.exists(PROC)) PROC <- file.path("data", "processed")
if (!dir.exists(PROC)) {
  stop("Keine Daten gefunden. Erst analysis/01..04 laufen lassen, ",
       "fuer das Browser-Bundle zusaetzlich analysis/05_app_assets.R.")
}

# RDS bevorzugen (kleiner, schnell), CSV als Rueckfall beim lokalen Lauf.
lies <- function(stamm) {
  rds <- file.path(PROC, paste0(stamm, ".rds"))
  csv <- file.path(PROC, paste0(stamm, ".csv"))
  if (file.exists(rds)) return(readRDS(rds))
  if (file.exists(csv)) return(utils::read.csv(csv, stringsAsFactors = FALSE))
  NULL
}

DAILY <- lies("fog_daily")
if (is.null(DAILY)) stop("fog_daily fehlt -- erst analysis/02_fog_definition.R")
DAILY$observation_date <- as.Date(DAILY$observation_date)
DAILY$jahr  <- as.integer(format(DAILY$observation_date, "%Y"))
DAILY$monat <- as.integer(format(DAILY$observation_date, "%m"))

ZONAL <- lies("zonal_vegetation_dem_SantaCruz")
if (is.null(ZONAL)) stop("Zonale Statistik fehlt -- erst analysis/01_zonal_vegetation_dem.R")

BREAKS <- lies("homogeneity_breaks")
if (!is.null(BREAKS)) {
  BREAKS$jahr <- as.numeric(substr(BREAKS$bruch, 1, 4)) +
                 (as.numeric(substr(BREAKS$bruch, 6, 7)) - 0.5) / 12
}

STATIONEN <- c("Bellavista", "Puerto Ayora")
HOEHE     <- c(Bellavista = 223, "Puerto Ayora" = 2)

# Kartengrundlagen (analysis/04_maps.R). Fehlen sie, bleibt der Karten-Tab
# leer statt die ganze App abstürzen zu lassen.
MAPS <- if (file.exists(file.path(PROC, "maps_SantaCruz.rds"))) {
  readRDS(file.path(PROC, "maps_SantaCruz.rds"))
} else NULL

# Externe 3D-Szenen (For3Dsuite). Bewusst als iframe statt Nachbau: die Szenen
# laufen bereits, sind aus echten Daten gerechnet und brauchen kein WebGL im
# Shiny-Prozess.
SZENEN <- c(
  "Rainforest Trail — 360°-Panorama" =
    "https://anayana.github.io/For3Dsuite/scene.html?id=ph-rainforest-trail"
)

# --- Nebelflag live aus den Schwellen ----------------------------------------
# dpd liegt in fog_daily.csv bereits vor -- die App muss nur neu schwellen.
flag <- function(d, dpd_max, cl_min, p_min, p_max, use_clouds, use_precip) {
  ok <- is.finite(d$dpd)
  f  <- d$dpd <= dpd_max
  if (use_clouds) { ok <- ok & is.finite(d$clouds);        f <- f & d$clouds >= cl_min }
  if (use_precip) { ok <- ok & is.finite(d$precipitation)
                    f <- f & d$precipitation >= p_min & d$precipitation <= p_max }
  ifelse(ok, f & ok, NA)
}

# =============================================================================
ui <- fluidPage(
  tags$head(tags$style(HTML("
    body { font-family: system-ui, sans-serif; }
    .kopf { background:#f4f4f2; border-left:4px solid #555; padding:10px 14px;
            margin-bottom:14px; font-size:13px; line-height:1.5; }
    .warn { background:#fdf3e7; border-left:4px solid #c87137; padding:10px 14px;
            margin:10px 0; font-size:13px; line-height:1.5; }
    .kennz { font-size:22px; font-weight:600; }
    .klein { color:#666; font-size:12px; }
  "))),

  titlePanel("Garúa & Scalesia — methodische Vorstudie Galápagos"),

  div(class = "kopf",
      "Datenquellen: Klimadaten „Galapagos Climatology Database\", dataZone,",
      "Charles Darwin Foundation (CC BY-NC-SA 4.0) · Vegetationskarte",
      "A_ECOSISTEMAS_NATIVOS_2016, Instituto de Geografía, USFQ ·",
      "Copernicus DEM GLO-30."),

  tabsetPanel(
    # ---------------------------------------------------------------- Pane 1
    tabPanel(
      "1 — Nebelklimatologie",
      br(),
      sidebarLayout(
        sidebarPanel(
          width = 3,
          h4("Definition des Nebeltags"),
          p(class = "klein",
            "Ein Nebeltag ist über Schwellenwerte definiert, nicht gemessen.",
            "Die Ereigniszahl hängt von der Wahl der Schwellen ab."),
          sliderInput("dpd", "Taupunktdifferenz höchstens (K)",
                      0.25, 3, 1.5, step = 0.25),
          checkboxInput("use_cl", "Bedeckungsgrad einbeziehen", TRUE),
          conditionalPanel("input.use_cl",
            sliderInput("cl", "Bedeckung mindestens (Achtel)", 4, 8, 7, step = 1)),
          checkboxInput("use_p", "Niederschlagsfenster einbeziehen", TRUE),
          conditionalPanel("input.use_p",
            sliderInput("p", "Niederschlag (mm)", 0, 20, c(0.1, 5), step = 0.1))
        ),
        mainPanel(
          width = 9,
          fluidRow(
            column(4, div(class = "kennz", textOutput("k_bella")),
                      div(class = "klein", "Bellavista, 223 m — Nebeltage")),
            column(4, div(class = "kennz", textOutput("k_pa")),
                      div(class = "klein", "Puerto Ayora, 2 m — Nebeltage")),
            column(4, div(class = "kennz", textOutput("k_kontrast")),
                      div(class = "klein", "Kontrast Hochland / Küste"))
          ),
          hr(),
          h4("Jahresgang"),
          p(class = "klein", "Grau hinterlegt: Garúa-Saison (Juni–Dezember)."),
          plotOutput("p_klima", height = "300px"),
          hr(),
          h4("Jahresreihe"),
          plotOutput("p_jahr", height = "300px"),
          uiOutput("u_brueche")
        )
      )
    ),

    # ---------------------------------------------------------------- Pane 2
    tabPanel(
      "2 — Der Wald",
      br(),
      fluidRow(
        column(3,
          h4("Santa Cruz, Höhenprofil"),
          p(class = "klein",
            "Zonale Statistik: Vegetationskarte über das DEM gerastert,",
            "Fläche je 100-m-Höhenband."),
          checkboxGroupInput("kl", "Klassen",
            choices  = c("Evergreen Forest and Shrubland", "Invasive Species",
                         "Agricultural Lands", "Humid Tallgrass"),
            selected = c("Evergreen Forest and Shrubland", "Invasive Species",
                         "Agricultural Lands")),
          hr(),
          p(class = "klein", strong("Auflösungsgrenze:"),
            "30 m, Maßstab 1:60.000. Der Bestand Los Gemelos (~140 ha) ist damit",
            "rund 15 Pixel breit — tauglich für Zonenaussagen, nicht für",
            "Bestandesebene.")
        ),
        column(9,
          plotOutput("p_wald", height = "420px"),
          tableOutput("t_wald")
        )
      )
    ),

    # ---------------------------------------------------------------- Pane 3
    tabPanel(
      "3 — Karten",
      br(),
      if (is.null(MAPS)) {
        div(class = "warn", strong("Kartengrundlagen fehlen."),
            "Erst ", code("source(\"analysis/04_maps.R\")"), " laufen lassen.")
      } else {
        sidebarLayout(
          sidebarPanel(
            width = 3,
            radioButtons("karte", "Ebene",
              choices = c("Vegetationsklassen 2016" = "veg",
                          "Höhe (GLO-30)"           = "dem",
                          "Nebelgürtel-Höhenband"   = "fog")),
            conditionalPanel("input.karte == 'fog'",
              sliderInput("band", "Höhenband (m)", 0, 900, c(100, 700), step = 50)),
            checkboxInput("st", "Stationen zeigen", TRUE)
          ),
          mainPanel(
            width = 9,
            plotOutput("p_karte", height = "520px"),
            uiOutput("u_karte_txt")
          )
        )
      }
    ),

    # ---------------------------------------------------------------- Pane 4
    tabPanel(
      "4 — 3D-Ansicht",
      br(),
      fluidRow(
        column(12,
          h4("Rainforest Trail — begehbares 360°-Panorama"),
          p(class = "klein",
            "Szene aus", a("For3Dsuite",
              href = "https://anayana.github.io/For3Dsuite/", target = "_blank"),
            "— nicht Galápagos. Panorama von Poly Haven, CC0",
            "(Dimitrios Savva, Jarod Guest)."),
          br(),
          tags$a(href = SZENEN[[1]], target = "_blank", rel = "noopener",
                 class = "btn btn-primary btn-lg",
                 "Szene in neuem Tab öffnen"),
          br(), br(),
          p(class = "klein",
            "Die Szene wird nicht eingebettet, sondern verlinkt: Diese App",
            "läuft als WebAssembly und setzt dafür",
            code("Cross-Origin-Embedder-Policy: require-corp"), "—",
            "der Browser blockiert damit eingebettete Inhalte von fremden",
            "Adressen (Fehlercode NS_ERROR_DOM_COEP_FAILED).")
        )
      )
    )
  )
)

# =============================================================================
server <- function(input, output, session) {

  dat <- reactive({
    d <- DAILY
    d$fog <- flag(d, input$dpd, input$cl, input$p[1], input$p[2],
                  isTRUE(input$use_cl), isTRUE(input$use_p))
    d
  })

  raten <- reactive({
    d <- dat()
    vapply(STATIONEN, function(s) mean(d$fog[d$station == s], na.rm = TRUE), numeric(1))
  })

  output$k_bella   <- renderText(sprintf("%.1f %%", 100 * raten()[["Bellavista"]]))
  output$k_pa      <- renderText(sprintf("%.1f %%", 100 * raten()[["Puerto Ayora"]]))
  output$k_kontrast <- renderText({
    r <- raten(); sprintf("%.2f×", r[["Bellavista"]] / r[["Puerto Ayora"]])
  })

  # --- Jahresgang ------------------------------------------------------------
  output$p_klima <- renderPlot({
    d <- dat()
    m <- sapply(STATIONEN, function(s) {
      x <- d[d$station == s, ]
      tapply(x$fog, factor(x$monat, levels = 1:12), function(v) mean(v, na.rm = TRUE))
    })
    m[!is.finite(m)] <- 0

    op <- par(mar = c(4, 4.5, 1, 1)); on.exit(par(op))
    plot(NA, xlim = c(0.5, 12.5), ylim = c(0, max(100 * m, 5)),
         xaxt = "n", xlab = "", ylab = "Nebeltage (% der Tage)", las = 1)
    rect(5.5, -5, 12.5, 200, col = "#ececec", border = NA)   # Garúa-Saison
    box()
    axis(1, 1:12, month.abb)
    for (i in seq_along(STATIONEN)) {
      lines(1:12, 100 * m[, i], type = "b", pch = 19, lwd = 2,
            col = c("#1f4e79", "#c87137")[i])
    }
    legend("topleft", STATIONEN, col = c("#1f4e79", "#c87137"),
           lwd = 2, pch = 19, bty = "n")
  })

  # --- Jahresreihe mit Bruchmarken -------------------------------------------
  output$p_jahr <- renderPlot({
    d <- dat()
    op <- par(mar = c(4, 4.5, 1, 1)); on.exit(par(op))
    plot(NA, xlim = range(d$jahr), ylim = c(0, 100),
         xlab = "", ylab = "Nebeltage (% der Tage)", las = 1)

    # Bruchpunkte als dezente Marken auf der Grundlinie statt als Linien durch
    # die ganze Grafik -- sie sind Kontext, nicht Gegenstand.
    if (!is.null(BREAKS)) {
      sk <- abs(BREAKS$sprung) / max(abs(BREAKS$sprung))
      segments(BREAKS$jahr, 0, BREAKS$jahr, 4 + 6 * sk, col = "#7a7a7a", lwd = 2)
      points(BREAKS$jahr, 4 + 6 * sk, pch = 25, cex = 0.6 + 0.7 * sk,
             col = "#7a7a7a", bg = "#7a7a7a")
    }
    for (i in seq_along(STATIONEN)) {
      x <- d[d$station == STATIONEN[i], ]
      a <- tapply(x$fog, x$jahr, function(v) mean(v, na.rm = TRUE))
      n <- tapply(!is.na(x$fog), x$jahr, sum)
      a[n < 200] <- NA                     # Jahre mit Datenlücke nicht zeichnen
      lines(as.numeric(names(a)), 100 * a, type = "b", pch = 19, lwd = 2,
            col = c("#1f4e79", "#c87137")[i])
    }
    legend("topright", c(STATIONEN, "Bruchpunkte"),
           col = c("#1f4e79", "#c87137", "#7a7a7a"), lwd = 2,
           pch = c(19, 19, 25), pt.bg = "#7a7a7a", bty = "n", bg = "white")
  })

  output$u_brueche <- renderUI({
    if (is.null(BREAKS)) return(NULL)
    p(class = "klein",
      sprintf(paste("Graue Dreiecke: %d Zeitpunkte, an denen der Abstand",
                    "zwischen den beiden Stationen plötzlich springt.",
                    "Wetter trifft beide Stationen gleichzeitig — springt nur",
                    "der Abstand, hat sich an einer Station die Messung",
                    "geändert, nicht das Klima. Je grösser das Dreieck, desto",
                    "grösser der Sprung (%.0f bis %.0f Prozentpunkte)."),
              nrow(BREAKS), 100 * min(abs(BREAKS$sprung)),
              100 * max(abs(BREAKS$sprung))))
  })

  # --- Pane 2 ----------------------------------------------------------------
  wald <- reactive({
    z <- ZONAL[ZONAL$klasse %in% input$kl, ]
    if (!nrow(z)) return(NULL)
    ord <- c("0-100 m", "100-200 m", "200-300 m", "300-400 m",
             "400-500 m", "500-600 m", "600-700 m", "700-900 m")
    m <- tapply(z$ha, list(factor(z$band, levels = ord), z$klasse), sum)
    m[is.na(m)] <- 0
    m
  })

  output$p_wald <- renderPlot({
    m <- wald(); if (is.null(m)) return(NULL)
    op <- par(mar = c(4, 8, 2, 1)); on.exit(par(op))
    cols <- c("Evergreen Forest and Shrubland" = "#2d6a4f",
              "Invasive Species"               = "#c0392b",
              "Agricultural Lands"             = "#d4a017",
              "Humid Tallgrass"                = "#7f8c8d")
    barplot(t(m), beside = TRUE, horiz = TRUE, las = 1,
            col = cols[colnames(m)], border = NA,
            xlab = "Fläche (ha)",
            main = "Vegetationsklassen über Höhe — Santa Cruz")
    legend("bottomright", colnames(m), fill = cols[colnames(m)],
           bty = "n", cex = 0.9, border = NA)
  })

  output$t_wald <- renderTable({
    m <- wald(); if (is.null(m)) return(NULL)
    out <- data.frame(Höhenband = rownames(m), round(m), check.names = FALSE)
    rbind(out, data.frame(Höhenband = "Summe", t(round(colSums(m))),
                          check.names = FALSE))
  }, digits = 0, striped = TRUE)

  # --- Pane 3: Karten --------------------------------------------------------
  output$p_karte <- renderPlot({
    req(MAPS)
    op <- par(mar = c(4, 4, 2, 1)); on.exit(par(op))

    if (input$karte == "dem") {
      image(MAPS$x, MAPS$y, MAPS$dem, col = terrain.colors(40),
            xlab = "Länge", ylab = "Breite", asp = 1,
            main = "Höhe — Copernicus DEM GLO-30")
      contour(MAPS$x, MAPS$y, MAPS$dem, levels = seq(100, 800, 100),
              add = TRUE, col = "#00000055", labcex = 0.7)

    } else if (input$karte == "fog") {
      # Das Höhenband, in dem der Nebelgürtel liegt -- der direkte Bezug
      # zwischen Pane 1 (Nebel über Höhe) und Pane 2 (Wald über Höhe).
      m <- MAPS$dem
      sel <- m >= input$band[1] & m <= input$band[2]
      image(MAPS$x, MAPS$y, m, col = grey.colors(30, 0.35, 0.95),
            xlab = "Länge", ylab = "Breite", asp = 1,
            main = sprintf("Höhenband %d–%d m", input$band[1], input$band[2]))
      image(MAPS$x, MAPS$y, ifelse(sel, 1, NA), col = "#1f4e79aa", add = TRUE)

    } else {
      k   <- MAPS$klassen
      pal <- rep("#e8e8e4", length(k))
      names(pal) <- k
      for (nm in names(pal)) {
        if (grepl("^Evergreen Forest", nm))   pal[nm] <- "#2d6a4f"
        if (grepl("^Invasive", nm))           pal[nm] <- "#c0392b"
        if (grepl("^Agricultural", nm))       pal[nm] <- "#d4a017"
        if (grepl("^Humid Tallgrass", nm))    pal[nm] <- "#7f8c8d"
        if (grepl("^Evergreen Seasonal", nm)) pal[nm] <- "#95c623"
        if (grepl("Lava", nm))                pal[nm] <- "#6d6875"
        if (grepl("Mangrove", nm))            pal[nm] <- "#1b7f79"
        if (grepl("Urban", nm))               pal[nm] <- "#000000"
      }
      image(MAPS$x, MAPS$y, MAPS$veg, col = pal,
            zlim = c(0.5, length(k) + 0.5),
            xlab = "Länge", ylab = "Breite", asp = 1,
            main = "Vegetationsklassen 2016 — USFQ")
      zeig <- k[k %in% c("Evergreen Forest and Shrubland", "Invasive Species",
                         "Agricultural Lands", "Humid Tallgrass",
                         "Evergreen Seasonal Forest")]
      legend("bottomleft", zeig, fill = pal[zeig], bty = "n",
             cex = 0.8, border = NA, bg = "#ffffffcc")
    }

    if (isTRUE(input$st)) {
      s <- MAPS$stationen
      points(s$lon, s$lat, pch = 21, bg = "white", col = "black", cex = 1.6, lwd = 2)
      text(s$lon, s$lat, sprintf("%s (%d m)", s$name, s$hoehe),
           pos = 4, cex = 0.85, font = 2)
    }
  })

  output$u_karte_txt <- renderUI({
    if (identical(input$karte, "veg")) {
      p(class = "klein",
        "A_ECOSISTEMAS_NATIVOS_2016, Instituto de Geografía USFQ.",
        "Landsat-8/OLI, 30 m, 1:60.000, Zeitschnitt 2016.")
    } else if (identical(input$karte, "fog")) {
      p(class = "klein",
        "Bodenmessungen liegen nur für 2 m (Puerto Ayora) und 223 m",
        "(Bellavista) vor. Das Band ist eine Auswahl, keine gemessene Grenze.")
    } else NULL
  })

  # --- Pane 4: 3D ------------------------------------------------------------
  # Der 3D-Tab ist rein statisch (Link statt iframe, siehe COEP-Hinweis dort).
}

shinyApp(ui, server)
