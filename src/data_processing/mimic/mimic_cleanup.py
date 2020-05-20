"""Given the mimic_flfvs produced by R preprocessing code, do some cleanup to output cleaner csv files.

* converts numerical features to numeric types
* drops excluded features
"""

import pandas as pd

out_dir = '../../data/mimic/mimic_cleaned/'
for in_fname in ['../../data/mimic/anypna/cleaner_mimic_anypna_timeline_flfv_{}_days_post_inicu.csv',
                 '../../data/mimic/anypna/cleaner_mimic_viralpna_timeline_flfv_{}_days_post_inicu.csv']:
  for i in range(3):
    fname = in_fname.format(i)
    df = pd.read_csv(fname, delimiter='|')
    df['cancer'] = df['cancer'].astype(int)
    df['deceased_indicator'] = df['deceased_indicator'].astype(int)
    for col in df.columns:
      if col in ['gender', 'ethnicity']:
        continue
      elif col in ['rbcs', 'wbc', 'platelets',
                   'hemoglobin', 'hct', 'rdw', 'mcv', 'mch', 'mchc', 'neutrophils',
                   'lymphocytes', 'monocytes', 'eosinophils', 'basophils', 'bun',
                   'temperature', 'ph', 'sodium', 'glucose', 'pao2', 'fio2', 'ldh', 'crp',
                   'direct_bilirubin', 'total_bilirubin', 'total_protein', 'albumin',
                   'ferritin', 'pt', 'ptt', 'fibrinogen', 'ast', 'alt', 'creatinine',
                   'troponin', 'alkaline_phosphatase', 'bands', 'bicarbonate', 'calcium',
                   'chloride', 'potassium', 'heart_rate', 'sao2', 'gcs', 'respiratory_rate',
                   'bp_systolic', 'bp_diastolic', 'bp_mean_arterial', 'orientation',
                    'censor_or_deceased_days', 'censor_or_vasopressor_days', 'censor_or_ventilator_days',
                   'd-dimer']:
        df[col] = pd.to_numeric(df[col], errors='coerce')  # replace strings with nans
      elif col in ['smoking', 'cancer', 'liver_disease', 'chf', 'renal_failure', 'pleural_effusion',
                   'deceased_indicator', 'vasopressor_indicator', 'ventilator_indicator']:
        df[col] = pd.to_numeric(df[col], errors='coerce')  # replace strings with nans
    df = df.drop('hosp_id', axis=1)
    df = df.drop('cancer', axis=1)
    df = df.drop('liver_disease', axis=1)
    df = df.drop('chf', axis=1)
    df = df.drop('renal_failure', axis=1)
    df['gender'] = df['gender'].replace({'gender:m': 'Male', 'gender:f': 'Female'})
    df.reset_index()
    df.index.name = 'X'
    df.to_csv(out_dir + in_fname.split('/')[-1].format(i), index=True, sep='|')
