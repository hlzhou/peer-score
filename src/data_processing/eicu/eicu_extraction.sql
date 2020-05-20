--Given the eICU database, create tables for the viral or unspecified pneumonia cohort and corresponding features.

SET search_path TO eicu_crd;

-------------------------------------- EXTRACT COHORT ----------------------------------

DROP TABLE IF EXISTS pna_nonbacterial_diagnoses;
CREATE TABLE pna_nonbacterial_diagnoses AS
(
 SELECT * FROM diagnosis
 WHERE diagnosisstring IN ('infectious diseases|chest/pulmonary infections|pneumonia|ventilator-associated',
   'surgery|respiratory failure|ARDS|pulmonary etiology|pneumonia',
   'infectious diseases|chest/pulmonary infections|pneumonia|community-acquired|viral',
   'infectious diseases|chest/pulmonary infections|pneumonia',
   'infectious diseases|chest/pulmonary infections|lung abscess|secondary to pneumonia',
   'pulmonary|pulmonary infections|pneumonia|community-acquired|viral|respiratory syncytial',
   'pulmonary|pulmonary infections|pneumonia|community-acquired',
   'surgery|infections|pneumonia|hospital acquired (not ventilator-associated)',
   'infectious diseases|chest/pulmonary infections|empyema|associated with pneumonia',
   'pulmonary|pulmonary infections|pneumonia|hospital acquired (not ventilator-associated)',
   'pulmonary|pulmonary infections|pneumonia|hospital acquired (not ventilator-associated)',
   'infectious diseases|chest/pulmonary infections|pneumonia|opportunistic',
   'surgery|respiratory failure|acute lung injury|pulmonary etiology|pneumonia',
   'pulmonary|respiratory failure|acute lung injury|pulmonary etiology|pneumonia',
   'infectious diseases|chest/pulmonary infections|pneumonia|community-acquired',
   'surgery|infections|pneumonia',
   'pulmonary|pulmonary infections|pneumonia|community-acquired|viral',
   'infectious diseases|chest/pulmonary infections|pneumonia|hospital acquired (not ventilator-associated)',
   'pulmonary|respiratory failure|ARDS|pulmonary etiology|pneumonia',
   'pulmonary|pulmonary infections|pneumonia|hospital acquired (not ventilator-associated)|viral',
   'transplant|s/p bone marrow transplant|idiopathic pneumonia syndrome - bone marrow transplant',
   'pulmonary|pulmonary infections|lung abscess|secondary to pneumonia',
   'infectious diseases|chest/pulmonary infections|pneumonia|community-acquired|viral|respiratory syncytial',
   'pulmonary|pulmonary infections|pneumonia',
   'pulmonary|pulmonary infections|pneumonia|ventilator-associated',
   'pulmonary|pulmonary infections|pneumonia|opportunistic',
   'surgery|infections|pneumonia|community-acquired')
);

DROP TABLE IF EXISTS pna_nonbacterial_cohort0;
CREATE TABLE pna_nonbacterial_cohort0 AS SELECT DISTINCT d.patientunitstayid AS patientunitstayid
FROM pna_nonbacterial_diagnoses AS d
JOIN patient AS p
ON d.patientunitstayid = p.patientunitstayid
WHERE (age = '') OR (age != '> 89' 
   AND CAST(age AS INT) <= 70 
   AND CAST(age AS INT) >= 18);

DROP TABLE IF EXISTS pna_nonbacterial_cohort_exclude;
CREATE TABLE pna_nonbacterial_cohort_exclude AS SELECT DISTINCT d.patientunitstayid AS patientunitstayid
FROM pna_nonbacterial_cohort0 AS c
JOIN diagnosis AS d
ON c.patientunitstayid = d.patientunitstayid
WHERE (lower(diagnosisstring) like '%surgery%')
OR (lower(diagnosisstring) like '%neurologic%stroke%')
OR (lower(diagnosisstring) = 'surgery|vascular surgery|surgery-related ischemia|postop stroke')
OR (lower(diagnosisstring) like '%cranial%hemorrhage%')
OR (lower(diagnosisstring) like '%cancer%')
OR (lower(diagnosisstring) like '%tumor%')
OR (lower(diagnosisstring) like '%lymphoma%')
OR ((lower(diagnosisstring) like '%hepatic%' OR lower(diagnosisstring) like '%hepatitis%')
   AND (diagnosisstring NOT IN ('gastrointestinal|post-GI surgery|s/p hepatic surgery',
     'gastrointestinal|hepatic disease|toxic hepatitis',
     'infectious diseases|GI infections|intra-abdominal abscess|hepatic|bacterial',
     'burns/trauma|trauma - abdomen|hepatic trauma',
     'gastrointestinal|abdominal/ general|intra-abdominal abscess|subhepatic',
     'gastrointestinal|hepatic disease|hepatorenal syndrome',
     'gastrointestinal|hepatic disease|hepatic infarction',
     'cardiovascular|shock / hypotension|sepsis|sepsis with single organ dysfunction-acute hepatic failure',
     'toxicology|drug overdose|acetaminophen overdose|hepatic injury expected',
     'gastrointestinal|hepatic disease|hepatic dysfunction|pregnancy related',
     'gastrointestinal|hepatic disease|hepatic dysfunction',
     'gastrointestinal|trauma|hepatic trauma',
     'toxicology|drug overdose|acetaminophen overdose|hepatic injury unexpected')))
OR lower(diagnosisstring) like '%liver disease%'
OR lower(diagnosisstring) like '%congestive heart failure%'
OR ((lower(diagnosisstring) like '%renal%') 
   AND (lower(diagnosisstring) not like '%adrenal%')
   AND (icd9code like '40%'));

DROP TABLE IF EXISTS pna_nonbacterial_cohort;
CREATE TABLE pna_nonbacterial_cohort AS SELECT DISTINCT patientunitstayid
FROM pna_nonbacterial_cohort0
WHERE patientunitstayid NOT IN (SELECT patientunitstayid FROM pna_nonbacterial_cohort_exclude);

DROP TABLE IF EXISTS cohort2;
CREATE TABLE cohort2 AS SELECT DISTINCT patientunitstayid FROM pna_nonbacterial_cohort;

-------------------------------------- EXTRACT FEATURES FOR COHORT ----------------------------------

--pull out demographics
DROP TABLE IF EXISTS c2_demographics;
CREATE TABLE c2_demographics AS 
(
  SELECT c.patientunitstayid as patientunitstayid, 
    patienthealthsystemstayid, 
    gender, 
    age, 
    CASE
      WHEN ethnicity IN ('Hispanic', 'Asian', 'Caucasian', 'African American') THEN ethnicity ELSE 'Other'
    END AS ethnicity,
    CASE
      WHEN lower(hospitaldischargelocation) like '%nursing home%' THEN 1 ELSE 0
    END AS nursing_home,
    hospitalid
  FROM cohort2 as c
  JOIN patient as p
  ON c.patientunitstayid = p.patientunitstayid
);

--nurseCharting features
DROP TABLE IF EXISTS c2_nurse_charting0;
CREATE TABLE c2_nurse_charting0 AS 
(
  SELECT c.patientunitstayid as patientunitstayid, 
  nursingchartoffset,
  nursingchartentryoffset,
  CASE
    WHEN (nursingchartcelltypevallabel = 'Glasgow coma score') 
    AND (nursingchartcelltypevalname = 'Eyes') 
    AND (nursingchartvalue != '') 
    AND (nursingchartvalue IS NOT NULL) 
    THEN CAST(nursingchartvalue AS INT)
  END AS gcs_eyes,
  CASE
    WHEN (nursingchartcelltypevallabel = 'Glasgow coma score') 
    AND (nursingchartcelltypevalname = 'Motor')
    AND (nursingchartvalue != '') 
    AND (nursingchartvalue IS NOT NULL)
    THEN CAST(nursingchartvalue AS INT)
  END AS gcs_motor,
  CASE
    WHEN (nursingchartcelltypevallabel = 'Glasgow coma score') 
    AND (nursingchartcelltypevalname = 'Verbal')
    AND (nursingchartvalue != '') 
    AND (nursingchartvalue IS NOT NULL) 
    THEN CAST(nursingchartvalue AS INT)
  END AS gcs_verbal,
  CASE
    WHEN (nursingchartcelltypevallabel = 'Glasgow coma score') 
    AND (nursingchartcelltypevalname = 'GCS Total')
    AND (nursingchartvalue != '') 
    AND (nursingchartvalue IS NOT NULL) 
    AND (nursingchartvalue != 'Unable to score due to medication') 
    THEN CAST(nursingchartvalue AS INT)
  END AS gcs_total,
  CASE
    WHEN nursingchartcelltypevallabel = 'Respiratory Rate' THEN nursingchartvalue
  END AS rr,
  CASE
    WHEN (nursingchartcelltypevalname = 'Invasive BP Systolic') AND (CAST(nursingchartvalue AS float) >= 0) THEN nursingchartvalue
    WHEN nursingchartcelltypevalname = 'Non-Invasive BP Systolic' AND (CAST(nursingchartvalue AS float) >= 0) THEN nursingchartvalue
  END AS bp_systolic,
  CASE
    WHEN nursingchartcelltypevalname = 'Invasive BP Diastolic' AND (CAST(nursingchartvalue AS float) >= 0) THEN nursingchartvalue
    WHEN nursingchartcelltypevalname = 'Non-Invasive BP Diastolic' AND (CAST(nursingchartvalue AS float) >= 0) THEN nursingchartvalue
  END AS bp_diastolic,
  CASE
    WHEN nursingchartcelltypevalname = 'Invasive BP Mean' AND (CAST(nursingchartvalue AS float) >= 0) THEN nursingchartvalue
    WHEN nursingchartcelltypevalname = 'Non-Invasive BP Mean' AND (CAST(nursingchartvalue AS float) >= 0) THEN nursingchartvalue
  END AS bp_mean,
  CASE
    WHEN (lower(nursingchartcelltypevalname) = 'temperature (f)' OR lower(nursingchartcelltypevalname) = 'temperature (c)')
    AND (CAST(nursingchartvalue AS FLOAT) < 46) AND (CAST(nursingchartvalue AS FLOAT) > 14) THEN CAST(nursingchartvalue AS FLOAT)
    WHEN (lower(nursingchartcelltypevalname) = 'temperature (f)' OR lower(nursingchartcelltypevalname) = 'temperature (c)')
    AND (CAST(nursingchartvalue as FLOAT) > 57) AND (CAST(nursingchartvalue AS FLOAT) < 115) THEN (CAST(nursingchartvalue AS FLOAT) - 32) / 1.8
  END AS temperature
  FROM cohort2 as c
  JOIN nurseCharting as n
  ON c.patientunitstayid = n.patientunitstayid
);

DROP TABLE IF EXISTS c2_nurse_charting;
CREATE TABLE c2_nurse_charting AS 
(
  SELECT patientunitstayid, 
  nursingchartoffset as t_offset,
  CASE 
    WHEN MAX(gcs_verbal) = 5 THEN 4
    WHEN MAX(gcs_verbal) < 5 AND MAX(gcs_verbal) >= 0 THEN 0
  END AS gcs_orientation,
  MAX(gcs_total) as gcs,
  MAX(gcs_eyes) + MAX(gcs_motor) + MAX(gcs_verbal) as gcs2,
  MAX(rr) as respiratory_rate,
  MAX(bp_systolic) as bp_systolic,
  MAX(bp_diastolic) as bp_diastolic,
  MAX(bp_mean) as bp_mean,
  MAX(temperature) as temperature
  FROM c2_nurse_charting0
  GROUP BY patientunitstayid, nursingchartoffset
);


DROP TABLE IF EXISTS c2_vitals;
CREATE TABLE c2_vitals AS
(
  SELECT c.patientunitstayid as patientunitstayid, 
  observationOffset as t_offset,
  CASE 
    WHEN (temperature < 46) AND (temperature > 14) THEN temperature -- TODO: check that this is ok
    WHEN (temperature > 57) AND (temperature < 115) THEN (temperature - 32) / 1.8
  END AS temperature,
  heartRate as heart_rate,
  saO2,
  respiration as respiratory_rate,
  CASE
    WHEN systemicSystolic >= 0 THEN systemicSystolic
  END AS bp_systolic,
  CASE
    WHEN systemicDiastolic >= 0 THEN systemicDiastolic
  END AS bp_diastolic,
  CASE
    WHEN systemicMean >= 0 THEN systemicMean
  END AS bp_mean
  FROM cohort2 as c
  JOIN vitalPeriodic as v
  ON c.patientunitstayid = v.patientunitstayid
);

DROP TABLE IF EXISTS c2_comorbidities0;
CREATE TABLE c2_comorbidities0 AS
(
  SELECT c.patientunitstayid as patientunitstayid,
  diagnosisoffset,
  CASE
    WHEN lower(diagnosisstring) like '%smoking%' THEN 1
    WHEN lower(diagnosisstring) like '%nicotine%' THEN 1
  END AS smoking,
  CASE
    WHEN (lower(diagnosisstring) like '%pleural effusion%') THEN 1 ELSE 0
  END AS pleural_effusion
  FROM cohort2 as c
  JOIN diagnosis as d
  ON c.patientunitstayid = d.patientunitstayid
);

DROP TABLE IF EXISTS c2_comorbidities;
CREATE TABLE c2_comorbidities AS
(
  SELECT patientunitstayid,
  diagnosisoffset as t_offset,
  MAX(smoking) as smoking,
  MAX(pleural_effusion) as pleural_effusion
  FROM c2_comorbidities0
  GROUP BY patientunitstayid, diagnosisoffset
);

DROP TABLE IF EXISTS c2_labs0;
CREATE TABLE c2_labs0 AS
(
  SELECT c.patientunitstayid as patientunitstayid, 
  labresultoffset, 
  labresultrevisedoffset,
  CASE
    WHEN lower(labname) = 'rbc' THEN labresult
  END AS rbc,
  CASE
    WHEN lower(labname) = 'wbc x 1000' THEN labresult
  END AS wbc,
  CASE
    WHEN lower(labname) = 'platelets x 1000' THEN labresult
  END AS platelets,
  CASE
    WHEN lower(labname) = 'hgb' THEN labresult
  END AS hgb,
  CASE
    WHEN lower(labname) = 'hct' THEN labresult
  END AS hct,
  CASE
    WHEN lower(labname) = 'rdw' THEN labresult
  END AS rdw,
  CASE
    WHEN lower(labname) = 'mcv' THEN labresult
  END AS mcv,
  CASE
    WHEN lower(labname) = 'mch' THEN labresult
  END AS mch,
  CASE
    WHEN lower(labname) = 'mchc' THEN labresult
  END AS mchc,
  CASE
    WHEN lower(labname) = '-polys' THEN labresult
  END AS polys,
  CASE
    WHEN lower(labname) = '-lymphs' THEN labresult
  END AS lymphs,
  CASE
    WHEN lower(labname) = '-monos' THEN labresult
  END AS monos,
  CASE
    WHEN lower(labname) = '-eos' THEN labresult
  END AS eos,
  CASE
    WHEN lower(labname) = '-basos' THEN labresult
  END AS basos,  
  CASE
    WHEN lower(labname) = 'bun' THEN labresult
  END AS bun,
  CASE
    WHEN (lower(labname) = 'temperature') AND (labresult < 46) AND (labresult > 14) THEN labresult
    WHEN (lower(labname) = 'temperature') AND (labresult > 57) AND (labresult < 115) THEN (labresult - 32) / 1.8
  END AS temperature,
  CASE
    WHEN lower(labname) = 'ph' THEN labresult
  END AS pH,
  CASE
    WHEN lower(labname) = 'sodium' THEN labresult
  END AS sodium,
  CASE
    WHEN lower(labname) = 'glucose' THEN labresult
  END AS glucose,
  CASE
    WHEN lower(labname) = 'pao2' THEN labresult
  END AS paO2,
  CASE
    WHEN lower(labname) = 'fio2' THEN labresult
  END AS fiO2,
  CASE
    WHEN lower(labname) = 'ldh' THEN labresult
  END AS ldh,
  CASE
    WHEN lower(labname) = 'crp' THEN labresult
    WHEN lower(labname) = 'crp-hs' THEN labresult
  END AS crp,
  CASE
    WHEN lower(labname) = 'direct bilirubin' THEN labresult
  END AS direct_bilirubin,
  CASE
    WHEN lower(labname) = 'total bilirubin' THEN labresult
  END AS total_bilirubin,
  CASE
    WHEN lower(labname) = 'total protein' THEN labresult
  END AS total_protein,
  CASE
    WHEN lower(labname) = 'albumin' THEN labresult
  END AS albumin,
  CASE
    WHEN lower(labname) = 'ferritin' THEN labresult
  END AS ferritin,
  CASE
    WHEN lower(labname) = 'pt' THEN labresult
  END AS pt,
  CASE
    WHEN lower(labname) = 'ptt' THEN labresult
  END AS ptt,
  CASE
    WHEN lower(labname) = 'fibrinogen' THEN labresult
  END AS fibrinogen,
  CASE
    WHEN lower(labname) = 'ast (sgot)' THEN labresult
  END AS ast,
  CASE
    WHEN lower(labname) = 'alt (sgpt)' THEN labresult
  END AS alt,
  CASE
    WHEN lower(labname) = 'creatinine' THEN labresult
  END AS creatinine,
  CASE
    WHEN lower(labname) = 'troponin - i' THEN labresult
    WHEN lower(labname) = 'troponin - t' THEN labresult
  END AS troponin,
  CASE
    WHEN lower(labname) = 'alkaline phos.' THEN labresult
  END AS alkaline_phosphatase,
  CASE
    WHEN lower(labname) = '-bands' THEN labresult
  END AS bands,
  CASE
    WHEN lower(labname) = 'bicarbonate' THEN labresult
  END AS bicarbonate,
  CASE
    WHEN lower(labname) = 'calcium' THEN labresult
  END AS calcium,
  CASE
    WHEN lower(labname) = 'chloride' THEN labresult
  END AS chloride,
  CASE
    WHEN lower(labname) = 'potassium' THEN labresult
  END AS potassium
  FROM cohort2 as c
  JOIN lab as l
  ON c.patientunitstayid = l.patientunitstayid
);

DROP TABLE IF EXISTS c2_labs;
CREATE TABLE c2_labs AS
(
  SELECT patientunitstayid, 
  labresultoffset as t_offset,
  MAX(rbc) as rbcs,
  MAX(wbc) as wbc,
  MAX(platelets) as platelets,
  MAX(hgb) as hemoglobin,
  MAX(hct) as hct,
  MAX(rdw) as rdw,
  MAX(mcv) as mcv,
  MAX(mch) as mch,
  MAX(mchc) as mchc,
  MAX(polys) as neutrophils,
  MAX(lymphs) as lymphocytes,
  MAX(monos) as monocytes,
  MAX(eos) as eosinophils,
  MAX(basos) as basophils,
  MAX(bun) as bun,
  MAX(temperature) as temperature,
  MAX(pH) as ph,
  MAX(sodium) as sodium,
  MAX(glucose) as glucose,
  MAX(paO2) as paO2,
  MAX(fiO2) as fiO2,
  MAX(ldh) as ldh,
  MAX(crp) as crp,
  MAX(direct_bilirubin) as direct_bilirubin,
  MAX(total_bilirubin) as total_bilirubin,
  MAX(total_protein) as total_protein,
  MAX(albumin) as albumin,
  MAX(ferritin) as ferritin,
  MAX(pt) as pt,
  MAX(ptt) as ptt,
  MAX(fibrinogen) as fibrinogen,
  MAX(ast) as ast,
  MAX(alt) as alt,
  MAX(creatinine) as creatinine,
  MAX(troponin) as troponin,
  MAX(alkaline_phosphatase) as alkaline_phosphatase,
  MAX(bands) as bands,
  MAX(bicarbonate) as bicarbonate,
  MAX(calcium) as calcium,
  MAX(chloride) as chloride,
  MAX(potassium) as potassium
  FROM c2_labs0
  GROUP BY patientunitstayid, labresultoffset --TODO: assuming we want labresultoffset
);

DROP TABLE IF EXISTS c2_amt0;
CREATE TABLE c2_amt0 AS
(
  SELECT c.patientunitstayid as patientunitstayid, 
  nurseassessoffset, 
  nurseassessentryoffset,
  CASE
    WHEN cellattributevalue = 'to person' THEN 1
    WHEN cellattributevalue = 'to place' THEN 1
    WHEN cellattributevalue = 'to situation' THEN 1
    WHEN cellattributevalue = 'to time' THEN 1
    WHEN cellattributevalue = 'unable to assess' THEN 0
  END AS orientation
  FROM cohort2 as c
  JOIN nurseAssessment as n
  ON c.patientunitstayid = n.patientunitstayid
  WHERE cellattribute = 'Orientation'
);

DROP TABLE IF EXISTS c2_amt;
CREATE TABLE c2_amt AS
(
  SELECT patientunitstayid, 
  nurseassessoffset as t_offset,
  SUM(orientation) as orientation 
  FROM c2_amt0
  GROUP BY patientunitstayid, nurseassessoffset
);

DROP TABLE IF EXISTS c2_ddimer0;
CREATE TABLE c2_ddimer0 AS
(
  SELECT c.patientunitstayid as patientunitstayid, 
  labotheroffset, 
  CASE
    WHEN lower(labothername) like '%dimer%' THEN labotherresult
  END AS ddimer
  FROM cohort2 as c
  JOIN customLab as l
  ON c.patientunitstayid = l.patientunitstayid
);

DROP TABLE IF EXISTS c2_ddimer;
CREATE TABLE c2_ddimer AS
(
  SELECT patientunitstayid, 
  labotheroffset as t_offset,
  MAX(ddimer) as d_dimer
  FROM c2_ddimer0
  GROUP BY patientunitstayid, labotheroffset
);

DROP TABLE IF EXISTS c2_xray0;
CREATE TABLE c2_xray0 AS
(
  SELECT c.patientunitstayid as patientunitstayid,
  treatmentoffset,
  CASE
    WHEN lower(treatmentstring) like '%chest x-ray%' THEN 1 ELSE 0
  END AS chest_xray
  FROM cohort2 as c
  JOIN treatment as t
  ON c.patientunitstayid = t.patientunitstayid
);

DROP TABLE IF EXISTS c2_xray;
CREATE TABLE c2_xray AS
(
  SELECT patientunitstayid,
  treatmentoffset as t_offset,
  MAX(chest_xray) AS chest_xray
  FROM c2_xray0
  GROUP BY patientunitstayid, treatmentoffset
);

