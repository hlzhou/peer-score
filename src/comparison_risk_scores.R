library(tidyverse)
library(data.table)

curb65 = function(dat, impute=T) {
  if (impute) {
    dat = dat %>% mutate_if(is.numeric, (function(.) {.[is.na(.)]=median(.,na.rm=T); .[is.na(.)]=0; .}))  # imputation (median here, 0 if binary)
    dat = dat %>% mutate_if(is.integer, (function(.) {.[is.na(.)]=median(.,na.rm=T); .[is.na(.)]=0; .}))
    dat = dat %>% mutate_if(is.logical, (function(.) {.[is.na(.)]=0; .}))
  }
  
  dat %>% transmute(curb65=
                      (orientation < 3.5) + 
                      (bun > 19) + 
                      (respiratory_rate >= 30) + (bp_systolic<=90 | bp_diastolic<=60) + 
                      (age >= 65)
                    )
}

psiport = function(dat, asclass=F, impute=T) {
  if (impute) {
    dat = dat %>% mutate_if(is.numeric, (function(.) {.[is.na(.)]=median(.,na.rm=T); .[is.na(.)]=0; .}))  # imputation (median here, 0 if binary)
    dat = dat %>% mutate_if(is.integer, (function(.) {.[is.na(.)]=median(.,na.rm=T); .[is.na(.)]=0; .}))
    dat = dat %>% mutate_if(is.logical, (function(.) {.[is.na(.)]=0; .}))
  }
  
  #cancer*30 + chf*10 + ("stroke"=="excluded")*10 + renal_failure*10 +
  result = dat %>% transmute(psiport= 
                      age + ("nursing_home"=="false")*10 +
                      (orientation < 3.5)*20 + 
                      (respiratory_rate >=30)*20 + (bp_systolic<90)*20 +
                      (temperature < 35 | temperature >=40)*15 + (heart_rate>=125)*10 +
                      (ph<7.35)*30 + (bun > 10.7)*20 + (sodium<130)*20 + (glucose>=250)*10 + 
                      (hct<30)*10 + (pao2 < 60 | sao2 < 90)*10 + pleural_effusion*30
  )
  if(asclass) {
    return(result %>% mutate(psiport=cut(psiport, breaks=c(0,50,70,90,130,1000))))
  } else {
    return(result)
  }
}

smartcop = function(dat, asclass=F, impute=T) {
  if (impute) {
    dat = dat %>% mutate_if(is.numeric, (function(.) {.[is.na(.)]=median(.,na.rm=T); .[is.na(.)]=0; .}))  # imputation (median here, 0 if binary)
    dat = dat %>% mutate_if(is.integer, (function(.) {.[is.na(.)]=median(.,na.rm=T); .[is.na(.)]=0; .}))
    dat = dat %>% mutate_if(is.logical, (function(.) {.[is.na(.)]=0; .}))
  }
  
  #("multilobar cxr involvement"=="multilobar cxr involvement")*1 +
  
  result = dat %>% transmute(smartcop = 
                               (bp_systolic < 90)*2 +
                               (albumin < 3.5)*1 +
                               ((respiratory_rate >= 25 & age<=50) | (respiratory_rate >= 30 & age>50))*1 +
                               (heart_rate > 100)*1 +
                               (orientation < 3.5)*1 +
                               (((pao2 < 60 | sao2 <= 90) & age>50)|((pao2<70|sao2<=93)&age<=50))*2 +
                               (ph < 7.35)*2
  )
  if(asclass) {
    return(result %>% mutate(smartcop=cut(smartcop, breaks=c(0,2,4,6,100))))
  } else {
    return(result)
  }
}

maastricht = function(dat, impute=T) {
  if (impute) {
    dat = dat %>% mutate_if(is.numeric, (function(.) {.[is.na(.)]=median(.,na.rm=T); .[is.na(.)]=0; .}))  # imputation (median here, 0 if binary)
    dat = dat %>% mutate_if(is.integer, (function(.) {.[is.na(.)]=median(.,na.rm=T); .[is.na(.)]=0; .}))
    dat = dat %>% mutate_if(is.logical, (function(.) {.[is.na(.)]=0; .}))
  }
  
  # ((pmin(pmax(crp,0),200)*47/200)) +
  result = dat %>% mutate_if(is.character, as.numeric) %>%
    transmute(maastricht =
                ((30 <= age) & (age < 40))*16 + ((40 <= age) & (age < 50))*31 + 
                ((50 <= age) & (age < 60))*47 + ((60 <= age) & (age < 70))*62 +
                ((age >= 70)) * 78 +
                ((direct_bilirubin >=5) & (direct_bilirubin<10))*11.5 +
                ((direct_bilirubin >=10) & (direct_bilirubin<15))*23 +
                ((direct_bilirubin >=15) & (direct_bilirubin<20))*34 +
                ((direct_bilirubin >=20))*45 +
                ((pmin(pmax(rdw,10.5),16)-10.5)*94/5.5) +
                ((pmin(pmax(bun,0),20)*30/20)) +
                ((pmin(pmax(ldh,50),650)-50)*100/600) +
                ((54-pmin(pmax(albumin,2.4),5.4)*10)*83/30)  # convesion from their units
  )
  return(result)
}
