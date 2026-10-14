# =============================================================================
# 00_run_all.R -- Run the complete analysis pipeline end to end
# -----------------------------------------------------------------------------
# Usage (from the project root):
#     source("R/00_run_all.R")
# Produces: data/processed/*  and  figures/*.png
# =============================================================================

# Make sure the working directory is the project root.
p <- normalizePath(getwd())
for (i in 1:6) {
  if (file.exists(file.path(p, "R", "00_setup.R"))) break
  p <- normalizePath(file.path(p, ".."))
}
if (!identical(p, normalizePath(getwd()))) setwd(p)

source("R/00_setup.R")
source("R/01_preprocess.R")
source("R/02_eda.R")
source("R/03_modeling.R")
source("R/04_replication.R")

cat("\n[run_all] Pipeline complete. See data/processed/ and figures/.\n")
