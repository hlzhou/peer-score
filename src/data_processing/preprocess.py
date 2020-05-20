"""Pre-process the csv output from tables.py in order to output data ready for modeling.

Functionality includes:
* imputing using MissForest
* converting categorical and binary variables into one-hot features 
  (dropping the last category to avoid collinearity)
* scaling numerical values
"""

import argparse
import os
import pickle
import pprint
import warnings

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

from lifelines.utils import sklearn_adapter, concordance_index
from lifelines import CoxPHFitter, WeibullAFTFitter
from missingpy import MissForest

from sklearn.model_selection import GridSearchCV
from sklearn.preprocessing import StandardScaler
from sklearn.utils import shuffle


DATA_DIR = '../data/final_splits/'
SAVE_IMPUTED_DIR = '../data/missforest/'

CATEGORICAL_VARS = [
  'African American', 'Asian', 'Caucasian', 'Hispanic', 'Other', 
  'Female', 'Male'
]
NUMERICAL_VARS = [
  'rbcs', 'wbc', 'platelets', 'hemoglobin', 'hct', 'rdw', 'mcv', 'mch',
  'mchc', 'neutrophils', 'lymphocytes', 'monocytes', 'eosinophils',
  'basophils', 'bun', 'temperature', 'ph', 'sodium', 'glucose', 'pao2',
  'ldh', 'direct_bilirubin', 'total_bilirubin', 'total_protein',
  'albumin', 'pt', 'ptt', 'ast', 'alt', 'creatinine', 'troponin',
  'alkaline_phosphatase', 'bands', 'bicarbonate', 'calcium', 'chloride',
  'potassium', 'age', 'heart_rate', 'sao2', 'gcs', 'respiratory_rate',
  'bp_systolic', 'bp_diastolic', 'bp_mean_arterial', 'orientation'
]
EXCLUDE_VARS = [
  'Unnamed: 0', 'fibrinogen', 'ferritin', 'crp', 'smoking', 'd.dimer', 
  'nursing_home', 'chest_xray', 'fio2'
]

pd.set_option('display.max_columns', 100)


def get_data(seed=42, prefix='viral', day=2, impute=-1, outcome='deceased', save=True, force=False, return_scaler=False):
  mf_fname = '{}_day{}_{}_seed{}.pkl'.format(prefix, day, outcome, seed)
  mf_fpath = os.path.join(SAVE_IMPUTED_DIR, mf_fname)

  print(mf_fname)

  if impute == -1:  # missForest
    if os.path.exists(mf_fpath) and (not force) and (not return_scaler):
      with open(mf_fpath, 'rb') as fin:
        print("file:", mf_fpath)
        d = pickle.load(fin)
        print('loaded from to {}'.format(mf_fpath))
        return d


  e_tr, e_te, mimic_df, e_viral_df, m_viral_df = load_csv(prefix, day, impute, return_viral=True)
  e_tr_idxs = list(range(len(e_tr)))
  e_te_idxs = list(range(len(e_te)))
  mimic_idxs = list(range(len(mimic_df)))

  e_viral_idxs = list(range(len(e_viral_df)))
  m_viral_idxs = list(range(len(m_viral_df)))
  
  X_train, y_train, scaler, imputer, e_tr_idxs= prepare_data(e_tr, e_tr_idxs, outcome, seed=seed)
  
  if return_scaler:
    return scaler

  X_test_eicu, y_test_eicu, _, _, e_te_idxs = prepare_data(e_te, e_te_idxs, outcome, keep_cols=X_train.columns, scaler=scaler, imputer=imputer)
  X_test_mimic, y_test_mimic, _, _, mimic_idxs = prepare_data(mimic_df, mimic_idxs, outcome, keep_cols=X_train.columns, scaler=scaler, imputer=imputer)

  X_eicu_viral, y_eicu_viral, _, _, eicu_viral_idxs = prepare_data(e_viral_df, e_viral_idxs, outcome, keep_cols=X_train.columns, scaler=scaler, imputer=imputer)
  X_mimic_viral, y_mimic_viral, _, _, mimic_viral_idxs = prepare_data(m_viral_df, m_viral_idxs, outcome, keep_cols=X_train.columns, scaler=scaler, imputer=imputer)

  d = {}
  d['X_train'] = X_train
  d['y_train'] = y_train
  d['X_test_eicu'] = X_test_eicu
  d['y_test_eicu'] = y_test_eicu
  d['X_test_mimic'] = X_test_mimic
  d['y_test_mimic'] = y_test_mimic
  d['X_eicu_viral'] = X_eicu_viral
  d['y_eicu_viral'] = y_eicu_viral
  d['X_mimic_viral'] = X_mimic_viral
  d['y_mimic_viral'] = y_mimic_viral
  d['idxs_train'] = e_tr_idxs
  d['idxs_test_eicu'] = e_te_idxs
  d['idxs_test_mimic'] = mimic_idxs
  d['idxs_eicu_viral'] = eicu_viral_idxs
  d['idxs_mimic_viral'] = mimic_viral_idxs

  if (impute == -1) and save:
    if not os.path.exists(SAVE_IMPUTED_DIR):
      os.makedirs(SAVE_IMPUTED_DIR)
    with open(mf_fpath, 'wb') as fout:
      pickle.dump(d, fout)
      print('saved to {}'.format(mf_fpath))
  return d


def prepare_data(data, data_idxs, outcome, convert_categorical=True, 
                 keep_cols=None, scaler=None, imputer=None, verbose=False, seed=None):
  X = data.iloc[:, 0:-6]  # TODO: get rid of magic number

  # remove excluded variables
  for v in EXCLUDE_VARS:
    if v in X.columns:
      print('dropped {} column...'.format(v))
      X = X.drop([v], axis=1)

  # convert categorical variables
  if convert_categorical:
    X = pd.concat([X, pd.get_dummies(X['ethnicity'])], axis=1)
    X = pd.concat([X, pd.get_dummies(X['gender'])], axis=1)
    X = X.drop(['ethnicity', 'gender'], axis=1)
    X = X.drop(['Other', 'Female'], axis=1)  # to avoid colinearity
  
  ## Extract outcomes
  y = None
  names = {
    'time': 'censor_or_{}_days'.format(outcome), 
    'event': '{}_indicator'.format(outcome),
  }
  y = data[[names['time'], names['event']]]

  ## Filter for appropriate samples
  prev_ct = len(y)
  pos_events = y.iloc[:, 0] > 0  # event times > 0
  X = X.loc[pos_events]
  y = y.loc[pos_events]
  data_idxs = list([i for (i, inc) in zip(data_idxs, pos_events.tolist()) if inc])
  print('filtered out {} events with times < 0'.format(prev_ct - len(y)))
  
  if keep_cols is None:
    X = X.loc[:, (X != 0).any(axis=0)]  # drop columns w/ all zero
  else:
    for vr in keep_cols:
      if not set([vr]).issubset(X.columns):
        X[vr] = 0.0  # impute with zero by default
    X = X[keep_cols]

  # check for nulls and impute
  x_null = np.sum(pd.isnull(X))
  y_null = np.sum(pd.isnull(y))
  if (x_null.sum() > 0) or (y_null.sum() > 0):
    print('Will impute...')
    print('NULL (X, y):', x_null, y_null)
  if imputer is None:
    print('Fitting MissForest...')
    imputer = MissForest(random_state=seed)
    X_data = imputer.fit_transform(X)
    X = pd.DataFrame(data=X_data, columns=X.columns)
    print('Fitted.')
  else:
    X_data = imputer.transform(X)
    X = pd.DataFrame(data=X_data, columns=X.columns)

  # scale numerical values
  if scaler is None:
    scaler = StandardScaler()
    X[NUMERICAL_VARS] = scaler.fit_transform(X[NUMERICAL_VARS])
  else:
    X[NUMERICAL_VARS] = scaler.transform(X[NUMERICAL_VARS])

  if verbose:
    print('X.shape: {}, y.shape: {}'.format(X.shape, y.shape))
    print('Columns: {}'.format(X.columns))
    print('---------------- X ----------------\n{}'.format(X.describe()))
    print('---------------- y ----------------\n{}'.format(y.describe()))

  return X, y, scaler, imputer, data_idxs


def load_csv(prefix, day, impute, return_viral=False):
  assert(impute == -1)
  assert(day == 2)
  assert(prefix == 'any')

  eicu_tr_df = pd.read_csv(os.path.join(DATA_DIR, 'eicu_any2_train.csv'))
  eicu_te_df = pd.read_csv(os.path.join(DATA_DIR, 'eicu_any2_test.csv'))
  mimic_df = pd.read_csv(os.path.join(DATA_DIR, 'mimic_any2_test.csv'))
  mimic_df = pd.read_csv(os.path.join(DATA_DIR, 'mimic_any2_test.csv'))
  eicu_viral_df = pd.read_csv(os.path.join(DATA_DIR, 'eicu_viral2_test.csv'))
  mimic_viral_df = pd.read_csv(os.path.join(DATA_DIR, 'mimic_viral2_test.csv'))

  if return_viral:
    return eicu_tr_df, eicu_te_df, mimic_df, eicu_viral_df, mimic_viral_df
  else:
    return eicu_tr_df, eicu_te_df, mimic_df


if __name__ == '__main__':
  outcome = 'deceased'
  prefix = 'any'
  day = 2
  impute = -1  # use MissForest
  seed = 42

  #load_csv(prefix, day, impute)

  d = get_data(seed=seed, prefix=prefix, day=day, impute=impute, outcome=outcome, save=False, force=True)
  #d = get_data(seed=seed, prefix=prefix, day=day, impute=impute, outcome='vasopressor', save=True, force=True)
  #d = get_data(seed=seed, prefix=prefix, day=day, impute=impute, outcome='ventilator', save=True, force=True)

