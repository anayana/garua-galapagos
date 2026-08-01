# =============================================================================
# run.R  --  Einstiegspunkt für die R-Konsole
#
# Arbeitsverzeichnis auf den Projektordner setzen, dann Zeile für Zeile
# ausführen. Kein Terminal, kein Rscript.
# =============================================================================

# setwd("C:/Users/A/Desktop/R/Galapagos")   # falls nötig

# --- einmalig ----------------------------------------------------------------
# install.packages(c("yaml", "curl", "readr", "terra", "sf",
#                    "httr2", "xml2", "jsonlite", "ncdf4", "ecmwfr"))


# --- alles Kleine auf einmal -------------------------------------------------
# Stationen + ENSO + DEM + Vegetation, wenige MB, kein Account nötig
source("download/download_all.R")


# --- oder einzeln ------------------------------------------------------------
# Jedes Skript läuft beim Sourcen sofort mit den Standardwerten durch und
# hinterlässt seine Funktion für weitere Aufrufe.

source("download/01_download_cdf_stations.R")
#   download_stations(with_raw = TRUE)          Rohdaten-XLS dazu
#   download_stations(overwrite = TRUE)         neu laden
#   download_stations(inspect = FALSE)          ohne Qualitätsbericht

source("download/02_download_enso.R")
#   download_enso(overwrite = TRUE)

source("download/03_download_dem.R")
#   download_dem(focus = TRUE)                  nur Santa Cruz statt Archipel
#   download_dem(keep_tiles = TRUE)             Volltiles zusätzlich ablegen

source("download/06_download_vegetation.R")
#   download_vegetation(all_islands = TRUE)     ganzes Archipel (11 Seiten)
#   download_vegetation(overwrite = TRUE)       neu laden und clippen


# --- Auswertung ---------------------------------------------------------------
# Zonale Statistik Vegetation x Höhe -- die Kerngrafik von Pane 2.
# Braucht DEM (03) und Vegetation (06). Bricht ab, wenn die Vegetationskarte
# nicht geometrisch geclippt ist.
source("analysis/01_zonal_vegetation_dem.R")
#   zonal_vegetation_dem(plot = TRUE)           mit Balkendiagramm
#   zonal_vegetation_dem(island = "archipel")   falls all_islands geladen wurde

# Nebeltage aus den Stationsdaten -- Kern von Pane 1. Braucht Stationen (01).
source("analysis/02_fog_definition.R")
#   fog_definition(plot = TRUE)                 Monatsklimatologie beider Stationen
#   fog_definition(dpd_max = 1.0, cl_min = 8)   strengere Definition
#   fog_definition(use_precip = FALSE)          ohne Niederschlagsfenster
#   fog_definition(use_clouds = FALSE)          ohne Bedeckungsgrad
#                                               -> beides zeigt, wie die Saisonalität kippt

# Bruchpunkte datieren. Braucht fog_annual.csv aus 02.
source("analysis/03_homogeneity.R")
#   homogeneity(plot = TRUE)                    Differenzreihe der Monatsanomalien
#   homogeneity(resolution = "annual")          alte Fassung auf Jahreswerten
#   homogeneity(min_days = 20)                  strengere Monatsabdeckung


# Landbedeckungs-Zeitreihe (MapBiomas Ecuador 1985-2024, ueber Earth Engine).
# Das Skript prueft nur, was vorliegt, und nennt die fehlenden Schritte.
source("download/07_download_lulc.R")

# Kartengrundlagen rastern (fuer den Karten-Tab). Braucht DEM + Vegetation.
source("analysis/04_maps.R")
#   build_maps(n = 600)                         feineres Raster


# --- Die App ------------------------------------------------------------------
# Braucht die drei analysis-Skripte oben. Nur shiny, sonst Basis-R --
# damit die spätere shinylive-Kompilierung (WebAssembly) zuverlässig läuft.
# install.packages("shiny")
shiny::runApp("app")


# --- Veroeffentlichen ---------------------------------------------------------
# NICHT shinyapps.io: das freie Kontingent ist auf wenige Apps begrenzt, und die
# Instanz schlaeft nach Inaktivitaet ein. Ein toter Link in der Bewerbung ist
# schlimmer als keiner.
#
# Stattdessen shinylive -> WebAssembly -> GitHub Pages: laeuft im Browser des
# Betrachters, kein Server, kein Kontingent, dauerhaft erreichbar.
#
# install.packages("shinylive")
source("analysis/05_app_assets.R")     # Daten in app/ kopieren (Browser hat kein ../)
# shinylive::export("app", "docs")
# httpuv::runStaticServer("docs")      # lokal pruefen
# danach docs/ committen und in den Repo-Einstellungen GitHub Pages auf docs/ stellen


# --- ERA5: braucht einen kostenlosen CDS-Account ------------------------------
# ecmwfr::wf_set_key(key = "<persönlicher Token>")     einmalig
# Danach im Webinterface die Lizenzbedingungen des Datensatzes akzeptieren,
# sonst antwortet jede Anfrage mit 403.

# source("download/04_download_era5.R")
#   download_era5(years = 2023:2024)
#   download_era5(years = 2024, only = "pressure", focus = TRUE)


# --- GOES: gross, deshalb erst zählen ----------------------------------------
# source("download/05_download_goes.R")
#   download_goes(dry_run = TRUE)                                nur auflisten
#   download_goes(start = "2024-07-01", end = "2024-07-31", hours = 6)
#   download_goes(subset = FALSE, keep_full = TRUE)              ohne Zuschnitt


# --- Ergebnisse ansehen -------------------------------------------------------
# bell <- readr::read_csv("data/raw/stations/climate_bellavista.csv")
# veg  <- sf::st_read("data/raw/vegetation/ecosistemas_nativos_2016_SantaCruz.gpkg")
# read.csv("data/raw/vegetation/flaechenbilanz_SantaCruz.csv")
# dem  <- terra::rast("data/raw/dem/copernicus_dem30_archipel.tif"); terra::plot(dem)
