#### Extract data from the MIMIC III v1.4 database (as CSV files)
#### Steps:
#### (1) specify input file directories containing raw MIMIC data
#### (2) specify primary and secondary subgroups (ds %>% filter(str_detect(...)))
#### (3) specify nameExtension, prefix and filename(s) (of the directory to extract to)
#### NB: careful that in memory consumption can be large (especially chartevents)

library(tidyverse)

mimicdir = "../data/raw_mimic3/"
  
### Inclusion: all admissions
adm = read_csv(paste0(mimicdir,"ADMISSIONS.csv")) %>% tbl_df()

### Load all descriptive tables
dlist = list()
dfiles = list.files(mimicdir) %>% tbl_df() %>% filter(startsWith(value,"D_")) %>% t() %>% c()
for(i in 1:length(dfiles)) {
  dlist[[i]] = list(name=dfiles[i], data=read_csv(paste0(mimicdir,dfiles[i])) %>% tbl_df())
}

### Load remaining csv files 1 by 1 and collect timestamps
pfiles = list.files(mimicdir) %>% tbl_df() %>% filter(!startsWith(value,"D_") & endsWith(value,".csv")) %>% t() %>% c()

### Load diagnoses files and attach descriptions
dat = read_csv(paste0(mimicdir,"DIAGNOSES_ICD.csv")) %>% tbl_df()
ddat = read_csv(paste0(mimicdir,"D_ICD_DIAGNOSES.csv")) %>% tbl_df()
ds = dat %>% inner_join(ddat %>% select(ICD9_CODE,LONG_TITLE), by="ICD9_CODE")

nameExtension = "anypna"
prefix = paste0("extractions/",nameExtension,"/")  # prefix for extraction outputs

### Patients with primary admission 
# Find the patients with pneumonia
subjects = ds %>% filter(str_detect(pattern = "neumonia", str_to_lower(LONG_TITLE))) %>%
  filter(str_detect(LONG_TITLE, pattern="Pneumonia, organism unspecified") |  # V1
           str_detect(LONG_TITLE, pattern="Influenza with pneumonia") |
           str_detect(LONG_TITLE, pattern="Bronchopneumonia, organism unspecified") |
           str_detect(LONG_TITLE, pattern="Viral pneumonia, unspecified") |
           str_detect(LONG_TITLE, pattern="Pneumonia due to respiratory syncytial virus") |
           str_detect(LONG_TITLE, pattern="Pneumonia due to parainfluenza virus") |
           str_detect(LONG_TITLE, pattern="Influenza due to identified avian influenza virus with pneumonia") |
           str_detect(LONG_TITLE, pattern="Pneumonia due to other specified organism") |
           str_detect(LONG_TITLE, pattern="Pneumonia due to other virus not elsewhere classified")) %>%
  select(SUBJECT_ID, HADM_ID) %>%
  distinct()

event_filter = function(data, subset, numberConditions = 2) {
  if(numberConditions == 1)
    return(data %>% filter(SUBJECT_ID %in% (subset$SUBJECT_ID)))
  return(data %>% filter(SUBJECT_ID %in% (subset$SUBJECT_ID) & HADM_ID %in% subset$HADM_ID))
}

if(!file.exists(prefix)) dir.create(prefix, recursive = T)


# histogram of ICU visits
pdf(paste0(prefix,"NVisitHistogram.pdf"), width=5, height=3)
par(mar=c(4,2,2,1))
adm %>% event_filter(subjects) %>%
  group_by(SUBJECT_ID) %>% summarise(count=n()) %>% select(count) %>% t() %>% c() %>%
  hist(breaks=40, main="Distribution of number of ICU visits")
dev.off()

write.table(
  adm %>% event_filter(subjects) %>%
    select(ADMISSION_LOCATION) %>% group_by(ADMISSION_LOCATION) %>%
    summarise(count=n()),
  file=paste0(prefix,"AdmissionLocation.csv"), row.names = F, quote = F, sep=",")


# Empty tables
tl = data.frame(pt=vector("numeric"), t=vector("numeric"), event=vector("character"), value=vector("character")) %>% tbl_df() %>%
  mutate(value = as.character(value))
constants = data.frame(pt=vector("numeric")) %>% tbl_df()

rn = function(tuple, convertTimeToLong=T, formatting="%Y-%m-%d %H:%M:%S") {
  names(tuple) = c("pt","t","event", "value")[1:length(tuple)]
  if(convertTimeToLong)
    return(tuple %>% mutate(t=as.POSIXct(strptime(t, format=formatting))%>%unclass()))
  tuple
}
rn2 = function(double, newcol="feature") {
  names(double) = c("pt",newcol)
  double
}
tLongToDT = function(t, formatting = "%Y-%m-%d %H:%M:%S") {
  as.POSIXct(t, origin="1960-01-01 00:00:00")
}


# Pull triples as you go (since you will {load, extract, and remove} the files sequentially)
# Pull descriptive tables as you go
adm_subjects = adm %>% event_filter(subjects)
admsubjects = admsubjects %>%
  mutate(ADMISSION_LOCATION=paste0("ADMISSION_LOCATION:",ADMISSION_LOCATION)) %>%
  mutate(ADMISSION_TYPE=paste0("ADMISSION_TYPE:",ADMISSION_TYPE)) %>%
  mutate(INSURANCE=paste0("INSURANCE:",INSURANCE)) %>%
  mutate(DISCHARGE_LOCATION=paste0("DISCHARGE_LOCATION:",DISCHARGE_LOCATION)) %>%
  mutate(MARITAL_STATUS=paste0("MARITAL_STATUS:",MARITAL_STATUS)) %>%
  mutate(DIAGNOSIS=paste0("DISCHARGE_DIAGNOSIS:",DIAGNOSIS))
tl = tl %>%
  bind_rows(admsubjects %>% select(SUBJECT_ID,ADMITTIME, ADMISSION_LOCATION) %>% rn()) %>%
  bind_rows(admsubjects %>% select(SUBJECT_ID,ADMITTIME, ADMISSION_TYPE) %>% rn()) %>%
  bind_rows(admsubjects %>% select(SUBJECT_ID,ADMITTIME, INSURANCE) %>% rn() ) %>%
  bind_rows(admsubjects %>% select(SUBJECT_ID,DISCHTIME, DISCHARGE_LOCATION) %>% rn()) %>%
  bind_rows(admsubjects %>% select(SUBJECT_ID,ADMITTIME, MARITAL_STATUS) %>% rn()) %>%
  bind_rows(admsubjects %>% select(SUBJECT_ID,DISCHTIME, DIAGNOSIS) %>% rn()) %>%
  bind_rows(admsubjects %>% select(SUBJECT_ID,DISCHTIME) %>% mutate(DISCHARGE="DISCHARGED") %>% rn()) %>%
  arrange(pt)
constants = constants %>%
  full_join(admsubjects %>% select(SUBJECT_ID,ETHNICITY) %>% mutate(ETHNICITY = paste0("ETHNICITY:",ETHNICITY)) %>% 
              rn2("ETHNICITY"), by="pt") %>% distinct()

write.table(constants %>%
              select(ETHNICITY) %>% 
              group_by(ETHNICITY) %>% summarise(count=n()) %>% arrange(desc(count)),
            file=paste0(prefix,"Ethnicities.csv"),
            sep=",", quote=F, row.names=F)

# attach gender and age
pts = read_csv(paste0(mimicdir,"PATIENTS.csv")) %>% tbl_df()
ptssubjects = pts %>% event_filter(subjects, 1)
ptssubjects = ptssubjects %>% mutate(GENDER=paste0("GENDER:",GENDER))
constants = constants %>%
  full_join(ptssubjects %>% select(SUBJECT_ID, GENDER) %>% rn2("GENDER"))
tl = tl %>%
  bind_rows(ptssubjects %>% select(SUBJECT_ID, DOB) %>% mutate(BIRTHEVENT="BIRTHED") %>%
              rn(formatting="%Y-%m-%d")) %>% arrange(pt)
tl = tl %>%
  bind_rows(ptssubjects %>% select(SUBJECT_ID, DOB) %>% inner_join(constants, by=c("SUBJECT_ID" = "pt")) %>% select(-GENDER) %>% rn(formatting="%Y-%m-%d"),
            ptssubjects %>% select(SUBJECT_ID, DOB) %>% inner_join(constants, by=c("SUBJECT_ID" = "pt")) %>% select(-ETHNICITY) %>% rn(formatting="%Y-%m-%d"))
tl = tl %>%
  bind_rows(ptssubjects %>% select(SUBJECT_ID, DOD) %>% mutate(DEATHEVENT="DECEASED") %>% filter(!is.na(DOD)) %>%
              rn(formatting="%Y-%m-%d")) %>% arrange(pt)
write.table(ptssubjects %>% select(GENDER) %>% group_by(GENDER) %>% summarise(count=n()),
            file=paste0(prefix,"Gender.csv"), sep=",", quote=F, row.names=F)
rm(pts,ptssubjects); gc()


# detemine who is in carevue (2001-2008) and who is in metavision (2008-2012+)
icustays = read_csv(paste0(mimicdir,"ICUSTAYS.csv")) %>% tbl_df()
icusubjects = icustays %>% event_filter(subjects) %>% 
  select(SUBJECT_ID,HADM_ID, INTIME, DBSOURCE)
# not currently keeping sensitivity profiles of positive cultures but one could
tl = tl %>% bind_rows(
  icusubjects %>% select(-HADM_ID) %>% rn()
)


# codiagnoses
dssubjects = ds %>% event_filter(subjects) %>% mutate(LONG_TITLE=paste0("CoDx:",LONG_TITLE))
dssubjects200 = dssubjects %>% select(LONG_TITLE) %>% group_by(LONG_TITLE) %>% summarise(count=n()) %>%
  arrange(desc(count)) # %>% slice(1:200)
write.table(dssubjects200,
            file=paste0(prefix,"DiagnosesTop200.tsv"), sep="|", quote=F, row.names=F)
interim = (dssubjects200 %>% select(LONG_TITLE) %>% t())
tl = tl %>% bind_rows(
  dssubjects %>% 
    # filter(LONG_TITLE %in% interim) %>%
    left_join(admsubjects %>% select(SUBJECT_ID, HADM_ID, DISCHTIME), by=c("SUBJECT_ID","HADM_ID")) %>%
    select(SUBJECT_ID, DISCHTIME, LONG_TITLE) %>% rn()
)
tl = tl %>% bind_rows(
  admsubjects %>% filter(HOSPITAL_EXPIRE_FLAG==1) %>% select(SUBJECT_ID, DISCHTIME) %>% mutate("EXPIRED_IN_HOSPITAL") %>% rn()
)
rm(dssubjects, dssubjects200, interim); gc()


# load prescriptions +/- keep 200 most common, concatenate route
pre = read_csv(paste0(mimicdir,"PRESCRIPTIONS.csv")) %>% tbl_df()
presubjects = pre %>% event_filter(subjects)
pre200 = presubjects %>% group_by(DRUG) %>% summarise(count=n()) %>% arrange(desc(count)) %>%
  # slice(1:200) %>%
  select(DRUG) %>% t() %>% c()
presubjects200 = presubjects %>% filter(DRUG %in% pre200)
presubjects200 = presubjects200 %>%
  mutate(DRUG=paste0("PRESCRIBED:",DRUG," via ",ROUTE, ":",DOSE_UNIT_RX))
write.table(presubjects200 %>% group_by(DRUG) %>% summarise(count=n()) %>% arrange(desc(count)),
            file=paste0(prefix,"DrugCounts.csv"), quote=F,sep=",",row.names=F)
tl = tl %>% bind_rows(
  presubjects %>% mutate(DRUG=paste0("PRESCRIBED:",DRUG," via ",ROUTE, ":",DOSE_UNIT_RX)) %>%
    select(SUBJECT_ID, STARTDATE, DRUG, DOSE_VAL_RX) %>% 
    mutate(STARTDATE = STARTDATE + 60*60*24 - 1) %>%
    rn()
  #presubjects200 %>% select(SUBJECT_ID, STARTDATE, DRUG, DOSE_VAL_RX) %>% mutate(STARTDATE = STARTDATE + 60*60*24 - 1) %>% rn(formatting="%Y-%m-%d")
) %>% arrange(pt)
rm(pre,presubjects,pre200,presubjects200); gc()


# load lab tests
lab = read_csv(paste0(mimicdir,"LABEVENTS.csv")) %>% tbl_df()
dlab = read_csv(paste0(mimicdir,"D_LABITEMS.csv")) %>% tbl_df()
labsubjects = lab %>% event_filter(subjects, numberConditions = 1) # outpatient labs do not have an HADM_ID (second condition)
labsubjects = labsubjects %>% left_join(dlab %>% select(LABEL,ITEMID, FLUID, CATEGORY), by="ITEMID") %>%
  mutate(LONGLABEL=paste0("LAB:",FLUID,":",CATEGORY,":",LABEL))
labsubjects200counts = labsubjects %>% select(LABEL, FLUID, CATEGORY) %>% group_by(LABEL, FLUID, CATEGORY) %>% summarise(count=n()) %>%
  arrange(desc(count)) #%>%
# slice(1:200)
write.table(labsubjects200counts%>%as.data.frame,
            file=paste0(prefix,"LabEventCounts.tsv"), quote=F, sep="|",row.names=F)
interim = (labsubjects200counts %>% select(LABEL) %>% t() %>% c()) 
labsubjects200 = labsubjects %>%
  filter(LABEL %in% labsubjects200counts$LABEL & FLUID %in% labsubjects200counts$FLUID & CATEGORY %in% labsubjects200counts$CATEGORY)
#mutate(LONGLABEL=paste0("LAB:",FLUID,":",CATEGORY,":",LABEL))
tl = tl %>% bind_rows(
  labsubjects %>% select(SUBJECT_ID, CHARTTIME, LONGLABEL, VALUE) %>% rn()
  #labsubjects200 %>% select(SUBJECT_ID, CHARTTIME, LONGLABEL, VALUE) %>% rn()
)
rm(lab,dlab,labsubjects,labsubjects200counts,interim, labsubjects200); gc()


# load chartevents
library(data.table)
ce = fread(paste0(mimicdir,"CHARTEVENTS.csv")) %>% as_tibble()
# ce = ce %>% event_filter(subjects)
dce = read_csv(paste0(mimicdir,"D_ITEMS.csv")) %>% tbl_df()
cesubjects = ce %>% filter(SUBJECT_ID %in% (subjects%>%t()))
cesubjects = cesubjects %>% left_join(dce %>% select(LABEL, ITEMID), by="ITEMID")
cesubjects200counts = cesubjects %>% select(LABEL, VALUEUOM) %>% group_by(LABEL, VALUEUOM) %>% summarise(count=n()) %>%
  arrange(desc(count))
write.table(cesubjects200counts%>%as.data.frame,
            file=paste0(prefix,"chartEventCounts.tsv"), quote=F, sep="|",row.names=F)
interim = (cesubjects200counts %>% select(LABEL) %>% t() %>% c()) 
cesubjects = cesubjects %>% mutate(LONGLABEL=paste0("CHART:",LABEL,":",VALUEUOM))
cesubjects200 = cesubjects %>%
  filter(LABEL %in% cesubjects200counts$LABEL & VALUEUOM %in% cesubjects200counts$VALUEUOM)
tl = tl %>% bind_rows(
  cesubjects %>% select(SUBJECT_ID, CHARTTIME, LONGLABEL, VALUE) %>% rn()
)
rm(ce,dce,cesubjects,cesubjects200counts,interim, cesubjects200); gc()

icus = read_csv(paste0(mimicdir,"ICUSTAYS.csv")) %>% tbl_df()
icussubjects = icus %>% event_filter(subjects)
tl = tl %>% bind_rows(
  icussubjects %>% select(SUBJECT_ID, INTIME, LOS) %>% mutate(LABEL="inICU") %>%
    bind_rows(icussubjects %>% select(SUBJECT_ID, OUTTIME, LOS) %>% rename(INTIME=OUTTIME) %>% mutate(LABEL="outICU") ) %>% 
    select(SUBJECT_ID, INTIME, LABEL, LOS) %>% mutate(LOS = as.character(LOS)) %>% rn()
)
rm(icus, icussubjects)

# load microbiology tests/results
micro = read_csv(paste0(mimicdir,"MICROBIOLOGYEVENTS.csv")) %>% tbl_df()
microsubjects = micro %>% event_filter(subjects)
microsubjects = microsubjects %>% select(SUBJECT_ID, HADM_ID, CHARTDATE, CHARTTIME, SPEC_TYPE_DESC, ORG_NAME) %>%
  mutate(CTIME = ifelse(is.na(CHARTTIME), yes = CHARTDATE + 60*60*24 - 1, no = CHARTTIME)) %>% # use end-of-day timestamp if not available
  mutate(LONGLABEL=paste0("MICROBIOLOGY:",SPEC_TYPE_DESC,":",ORG_NAME)) %>%
  select(SUBJECT_ID, HADM_ID, CTIME, LONGLABEL) %>% distinct() 
# not currently keeping sensitivity profiles of positive cultures but one could
tl = tl %>% bind_rows(
  microsubjects %>% select(-HADM_ID) %>% (function(tuple) {names(tuple) = c("pt","t","event")[1:length(tuple)]; tuple})(.) %>% mutate(value = NA)
)
rm(micro, microsubjects); gc()

# callout data
callout = read_csv(paste0(mimicdir,"CALLOUT.csv")) %>% tbl_df()
calloutsubjects = callout %>% event_filter(subjects) %>% 
  select(SUBJECT_ID,HADM_ID, CURR_CAREUNIT, CALLOUT_SERVICE, CREATETIME, OUTCOMETIME, CALLOUT_OUTCOME) %>% arrange(SUBJECT_ID, CREATETIME)
# not currently keeping sensitivity profiles of positive cultures but one could
tl = tl %>% bind_rows(
  calloutsubjects %>% select(SUBJECT_ID, CREATETIME, CURR_CAREUNIT) %>% mutate(CURR_CAREUNIT = paste0("CALLOUT:DCSCHEDULED:",CURR_CAREUNIT)) %>% rn(),
  calloutsubjects %>% select(SUBJECT_ID, CREATETIME, CALLOUT_SERVICE, CALLOUT_OUTCOME) %>% mutate(CALLOUT_SERVICE = paste0("CALLOUT:DCTO:",CALLOUT_SERVICE)) %>% rn()
)
rm(callout, calloutsubjects); gc()

# CPTevents - not useful

# datetimevents: t/l/d's
datetimeevents = read_csv(paste0(mimicdir,"DATETIMEEVENTS.csv"), guess_max = 5e5) %>% tbl_df()
dce = read_csv(paste0(mimicdir,"D_ITEMS.csv")) %>% tbl_df()
dtsubjects = datetimeevents %>% event_filter(subjects) %>% 
  left_join(dce %>% filter(LINKSTO=="datetimeevents") %>% select(ITEMID, LABEL), by="ITEMID") %>%
  filter(!str_detect(pattern="^INV|Change", LABEL))

# not currently keeping sensitivity profiles of positive cultures but one could
tl = tl %>% bind_rows(
  dtsubjects %>% select(SUBJECT_ID, VALUE, LABEL) %>% rn()
)
rm(datetimeevents, dce, dtsubjects); gc()

# DRG codes 
drgs = read_csv(paste0(mimicdir,"DRGCODES.csv"), guess_max = 5e5) %>% tbl_df()
drgs = drgs %>% #event_filter(subjects) %>% 
  inner_join(admsubjects %>% select(SUBJECT_ID, HADM_ID, DISCHTIME), by=c("HADM_ID", "SUBJECT_ID")) 
tl = tl %>% bind_rows(
  drgs %>% select(SUBJECT_ID, DISCHTIME, DESCRIPTION, DRG_SEVERITY) %>% mutate(DRG_SEVERITY=DRG_SEVERITY %>% as.character()) %>% rn()
)


#OUTPUT events
outevents = read_csv(paste0(mimicdir,"OUTPUTEVENTS.csv"), guess_max = 1e5) %>% tbl_df()
dce = read_csv(paste0(mimicdir,"D_ITEMS.csv")) %>% tbl_df()
outsubjects = outevents %>% event_filter(subjects) %>% 
  left_join(dce %>% select(ITEMID, LABEL), by="ITEMID") %>%
  mutate(LONGLABEL=paste0(LABEL,":", VALUEUOM))
# not currently keeping sensitivity profiles of positive cultures but one could
tl = tl %>% bind_rows(
  outsubjects %>% select(SUBJECT_ID, CHARTTIME, LONGLABEL, VALUE) %>% mutate(VALUE = VALUE %>% as.character()) %>% rn()
) 
rm(outevents, outsubjects); gc()


# Procedure events
procevents = read_csv(paste0(mimicdir,"PROCEDUREEVENTS_MV.csv"), guess_max = 1e5) %>% tbl_df() #unfortunately the demoninator here is determined by presence in MetaVision or CareVue
proc2events = read_csv(paste0(mimicdir,"PROCEDURES_ICD.csv"), guess_max = 1e5) %>% tbl_df()
dce = read_csv(paste0(mimicdir,"D_ITEMS.csv")) %>% tbl_df()
dicd = read_csv(paste0(mimicdir,"D_ICD_PROCEDURES.csv")) %>% tbl_df()
procsubjects = procevents %>% event_filter(subjects) %>% 
  left_join(dce %>% select(ITEMID, LABEL), by="ITEMID") %>%
  mutate(LONGLABEL=paste0("MV:",LABEL))
proc2subjects = proc2events %>% event_filter(subjects) %>% 
  left_join(dicd %>% select(ICD9_CODE, LONG_TITLE), by="ICD9_CODE") %>%
  mutate(LONGLABEL=paste0("PROC_ICD:",LONG_TITLE)) %>%
  inner_join(adm %>% select(HADM_ID, DISCHTIME), by="HADM_ID")
# not currently keeping sensitivity profiles of positive cultures but one could
tl = tl %>% bind_rows(
  procsubjects %>% select(SUBJECT_ID, STARTTIME, LONGLABEL, STATUSDESCRIPTION) %>% mutate(LONGLABEL=paste0(LONGLABEL,":","START")) %>% rn(),
  procsubjects %>% select(SUBJECT_ID, ENDTIME, LONGLABEL, STATUSDESCRIPTION) %>% mutate(LONGLABEL=paste0(LONGLABEL,":","END")) %>% rn()
)
tl = tl %>% bind_rows(
  proc2subjects %>% select(SUBJECT_ID, DISCHTIME, LONGLABEL) %>% rn()
)
rm(procevents, proc2events, procsubjects, proc2subjects); gc()

tl %>% filter(!str_detect(pattern="^CHART", event)) %>% arrange(pt,t) %>% mutate(t=t/60/60) %>% View()

# make events all lower case
tl = tl %>% mutate(event = str_to_lower(event))

tl = tl %>% arrange(pt,t)

# Write to file
outname = "mimic_timeline.csv"
outname2 = "mimic_timeline_v2.csv"
write_csv(tl, paste0(prefix, outname))
write_csv(tl %>% filter(pt %in% (subjects2$SUBJECT_ID %>% unique())),
          paste0(prefix, outname2))
