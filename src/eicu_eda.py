import pandas as pd
name_map = {
    'age': 'Age',
    'gender': 'Gender',
    'cancer': 'Malignancy',                                 # comorbidities
    'liver_disease': 'Liver disease',
    'chf': 'Congestive heart failure',
    'renal_failure': 'Renal failure',
    'pleural_effusion': 'Pleural effusion',
    'orientation': 'Orientation',                                     # physical
    'temperature': 'Temperature (\degree C)',
    'heart_rate': 'Heart rate (beats per minute)',
    'respiratory_rate': 'Respiratory rate (breaths per minute)',
    'bp_systolic': 'Systolic blood pressure (mmHg)',
    'bp_diastolic': 'Diastolic blood pressure (mmHg)',
    'bp_mean_arterial': 'Mean arterial pressure (mmHg)',
    'gcs': 'Glasgow Coma Scale',
    'rbcs': 'Red blood cells (millions/$\mu$L)',                      # is this low?
    'wbc': 'White blood cells (thousands/$\mu$L)',
    'platelets': 'Platelets (thousands/$\mu$L)',
    'hct': 'Hematocrit (%)',                                          # is this low?
    'rdw': 'Red blood cell dist. width (%)',
    'mcv': 'Mean corpuscular volume (fL)',
    'mch': 'Mean corpuscular hemoglobin/ MCH (pg)',
    'mchc': 'MCH concentration (g/dL)',
    'neutrophils': 'Neutrophils (%)',                                 # is this higher than normal?
    'lymphocytes': 'Lymphocytes (%)',                                 # is this lower than normal?
    'monocytes': 'Monocytes (%)',
    'eosinophils': 'Eosinophils (%)',
    'basophils': 'Basophils (%)',
    'bands': 'Band cells (%)',                                        # is this low?
    'sodium': 'Sodium (mmol/L)',
    'potassium': 'Potassium (mmol/L)',
    'chloride': 'Chloride (mmol/L)',
    'bicarbonate': 'Bicarbonate (mmol/L)',
    'bun': 'Blood urea nitrogen (mg/dL)',
    'creatinine': 'Creatinine (mg/dL)',
    'glucose': 'Glucose (mg/dL)',
    'ast': 'Aspartate aminotransferase (units/L)',
    'alt': 'Alanine aminotransferase (units/L)',
    'alkaline_phosphatase': 'Alkaline phosphatase (units/L)',
    'crp': 'C-reactive protein (mg/L)',
    'direct_bilirubin': 'Direct bilirubin (mg/L)',
    'total_bilirubin': 'Total bilirubin (mg/L)',
    'total_protein': 'Total protein (g/dL)',
    'calcium': 'Calcium (mg/dL)',
    'albumin': 'Albumin (g/dL)',
    'troponin': 'Troponin (ng/mL)',
    'pt': 'Prothrombin time (sec)',
    'ptt': 'Partial thromboplastin time (sec)',
    'ph': 'pH',
    'pao2': 'Partial pressure of oxygen (mmHg)',
    'sao2': 'Arterial oxygen saturation (mmHg)',
    'deceased_indicator': 'Deceased',
    'vasopressor_indicator': 'Vasopressors administered',
    'ventilator_indicator': 'Ventilator used'
  }

def get_mean_std_str(df, col, return_range=False, tabs=False):
  dcol = df[col]
  s = col
  if len(col) < 8:
    s += '\t'
  if len(col) < 16:
    s += '\t'
  if len(col) < 24:
    s += '\t'

  if return_range:
    dlower = dcol.quantile(0.25)  # change to iqr
    dupper = dcol.quantile(0.75)
    if col == 'ph':
      s += '\t{0:.2f} ({1:.2f}-{2:.2f})'.format(dcol.median(), dlower, dupper)
    else:
      s += '\t{0:.1f} ({1:.1f}-{2:.1f})'.format(dcol.median(), dlower, dupper)
    # s += '\t{0:.1f} ({1:.1f})'.format(dcol.median(), dupper - dlower)
  else:
    s += '\t{0:.1f} ({1:.1f})'.format(dcol.mean(), dcol.std())

  if not tabs:
    s = s.replace('\t', '').replace(col, '')
  return s

def get_binary_var_str(df, col, missingness=False, tabs=False):
  if col is not None:
    dcol = df[col]
  else:
    dcol = df

  ct = int(dcol.sum())
  prop = ct / float(len(df))
  missing = dcol.isna().sum() / float(len(df))

  s = ''
  if col is not None:
    s += col
    if len(col) < 8:
      s += '\t'
    if len(col) < 16:
      s += '\t'
    if len(col) < 24:
      s += '\t'
  s += '\t{0:d} ({1:.1%})'.format(ct, prop)

  if missingness:
    s += '\t(missingness: {0:.1%})'.format(missing)

  if not tabs:
    s = s.replace('\t', '')
    if col is not None:
      s = s.replace(col, '')
  return s


def make_table1(df, df_name):
  global name_map

  N = len(df)
  indent = '\hspace{5mm}'

  names = ['']
  vals = ['(n = {})'.format(N)]

  def add_pair(key, val):
    names.append(key)
    vals.append(val)

  def add_header(header):
    names.append('\\textbf{' + header + '}')
    vals.append('')

  ## Demographics
  add_header('Demographics')

  # age
  age = df['age']
  r1 = len(df[(df['age'] < 30)])
  r2 = len(df[(df['age'] >= 30) & (df['age'] < 40)])
  r3 = len(df[(df['age'] >= 40) & (df['age'] < 50)])
  r4 = len(df[(df['age'] >= 50) & (df['age'] < 60)])
  r5 = len(df[(df['age'] >= 60)])

  add_pair('Age, years', get_mean_std_str(df, 'age', return_range=True))
  add_pair('Age range, years', '')
  add_pair(indent + '$<$ 30', '{0:d} ({1:.1%})'.format(r1, r1 / float(N)))
  add_pair(indent + '30-39', '{0:d} ({1:.1%})'.format(r2, r2 / float(N)))
  add_pair(indent + '40-49', '{0:d} ({1:.1%})'.format(r3, r3 / float(N)))
  add_pair(indent + '50-59', '{0:d} ({1:.1%})'.format(r4, r4 / float(N)))
  add_pair(indent + '$\\leq$ 60', '{0:d} ({1:.1%})'.format(r5, r5 / float(N)))

  # gender
  gender = df['gender']
  g1 = sum(gender == 'Male') + sum(gender == 'gender:m')
  g2 = sum(gender == 'Female') + sum(gender == 'gender:f')

  add_pair('Gender', '')
  add_pair(indent + 'Male', '{0:d} ({1:.1%})'.format(g1, g1 / float(N)))
  add_pair(indent + 'Female', '{0:d} ({1:.1%})'.format(g2, g2 / float(N)))

  ## Comorbidities
  add_pair('', '')
  add_header('Comorbidities')

  cvars = [
    'pleural_effusion'
  ]
  for col in cvars:
    val = get_binary_var_str(df, col)
    add_pair(name_map[col], val)

  ## Physicals
  add_pair('', '')
  add_header('Physical exam findings')

  # orientation
  orientation = df['orientation']
  o1 = (orientation >= 4).astype(int)
  o2 = (orientation < 4).astype(int)

  add_pair('Orientation', '')
  add_pair(indent + 'oriented', get_binary_var_str(o1, None))
  add_pair(indent + 'confused', get_binary_var_str(o2, None))

  # other physical measurements
  pvars = [
    'temperature', 'heart_rate', 'respiratory_rate',
    'bp_systolic', 'bp_diastolic', 'bp_mean_arterial', 'gcs'
  ]
  for col in pvars:
    val = get_mean_std_str(df, col, return_range=True)
    add_pair(name_map[col], val)

  ## Laboratory findings
  add_pair('', '')
  add_header('Laboratory findings')

  hema_vars = [
    'rbcs', 'wbc', 'platelets', 'hct', 'rdw', 'mcv', 'mch', 'mchc',
    'neutrophils', 'lymphocytes', 'monocytes', 'eosinophils', 'basophils', 'bands',
  ]
  chem_vars = [
    'sodium', 'potassium', 'chloride', 'bicarbonate',
    'bun', 'creatinine', 'glucose',
    'ast', 'alt', 'alkaline_phosphatase', 'crp',
    'direct_bilirubin', 'total_bilirubin', 'total_protein',
    'calcium', 'albumin', 'troponin'
  ]
  coag_vars = ['pt', 'ptt']
  bgas_vars = ['ph', 'pao2', 'sao2']

  add_pair('Hemotology', '')
  for col in hema_vars:
    try:
      add_pair(indent + name_map[col], get_mean_std_str(df, col, return_range=True))
    except Exception as e:
      print(e)
      import pdb;
      pdb.set_trace()

  add_pair('Chemistry', '')
  for col in chem_vars:
    add_pair(indent + name_map[col], get_mean_std_str(df, col, return_range=True))

  add_pair('Coagulation', '')
  for col in coag_vars:
    add_pair(indent + name_map[col], get_mean_std_str(df, col, return_range=True))

  add_pair('Blood gas', '')
  for col in bgas_vars:
    add_pair(indent + name_map[col], get_mean_std_str(df, col, return_range=True))

  ## Outcomes
  add_pair('', '')
  add_header('Outcomes')
  out_vars = [
    'deceased_indicator',
    'vasopressor_indicator',
    'ventilator_indicator'
  ]
  for col in out_vars:
    add_pair(name_map[col], get_binary_var_str(df, col))

  table_df = pd.DataFrame({'Variable': names, df_name: vals})
  return table_df


def print_table1(df, df_name):
  print('==================== TABLE FOR {} ================='.format(df_name))
  N = len(df)
  print('Patients (n = {})\n'.format(N))

  age = df['age']
  print('Age missingness*:\t{0:d} ({1:.1%})'.format(age.isna().sum(), round(age.isna().sum() / float(N), 3)))
  print('Age, years\t\t{0:.1f} ({1:.1f})'.format(age.mean(), age.std()))
  print('Age range, years')
  r = len(df[(df['age'] < 30)])
  print('\t<30\t\t{0:d} ({1:.1%})'.format(r, r / float(N)))
  r = len(df[(df['age'] >= 30) & (df['age'] < 40)])
  print('\t30-39\t\t{0:d} ({1:.1%})'.format(r, r / float(N)))
  r = len(df[(df['age'] >= 40) & (df['age'] < 50)])
  print('\t40-49\t\t{0:d} ({1:.1%})'.format(r, r / float(N)))
  r = len(df[(df['age'] >= 50) & (df['age'] < 60)])
  print('\t50-59\t\t{0:d} ({1:.1%})'.format(r, r / float(N)))
  r = len(df[(df['age'] >= 60)])
  print('\t>= 60\t\t{0:d} ({1:.1%})'.format(r, r / float(N)))

  gender = df['gender']
  print('\nGender missingness*: \t{0:d} ({1:.1%})'.format(gender.isna().sum(), round(gender.isna().sum() / float(N), 3)))
  print('Gender')
  g = sum(gender == 'Male')
  print('\tMale\t\t{0:d} ({1:.1%})'.format(g, g / float(N)))
  g = sum(gender == 'Female')
  print('\tFemale\t\t{0:d} ({1:.1%})'.format(g, g / float(N)))

  print('\nLab values')
  print('(compare w/ washington state)')
  lvars = [  # compare w/ washington state
    'wbc', 'lymphocytes', 'hemoglobin', 'platelets', 'sodium',
    'creatinine', 'total_bilirubin',
    'alkaline_phosphatase', 'ast', 'alt', 'troponin'
  ]
  for col in lvars:
    print(get_mean_std_str(df, col))
  print('\n(remaining lab values)')
  lvars = [  # compare w/ washington state
    'bun', 'temperature',
    'rbcs', 'hct', 'rdw', 'mcv', 'mch', 'mchc',
    'neutrophils', 'monocytes', 'eosinophils', 'basophils',
    'ph', 'glucose', 'pao2', 'fio2', 'crp',
    'direct_bilirubin', 'total_protein', 'albumin',
    'ferritin', 'pt', 'ptt', 'fibrinogen',
    'bands', 'bicarbonate', 'calcium',
    'chloride', 'potassium', 'heart_rate', 'sao2', 'gcs', 'respiratory_rate',
    'bp_systolic', 'bp_diastolic', 'bp_mean_arterial',
  ]
  for col in lvars:
    print(get_mean_std_str(df, col, return_range=True))

  print('\nComorbidities')
  cvars = [
    'smoking', 'cancer', 'liver_disease', 'chf',
    'renal_failure', 'pleural_effusion'
  ]
  for col in cvars:
    print(get_binary_var_str(df, col))

  print('\nOrientation')
  print(get_mean_std_str(df, 'orientation'))

  print('\nOutcomes')
  outvars = [
    'censor_or_deceased_days',
    'censor_or_vasopressor_days',
    'censor_or_ventilator_days',
    'deceased_indicator',
    'vasopressor_indicator',
    'ventilator_indicator'
  ]
  for col in outvars:
    if 'indicator' in col:
      print(get_binary_var_str(df, col))
    else:
      print(get_mean_std_str(df, col))


  import pdb; pdb.set_trace()
  #
  #
  # df[['gender']]
  #
  # labs = ['wbc', ]
  #
  # tab = df[]
  #
  # print('Values are n (%) or mean (SD) unless otherwise specified.')


"""Full list of variables:
'rbcs', 'wbc', 'platelets',
'hemoglobin', 'hct', 'rdw', 'mcv', 'mch', 'mchc', 'neutrophils',
'lymphocytes', 'monocytes', 'eosinophils', 'basophils', 'bun',
'temperature', 'ph', 'sodium', 'glucose', 'pao2', 'fio2', 'ldh', 'crp',
'direct_bilirubin', 'total_bilirubin', 'total_protein', 'albumin',
'ferritin', 'pt', 'ptt', 'fibrinogen', 'ast', 'alt', 'creatinine',
'troponin', 'alkaline_phosphatase', 'bands', 'bicarbonate', 'calcium',
'chloride', 'potassium', 'gender', 'age', 'ethnicity',
'observation_offset', 'heart_rate', 'sao2', 'gcs', 'respiratory_rate',
'bp_systolic', 'bp_diastolic', 'bp_mean_arterial', 'smoking', 'cancer',
'liver_disease', 'chf', 'renal_failure', 'pleural_effusion',
'orientation', 'censor_or_deceased_days', 'deceased_indicator',
'censor_or_vasopressor_days', 'vasopressor_indicator',
'censor_or_ventilator_days', 'ventilator_indicator'
"""

eicu_template = '../data/eicu/eicu_cleaned/eicu_anypna_{}_days_post_inicu.csv'
mimic_template = '../data/mimic/mimic_cleaned/cleaner_mimic_anypna_timeline_flfv_{}_days_post_inicu.csv'

# make anypna table
table_cols = [
  # (eicu_template.format(0), 'eICU Day 0'),
  # (eicu_template.format(1), 'eICU Day 1'),
  (eicu_template.format(2), 'eICU Day 2'),
  # (mimic_template.format(0), 'MIMIC Day 0'),
  # (mimic_template.format(1), 'MIMIC Day 1'),
  (mimic_template.format(2), 'MIMIC Day 2'),
]

tte_names = ['Time to death (days)',
             'Time to administering vasopressors (days)',
             'Time to ventilation (days)']
median_ttes = {
  'eICU Day 0': ['58.7', 'NA', '21.0'],
  'eICU Day 1': ['57.7', 'NA', '14.5'],
  'eICU Day 2': ['56.7', 'NA', 'NA'],
  'MIMIC Day 0': ['NA', '12.7', '1.78'],
  'MIMIC Day 1': ['NA', '24.3', '3.71'],
  'MIMIC Day 2': ['NA', '28.6', '3.87'],
}

# iterate through columns and format rows of latex table
table_df = None
filter_neg_outcomes = True
missingness_df = None
for fpath, name in table_cols:
  if 'mimic' in name.lower():
    df = pd.read_csv(fpath, '|')
    if filter_neg_outcomes:
      df = df[df['censor_or_deceased_days'] > 0]
      df = df[df['age'] >= 18]
  else:
    df = pd.read_csv(fpath)
    if filter_neg_outcomes:
      df = df[df['censor_or_deceased_days'] > 0]
  
  # make missingness df
  vars1 = ['age', 'gender', 'pleural_effusion', 'orientation']
  pvars = [
    'temperature', 'heart_rate', 'respiratory_rate',
    'bp_systolic', 'bp_diastolic', 'bp_mean_arterial', 'gcs'
  ]
  hema_vars = [
    'rbcs', 'wbc', 'platelets', 'hct', 'rdw', 'mcv', 'mch', 'mchc',
    'neutrophils', 'lymphocytes', 'monocytes', 'eosinophils', 'basophils', 'bands',
  ]
  chem_vars = [
    'sodium', 'potassium', 'chloride', 'bicarbonate',
    'bun', 'creatinine', 'glucose',
    'ast', 'alt', 'alkaline_phosphatase', 'crp',
    'direct_bilirubin', 'total_bilirubin', 'total_protein',
    'calcium', 'albumin', 'troponin'
  ]
  coag_vars = ['pt', 'ptt']
  bgas_vars = ['ph', 'pao2', 'sao2']
  out_vars = [
    'deceased_indicator',
    'vasopressor_indicator',
    'ventilator_indicator'
  ]
  all_vars = vars1 + pvars + hema_vars + chem_vars + coag_vars + bgas_vars + out_vars

  if missingness_df is None:
    print(name)
    miss_frac = (df[all_vars].isna().sum() / len(df)).tolist()
    miss_cts = (df[all_vars].isna().sum()).tolist()
    miss_summ = list(['{} ({})'.format(round(f, 3), round(c, 3)) for (f, c) in zip(miss_frac, miss_cts)])
    missingness_df = {'Variable': [name_map[v] for v in all_vars]}
    missingness_df[name + ' (n = {})'.format(len(df))] = miss_summ
  else:
    print(name)
    miss_frac = (df[all_vars].isna().sum() / len(df)).tolist()
    miss_cts = (df[all_vars].isna().sum()).tolist()
    miss_summ = list(['{} ({})'.format(round(f, 3), round(c, 3)) for (f, c) in zip(miss_frac, miss_cts)])
    missingness_df[name + ' (n = {})'.format(len(df))] = miss_summ
    missingness_df = pd.DataFrame(missingness_df)
  
  # make table 1
  table = make_table1(df, name)
  if table_df is None:
    table_df = table
  else:  # iteratively add column to table
    assert(table_df['Variable'].tolist() == table['Variable'].tolist())
    table = table.drop('Variable', axis=1)
    table_df = pd.concat((table_df, table), axis=1)

# add median time to event values
tte_rows = {'Variable': tte_names}
for col in table_df.columns:
  table_df[col] = table_df[col].str.replace('%', '\\%')  # escape %
  if col in median_ttes:
    tte_rows[col] = tte_rows.get(col, []) + median_ttes[col]
tte_df = pd.DataFrame(tte_rows)
table_df = table_df.append(tte_df)

print('======================= table 1 ===============================')
print(table_df.to_latex(index=False, escape=False))
import pdb; pdb.set_trace()
print('======================= missingness ===============================')
print(missingness_df.to_latex(index=False))
