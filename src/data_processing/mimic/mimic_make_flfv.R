# Run this after mimic3buildtimeline.R

library(ggplot2)
library(ggthemes)
library(DT)

library(tidyverse)
library(shiny)
library(data.table)
library(zip)

keyword = "mimic_anypna_timeline"

setwd('../../../data/mimic/')
dat = fread(paste0("anypna/",keyword,".csv")) %>% as_tibble() %>%
  rename(hosp_id=pt, TIME=t) %>% mutate(TIME=as.numeric(TIME))
dat = dat %>% filter(hosp_id %in% (dat %>% filter(event=="inicu") %>% .[["hosp_id"]] %>% unique()))
smoking = fread("mimic3/smoking.tsv") %>% as_tibble()
codx = fread("mimic3/codx.tsv") %>% as_tibble()
codx = codx %>% 
  group_by(subject_id) %>% summarise_all(mean) %>% 
  mutate_all((function(.) round(.-0.25))) %>%  # set to 1 only if 1 most of the time (>3/4)
  select(subject_id, congestive_heart_failure, renal_failure, liver_disease, lymphoma, metastatic_cancer) %>%
  mutate(cancer = lymphoma + metastatic_cancer > 0) %>% select(-lymphoma, -metastatic_cancer)


find_and_label = function(dat, pattern, renameto=NULL) {
  if(is.null(renameto)) {
    dat %>% filter(str_detect(event, pattern=pattern))
  } else {
    dat %>% filter(str_detect(event, pattern=pattern)) %>% mutate(event=renameto)
  }
}

gcs_motor = dat %>% 
  filter(str_detect(event, "chart:gcs - motor response:")) %>%
  select(event,value) %>% table() %>% as.data.frame() %>% as_tibble() %>% arrange(value) %>%
  mutate(score=c(2,3,4,5,1,6))
gcs_verbal = dat %>% 
  filter(str_detect(event, "chart:gcs - verbal response:")) %>%
  select(event,value) %>% table() %>% as.data.frame() %>% as_tibble() %>% arrange(value) %>%
  mutate(score=c(4,3,2,1,1,5))
gcs_eye = dat %>%
  filter(str_detect(event, "chart:gcs - eye opening:")) %>%
  select(event,value) %>% table() %>% as.data.frame() %>% as_tibble() %>% arrange(value) %>%
  mutate(score=c(1,4,2,3))
pna_gcs = bind_rows(
  dat %>% filter(str_detect(event, "chart:gcs - motor response:")) %>%
  left_join(gcs_motor %>% select(value,score), by="value") %>% mutate(value=score) %>% select(-score),
  dat %>% filter(str_detect(event, "chart:gcs - verbal response:")) %>%
    left_join(gcs_verbal %>% select(value,score), by="value") %>% mutate(value=score) %>% select(-score),
  dat %>% filter(str_detect(event, "chart:gcs - eye opening:")) %>%
    left_join(gcs_eye %>% select(value,score), by="value") %>% mutate(value=score) %>% select(-score)
) %>%
  nest(-hosp_id,-TIME) %>% mutate(count=map_dbl(data, ~ nrow(.x))) %>%
  filter(count==3) %>% unnest() %>%
  group_by(hosp_id, TIME) %>% summarise(value=as.character(sum(value))) %>% ungroup() %>%
  mutate(event="chart:gcs total:points") %>%
  select(hosp_id, TIME, event, value)
rm("gcs_motor","gcs_eye","gcs_verbal"); gc(reset=T)

orientation = dat %>%
  filter(str_detect(event, "chart:orientation:")) %>% 
  select(value) %>% table() %>% as.data.frame() %>% as_tibble() %>%
  (function(.) {names(.) = c("Status", "Count"); .})(.) %>%
  arrange(Status) %>%
  filter(str_detect(Status, "[a-zA-Z]")) %>%
  mutate(score=c(0,1,1,2,2,4,4,NA,NA),
         Status = as.character(Status))
pna_orientation = dat %>%
  filter(str_detect(event, "chart:orientation:")) %>%
  left_join(orientation %>% select(Status,score), by=c("value"="Status")) %>%
  mutate(value=as.character(score)) %>% select(-score)
rm(orientation); gc()

### update dat to include precompute features: gcs and orientation
dat = bind_rows(dat, pna_gcs, pna_orientation)

find_and_labels = 
  c(
    c("chart:gcs total:points","gcs"),
    c("chart:respiratory rate:insp/min|chart:respiratory rate:bpm|chart:respiratory rate \\(total\\):insp/min|chart:resp rate \\(total\\):bpm","respiratory rate"),
    c("chart:nbp \\[systolic\\]:mmhg|chart:non invasive blood pressure systolic:mmhg|chart:arterial bp \\[systolic\\]:mmhg|chart:art bp systolic:mmhg",
      "systolic bp"),
    c("chart:nbp \\[diastolic\\]:mmhg|chart:non invasive blood pressure diastolic:mmhg|chart:arterial bp \\[diastolic\\]:mmhg|chart:art bp diastolic:mmhg",
      "diastolic bp"),
    c("chart:non invasive blood pressure mean:mmhg|chart:arterial blood pressure mean:mmhg|chart:nbp mean:mmhg|chart:art bp mean:mmhg|chart:arterial bp mean:mmhg", "mean arterial pressure"),
    c("lab:blood:hematology:lymphocytes","lymphocyte count"),
    c("chart:heart rate:bpm","heart rate"),
    c("lab:blood:blood gas:temperature|chart:temperature c \\(calc\\):deg. c","temperature"),
    c("lab:blood:blood gas:ph|chart:art.ph:|chart:arterial ph:", "ph"),
    c("lab:blood:chemistry:sodium","sodium"),
    c("lab:blood:chemistry:glucose|chart:fingerstick glucose:|chart:glucose:","glucose"),
    c("lab:blood:hematology:hemoglobin|chart:hemoglobin:","hemoglobin"),
    c("chart:arterial pao2:mmhg|lab:blood:blood gas:po2","pao2"),
    c("lab:blood:hematology:ptt","ptt"),
    c("lab:blood:hematology:pt$","pt"),
    c("hematology:fibrinogen","fibrinogen"),
    c("d-dimer","d-dimer"),
    c("asparate aminotransferase \\(ast\\)", "ast"),
    c("alanine aminotransferase \\(alt\\)","alt"),
    c("lab:blood:chemistry:creatinine","creatinine"),
    c("lab:blood:chemistry:troponin|chart:troponin:","troponin"),
    c("lab:blood:chemistry:lactate dehydrogenase","ldh"),
    c("lab:blood:hematology:rdw","rdw"),
    c("lab:blood:chemistry:urea nitrogen","bun"),
    c("lab:blood:hematology:mcv","mcv"),
    c("lab:blood:hematology:red blood cells","rbcs"),
    c("lab:blood:hematology:platelet count","platelets"),
    c("lab:blood:hematology:mchc","mchc"),
    c("lab:blood:hematology:hematocrit","hct"),
    c("lab:blood:hematology:mch$","mch"),
    c("chart:sao2:","sao2"),
    c("lab:blood:chemistry:albumin","albumin"),
    c("lab:blood:chemistry:bilirubin, total|chart:total bilirubin:mg/dl","total bilirubin"),
    c("chart:potassium \\(serum\\):meq/l|potassium, whole blood|lab:blood:chemistry:potassium","potassium"),
    c("chart:chloride \\(serum\\):meq/l|chloride, whole blood|lab:blood:chemistry:chloride","chloride"),
    c("chart:tco2 \\(calc\\) arterial:meq/l|lab:blood:chemistry:bicarbonate|calculated total co2|calculated bicarbonate, whole blood","bicarbonate"),
    c("lab:blood:chemistry:calcium, total|chart:calcium non-ionized:mg/dl","calcium"),
    c("lab:blood:chemistry:albumin|chart:albumin:g/dl","albumin"),
    c("lab:blood:chemistry:alkaline phosphatase|chart:alkaline phosphate:iu/l","alkaline phosphatase"),
    c("chart:wbc:k/ul|lab:blood:hematology:white blood cells","wbc"),
    c("lab:blood:hematology:neutrophils","neutrophils"),
    c("lab:blood:hematology:monocytes","monocytes"),
    c("lab:blood:hematology:eosinophils","eosinophils"),
    c("lab:blood:hematology:basophils","basophils"),
    c("lab:blood:hematology:eosinophils","eosinophils"),
    c("lab:blood:hematology:bands","bands"),
    c("lab:blood:chemistry:c-reactive protein","crp"),
    c("bilirubin, direct","dbili"),
    c("protein, total","total protein"),
    c("chart:orientation:","orientation")
    
  ) %>% matrix(ncol = 2, byrow = T) %>% data.frame(stringsAsFactors=F) %>%
  (function(.) {names(.) = c("regexp","feature_name"); . })(.) %>%
  as_tibble()

### now extract other the selected features
pna_features_part1 = 
  dat %>% filter(str_detect(event, pattern="birthed|^gender:|^ethnicity:|inicu|outicu|lab:blood:chemistry:ferritin|codx.*pleural effusion"))

ethnicity_conversion = 
  read_csv("../data/anypna/Ethnicities.csv") %>% 
  mutate(outs = c("Caucasian",
                  "African American",
                  "Other",
                  "Hispanic",
                  "Other",
                  "Asian",
                  "Other",
                  "Asian",
                  "Hispanic",
                  "Other",
                  "African American",
                  "Hispanic",
                  "African American",
                  "Hispanic",
                  "Caucasian",
                  "Asian",
                  "Other",
                  "Other",
                  "Other",
                  "Other",
                  "Other")) %>%
  mutate(ETHNICITY = str_to_lower(ETHNICITY)) %>% select(-count)

pna_features = bind_rows(
    pna_features_part1 %>% filter(event=="birthed"),
    pna_features_part1 %>% filter(str_detect(event, pattern="^gender:")) %>% 
      mutate(value=event) %>% mutate(event="gender"),
    pna_features_part1 %>% filter(str_detect(event, pattern="^ethnicity:")) %>% 
      mutate(value=event) %>% mutate(event="ethnicity") %>%
      left_join(ethnicity_conversion, by=c("value"="ETHNICITY")) %>% mutate(value=outs) %>% select(-outs),
    pna_features_part1 %>% filter(str_detect(event, pattern="inicu|outicu")),
    pna_features_part1 %>% find_and_label("lab:blood:chemistry:ferritin","ferritin") %>% 
      mutate(value=ifelse(value=="GREATER THAN 2000", 2000,value)),
    pna_features_part1 %>% filter(str_detect(event, pattern="codx.*pleural effusion")) %>%
      mutate(TIME=min(TIME), event="pleural_effusion", value=as.character(1))
  )

pna_features_part2 = 
  find_and_labels %>% mutate(result = map2(regexp, feature_name,
                                           ~ dat %>% find_and_label(.x, .y)
  )) %>% select(result) %>% unnest(cols=c(result))

pna_features = pna_features %>% bind_rows(pna_features_part2)

pna_outcomes = bind_rows(  # value is the time of outcome from inicu (in days)
  dat %>% filter(str_detect(event, pattern="inicu")),
  dat %>% find_and_label("henylephrine|pinephrine|asopressin|ilrinone|obutamine|opamine","vasopressor"),  #
  dat %>% find_and_label("ventilator","mechanical ventilation"),  #
) %>% 
  group_by(hosp_id) %>%
  mutate(inicuTIME = ifelse(event=="inicu",TIME,NA)) %>%
  mutate(inicuTIME = min(inicuTIME, na.rm = T)) %>%
  filter(event=="vasopressor" | event=="mechanical ventilation") %>%
  mutate(value=(TIME-inicuTIME)/24/60/60) %>% ungroup() %>%
  select(hosp_id, event, value) %>%
  pivot_wider(names_from=event, values_from=value, values_fn=list(value=first))

pna_death =
  dat %>% filter(str_detect(event, pattern="inicu|outicu|deceased")) %>%
  group_by(hosp_id) %>%
  mutate(inicuTIME = ifelse(event=="inicu",TIME,NA)) %>%
  mutate(inicuTIME = min(inicuTIME, na.rm = T)) %>%
  mutate(outicuTIME = ifelse(event=="outicu",TIME,NA)) %>%
  mutate(outicuTIME = min(outicuTIME, na.rm=T)) %>%
  mutate(deceasedTIME = ifelse(event=="deceased",TIME,NA)) %>%
  mutate(deceasedTIME = min(deceasedTIME, na.rm=T)) %>%
  mutate(codTIME = min(outicuTIME,deceasedTIME)) %>%
  mutate(deceased_indicator = codTIME == deceasedTIME) %>%  # note death is to the day, so lte censor time
  mutate(codTIME_days = (codTIME - inicuTIME)/24/60/60) %>%  # in days
  filter(TIME==codTIME) %>%  
  select(-outicuTIME, -deceasedTIME, -inicuTIME, -codTIME) %>%
  mutate(event="deceased or censored") %>% ungroup() %>% arrange(hosp_id,TIME) %>%
  select(hosp_id, event, deceased_indicator, codTIME_days) %>%
  pivot_wider(names_from=event, values_from=c(codTIME_days, deceased_indicator)) %>%
  (function(.) {names(.) = c("hosp_id", "censor_or_deceased_days", "deceased_indicator"); .})(.)
  
pna_ages = pna_features %>% group_by(hosp_id) %>% 
  mutate(inicuTIME = ifelse(event=="inicu",TIME,NA)) %>%
  mutate(inicuTIME = min(inicuTIME, na.rm = T)) %>%
  filter(event=="birthed") %>% mutate(value=(inicuTIME-TIME)/24/60/60/365.25) %>%
  mutate(value=ifelse(value>150,90,value)) %>% mutate(value=as.character(value)) %>%
  mutate(event="age at icu admission") %>% select(-inicuTIME) %>% ungroup() %>%
  select(hosp_id, event, value) %>%
  pivot_wider(names_from=event, values_from=value)

pna_features = pna_features %>% 
  filter(event!="birthed", event!="outicu") %>%
  # bind_rows(pna_ages) %>%  # replace with age
  group_by(hosp_id) %>% 
  mutate(TIME=(TIME-min(TIME))/24/60/60) %>%  # age in days
  arrange(hosp_id,TIME)  # ordered by pt, time

# Filter on timestamp and merge features and outcomes
pna_dats = data.frame(time_since_first_inicu = c(0, 1, 2)) %>% as_tibble() %>%
  mutate(data = map(time_since_first_inicu, ~ pna_features %>%
                      mutate(inicuTIME = ifelse(event=="inicu",TIME,NA)) %>%
                      mutate(inicuTIME = min(inicuTIME, na.rm = T)) %>%
                      filter(TIME <= inicuTIME + .x) %>% select(-inicuTIME)
  ))

### Exclusion criteria:
# DIC: PT, PTT, fibrinogen, d-dimer
# stroke or ICH
# liver failure
# renal failure
# CHF
mimicdir = "mimic3/"
blacklist = 
  bind_rows(
    fread(paste0(mimicdir,"DIAGNOSES_ICD.csv")) %>% as_tibble() %>%
      inner_join(read_csv(paste0(mimicdir,"D_ICD_DIAGNOSES.csv")) %>% select(ICD9_CODE,LONG_TITLE),
                 by="ICD9_CODE") %>%
      filter(str_detect(str_to_lower(LONG_TITLE), pattern="isseminated intra|cerebral hem|cerebral inf")) %>% 
      filter(!str_detect(str_to_lower(LONG_TITLE), pattern="history")),
    fread(paste0(mimicdir,"DIAGNOSES_ICD.csv")) %>% as_tibble() %>%
      inner_join(read_csv(paste0(mimicdir,"D_ICD_DIAGNOSES.csv")) %>% select(ICD9_CODE,LONG_TITLE),
                 by="ICD9_CODE") %>%
      filter(str_detect(str_to_lower(LONG_TITLE), pattern="urgical")) %>%
      filter(!str_detect(str_to_lower(LONG_TITLE), pattern=" not ")) %>%
      filter(SEQ_NUM < 3) # only remove if surgery in top 3
  ) %>%
  select(SUBJECT_ID) %>% rename(subject_id=SUBJECT_ID) %>% distinct()


blacklist = blacklist %>% bind_rows(
  codx %>% 
    select(liver_disease, renal_failure,congestive_heart_failure, subject_id) %>% 
    mutate(anyofthem=liver_disease+renal_failure+congestive_heart_failure) %>% 
    filter(anyofthem>0) %>%
    select(subject_id)
) %>% distinct()


flfvs = pna_dats %>%
  mutate(flfv = map2(data, time_since_first_inicu, ~ .x %>%
                       select(-TIME) %>%
                       pivot_wider(names_from=event, values_from=value, 
                                   values_fn=list(value=dplyr::last)) %>%
                       mutate(pleural_effusion=ifelse(is.na(pleural_effusion),0,1)) %>%
                       left_join(pna_ages, by="hosp_id") %>% 
                       filter(as.numeric(`age at icu admission`)<70) %>%
                       left_join(smoking, by = c("hosp_id"="subject_id")) %>%
                       left_join(codx, by = c("hosp_id"="subject_id")) %>%
                       select(hosp_id, sort(tidyselect::peek_vars())) %>%
                       filter(! hosp_id %in% blacklist$subject_id) %>%
                       left_join(pna_outcomes %>% mutate(vasopressor=vasopressor-.y,
                                                         `mechanical ventilation`=`mechanical ventilation`-.y),  
                                 by="hosp_id") %>%
                       left_join(pna_death %>% 
                                   mutate(censor_or_deceased_days=censor_or_deceased_days-.y),
                                 by="hosp_id") %>%
                       filter(censor_or_deceased_days > 0) %>%
                       mutate(censor_or_vasopressor_days = min(censor_or_deceased_days, vasopressor, na.rm = T),
                              vasopressor_indicator = vasopressor < censor_or_deceased_days,
                              vasopressor_indicator = ifelse(is.na(vasopressor_indicator), 0, 1)) %>%
                       mutate(censor_or_ventilator_days = min(censor_or_deceased_days, `mechanical ventilation`, na.rm=T),
                              ventilator_indicator = `mechanical ventilation` < censor_or_deceased_days,
                              ventilator_indicator = ifelse(is.na(ventilator_indicator), 0, 1)) %>%
                       select(-vasopressor, -`mechanical ventilation`, -inicu) %>%
                       rename(
                         age=`age at icu admission`,
                         bp_diastolic=`diastolic bp`,
                         bp_mean_arterial=`mean arterial pressure`,
                         bp_systolic=`systolic bp`,
                         chf=congestive_heart_failure,
                         direct_bilirubin=dbili,
                         heart_rate=`heart rate`,
                         lymphocytes=`lymphocyte count`,
                         respiratory_rate=`respiratory rate`,
                         total_bilirubin=`total bilirubin`,
                         total_protein=`total protein`,
                         alkaline_phosphatase=`alkaline phosphatase`
                       ) %>%
                       filter(cancer==0)
  ))


flfvs %>% 
  mutate(tmp=map2(time_since_first_inicu, flfv, ~ 
                write_delim(.y, 
                            paste0("mimic/", keyword, 
                                   "_flfv_",.x,"_days_post_inicu.csv"),
                            delim="|"))) %>%
  select(-tmp)
