# After running mimic_make_flfv.R, clean up the data a bit.

library(tidyverse)
library(data.table)

setwd('../../../data/mimic/anypna/')
dats = data.frame(filenames = list.files(), stringsAsFactors=F) %>% as_tibble() %>% 
  filter(str_detect(filenames, "^mimic_.*pna")) %>% 
  mutate(data = map(filenames, ~ fread(.x) %>% as_tibble()))

numeric_cleaner = function(dat) {
  dat %>% mutate_all(as.character) %>%
    mutate_all((function(.) str_remove_all(., "<|>|LESS THAN |GREATER THAN|\\*"))) %>%
    mutate_all((function(.) str_replace_all(., "([0-9])-[0-9]+","\\1"))) %>%
    mutate_all((function(.) str_remove_all(., "^\\*$|^ERROR|^no data|^\\.$"))) %>%
    mutate_all((function(.) ifelse(.=="", NA,.))) %>%
    write_csv("tmp.csv")
  fread("tmp.csv") %>% as_tibble()
}

dats %>%
  mutate(cleaner = map(data, ~ numeric_cleaner(.x))) %>%
  mutate(writer = map2(filenames, cleaner,
                       ~ write_delim(.y, paste0("cleaner_", .x), delim="|"))) %>%
  select(-writer)
