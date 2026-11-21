# Verify changing ACS cells against cached official table metadata before download.
source("R/model_display_config.R")
source("R/acs_helpers.R")
cfg <- model_display_config
directory <- "data/raw_data/model_display_metadata"
dir.create(directory,recursive=TRUE,showWarnings=FALSE)
metadata <- list()
for(table in c("B25036","B25038","B25042","B25032","B25007")) {
  path <- file.path(directory,sprintf("%d_%s.json",cfg$year,table))
  cache_download(sprintf("https://api.census.gov/data/%d/acs/acs5/groups/%s.json",cfg$year,table),path)
  metadata[[table]] <- jsonlite::read_json(path)$variables
}
label <- function(code) {
  table <- sub("_.*$","",code)
  metadata[[table]][[paste0(code,"E")]]$label
}
for(group in c("age","movers","bedrooms","structures","renter_age")) {
  codes <- model_display_groups[[group]]
  labels <- vapply(codes,label,character(1))
  stopifnot(all(grepl("Renter[- ]occupied",labels,ignore.case=TRUE)))
}
stopifnot(grepl("1939 or earlier",label(model_display_groups$age[["age_pre1940"]])))
built_codes <- model_display_groups$age[model_display_shares$built2000_plus$numerator]
stopifnot(all(grepl("Built (2000|2010|2014|2020)",vapply(built_codes,label,character(1)))))
move_codes <- model_display_groups$movers[model_display_shares$recent_movers$numerator]
move_labels <- vapply(move_codes,label,character(1))
cutoffs <- as.integer(sub(".*Moved in ([0-9]{4}).*","\\1",move_labels))
stopifnot(min(cutoffs)==cfg$year-4L)
dir.create(cfg$analytic_dir,recursive=TRUE,showWarnings=FALSE)
codebook <- dplyr::bind_rows(lapply(names(model_display_shares),function(name) {
  definition <- model_display_shares[[name]]
  codes <- unlist(model_display_groups,use.names=FALSE)
  aliases <- unlist(lapply(model_display_groups,names),use.names=FALSE)
  names(codes) <- aliases
  data.frame(measure=paste0(name,"_pct"),year=cfg$year,
    numerator=paste(unname(codes[definition$numerator]),collapse=" + "),
    denominator=paste(unname(codes[definition$denominator]),collapse=" + "),
    unit="percent",recent_move_cutoff=if(name=="recent_movers")cfg$year-4L else NA_integer_)
}))
readr::write_csv(codebook,file.path(cfg$analytic_dir,"derived_codebook.csv"))
message("PASS ",cfg$year,": historical Census labels and move-in cutoff")
