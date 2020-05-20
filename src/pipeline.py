import os
import pprint
import pickle

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

from lifelines.utils import concordance_index, k_fold_cross_validation
from lifelines import CoxPHFitter, WeibullAFTFitter
from lifelines import KaplanMeierFitter

from sklearn.model_selection import GridSearchCV, KFold
from sklearn.utils import resample
import random
from preprocess import get_data
import argparse

import rpy2.robjects as ro
from rpy2.robjects.packages import importr
from rpy2.robjects import pandas2ri
from rpy2.robjects import Formula 
from rpy2.robjects.conversion import localconverter

r_glmnet = importr('glmnet')
r_surv = importr('survival')
base = importr('base')
utils = importr('utils')
r_stats = importr('stats')
r_graphics = importr('graphics')
r_matrix = importr('Matrix')


survival_estimator_name = 'glmnet_cox'  # for this file
parser = argparse.ArgumentParser(description='risk score for pn')
parser.add_argument('--outcome', default="deceased", action="store")
parser.add_argument('--cvglmnet', action="store_true")
parser.add_argument('--prefix', default="any", action="store")
parser.add_argument('--day', type=int, default=2, action="store")
parser.add_argument('--impute', type=int, default=-1, action="store")
parser.add_argument('--seed', type=int, default=499, action="store")
parser.add_argument('--alpha', type=float, default=1.0, action="store")
parser.add_argument('--cross_val_n_folds', type=int, default=5, action="store")
parser.add_argument('--output_dir', default="output", action="store")
args = parser.parse_args()

outcome = args.outcome
prefix = args.prefix
day = args.day
impute = args.impute  # use MissForest
seed = args.seed
np.random.seed(seed)
random.seed(seed)

d = get_data(seed=seed, prefix=prefix, day=day, impute=impute, outcome=outcome, save=True)

X_tr = d['X_train']
y_tr = d['y_train']
X_te_eicu = d['X_test_eicu']
y_te_eicu = d['y_test_eicu']
X_te_mimic = d['X_test_mimic']
y_te_mimic = d['y_test_mimic']

def combine_Xy(X, y):
    dataset = X.copy()
    for col in y.columns:
        dataset.loc[:, col] = y[col].tolist()
    return dataset

tr_dataset = combine_Xy(X_tr, y_tr)
te_eicu_dataset = combine_Xy(X_te_eicu, y_te_eicu)
te_mimic_dataset = combine_Xy(X_te_mimic, y_te_mimic)

tr_dataset.describe()

duration_col = y_tr.columns[0]
event_col = y_tr.columns[1]

def get_glmnet_params(l1_ratio, penalizer):
    l2_coeff = 0.5 * penalizer * (1 - l1_ratio)
    l1_coeff = 0.5 * penalizer * l1_ratio
    ratio = l2_coeff / l1_coeff
    alpha = 1.0 / (ratio * 2 + 1)
    lmbda = l1_coeff / alpha
    return alpha, lmbda

def get_lifelines_params(alpha, lmbda):
    l2_coeff = lmbda * (1 - alpha) / 2.0
    l1_coeff = lmbda * alpha
    ratio = l2_coeff / l1_coeff
    l1_ratio = 1.0 / (ratio + 1)
    penalizer = l1_coeff * 2 / l1_ratio
    return l1_ratio, penalizer

def get_r_df(y_tr):
    with localconverter(ro.default_converter + pandas2ri.converter):
        r_y_tr = ro.conversion.py2rpy(y_tr)
    return r_y_tr

use_saved_values = False
override_outputs = True
cv_glmnet = True

grid_path = "grid_out"
if not os.path.exists(grid_path):
    os.makedirs(grid_path)

goal = "l1_search" if not cv_glmnet else "cvglmnet"
tag = '{prefix}_day{day}_{outcome}_seed{seed}_{goal}'.format(prefix=prefix, day=day, outcome=outcome, seed=seed, goal=goal)
fname = '{path}/{tag}_grid_search.pkl'.format(path=grid_path,tag=tag)


l1_ratios = [1.0]  

penalizers = [1.0, 0.75, 0.5, 0.25, 0.20, 0.15,0.1, 0.055, 0.05, 0.045, 0.04, 0.035, 0.03, 0.025, 0.02, 0.01, 0.001]

# Doing cross validatin for penalizer selection
if os.path.exists(fname) and use_saved_values:    
    with open(fname, 'rb') as fin:
        grid_search_results = pickle.load(fin)

    all_scores = grid_search_results['all_scores']
    zero_betas = grid_search_results['zero_betas']
    errors = grid_search_results['errors']
    print("get saved")

else:
    all_scores = {}
    zero_betas = {}
    errors = {}
    for l1_ratio in l1_ratios:
        # for penalizer in penalizers:
        nfeatures= []

        # data preparation
        alp , lbd = get_glmnet_params(l1_ratio, penalizers[0])
        lbds = []
        for p in penalizers:
            _, lbd = get_glmnet_params(l1_ratio, p)
            lbds.append(lbd)

        r_X_tr = get_r_df(X_tr)
        r_y_tr = get_r_df(y_tr)

        # train glmnet 
        surv1 = r_surv.Surv(r_y_tr[0], r_y_tr[1])
        x_m = base.as_matrix(r_X_tr)
        r_lbds = ro.FloatVector(lbds)
        nfolds = 10
        base.set_seed(seed)
        fit = r_glmnet.cv_glmnet(x=x_m,y=surv1, alpha=alp, **{"lambda":r_lbds},family="cox",  maxit = 1e6,type_measure = "C")
        non_zeros = np.array(fit.rx2("nzero")).tolist()
        print('non_zero:{}'.format(non_zeros))
        r_lbds = np.array(fit.rx2("lambda")).tolist()
        scores = np.array(fit.rx2("cvm")).tolist()
        r_cvsd = np.array(fit.rx2("cvsd")).tolist()
        no_match = np.array(lbds != r_lbds).sum()
        print('double check num no match lbds:', no_match)

        for i, n_nonzero in enumerate(non_zeros):
            tup = (penalizers[i], l1_ratio)
            if n_nonzero > 0:  # only include hyperparams w/ a nonzero beta
                all_scores[tup] = {'scores': scores[i], 'std':r_cvsd[i], 'n_nonzero': n_nonzero}
                print("mean c:", scores[i], "std", r_cvsd[i], "mean f:", n_nonzero)
            else:
                zero_betas[tup] = {'scores': scores[i], 'std':r_cvsd[i],'n_nonzero': n_nonzero}

    grid_search_results = {
    'all_scores': all_scores,
    'zero_betas': zero_betas,
    'errors': errors,
    }

    if override_outputs:
        with open(fname, 'wb') as fout:
            pickle.dump(grid_search_results, fout)     

    print("the end")


# # Grid search result


if not cv_glmnet:
    score_summary = []
    for (tup, s) in all_scores.items():
        mean = np.mean(s['scores'])
        std = np.std(s['scores'])
        summary = {
            'hyperparams': {'penalizer': tup[0], 'l1_ratio': tup[1]},
            'mean_concordance': mean, 'std_concordance': std, 
            'beta_nonzero': s['n_nonzero'],
        }
        score_summary.append(summary)

    top3 = list(reversed(sorted(score_summary, key=lambda x: x['mean_concordance'])))[:3]
    best_params = top3[0]['hyperparams']

    zero_beta_summary = []
    for (tup, s) in zero_betas.items():
        mean = np.mean(s['scores'])
        std = np.std(s['scores'])
        summary = {
            'hyperparams': {'penalizer': tup[0], 'l1_ratio': tup[1]},
            'mean_concordance': mean, 'std_concordance': std, 
            'beta_nonzero': s['n_nonzero'],
        }
        zero_beta_summary.append(summary)
    zero_top3 = list(reversed(sorted(zero_beta_summary, key=lambda x: x['mean_concordance'])))[:3]
else:
    score_summary = []
    for (tup, s) in all_scores.items():
        #print(s)
        mean = s['scores']
        std = s['std']
        summary = {
            'hyperparams': {'penalizer': tup[0], 'l1_ratio': tup[1]},
            'mean_concordance': mean, 'std_concordance': std, 
            'beta_nonzero': s['n_nonzero'],
        }
        score_summary.append(summary)

    top3 = list(reversed(sorted(score_summary, key=lambda x: x['mean_concordance'])))[:3]
    best_params = top3[0]['hyperparams']




    zero_beta_summary = []
    for (tup, s) in zero_betas.items():
        mean = s['scores']
        std = s['std']
        summary = {
            'hyperparams': {'penalizer': tup[0], 'l1_ratio': tup[1]},
            'mean_concordance': mean, 'std_concordance': std, 
            'beta_nonzero': s['n_nonzero'],
        }
        zero_beta_summary.append(summary)
    zero_top3 = list(reversed(sorted(zero_beta_summary, key=lambda x: x['mean_concordance'])))[:3]





merged_scores = all_scores
for tup in zero_betas:
    merged_scores[tup] = zero_betas[tup]

nfeat_to_summary = {}
for (tup, s) in merged_scores.items():
    mean = s['scores']
    std = s['std']
    n_nonzero = s['n_nonzero']
    if nfeat_to_summary.get(n_nonzero, {'mean': -1})['mean'] < mean:
        nfeat_to_summary[n_nonzero] = {'mean': mean, 
                                       'std': std,
                                       'penalizer': tup[0], 
                                       'l1_ratio': tup[1]}

x = np.array(sorted(list(nfeat_to_summary.keys())))
y = np.array([nfeat_to_summary[nf]['mean'] for nf in x])
y_sigma = np.array([nfeat_to_summary[nf]['std'] for nf in x])
y_penalizer = np.array([nfeat_to_summary[nf]['penalizer'] for nf in x])
y_l1_ratio = np.array([nfeat_to_summary[nf]['l1_ratio'] for nf in x])

fig, ax = plt.subplots(3, 1, figsize=(12,8))
fig.tight_layout(pad=4)
ax[0].plot(x, y, 'bo-', lw=2, label='mean concordance')
ax[0].fill_between(x, y+y_sigma, y-y_sigma, facecolor='blue', alpha=0.5)
ax[0].set_title(r'Best Concordance vs. Number of Features Selected')
ax[0].grid()

ax[1].plot(x, y_penalizer, 'bo-', lw=2, label='penalizer')
ax[1].set_title(r'Best Penalizer vs. Number of Features Selected')
ax[1].grid()
for i, txt in enumerate(y_penalizer):
    ax[1].annotate(txt, (x[i], y_penalizer[i]))
    
ax[2].plot(x, y_l1_ratio, 'bo-', lw=2, label='l1 ratio')
ax[2].set_title(r'Best L1 Ratio vs. Number of Features Selected')
ax[2].grid()
for i, txt in enumerate(y_l1_ratio):
    ax[2].annotate(txt, (x[i], y_l1_ratio[i]))

plot_path = "plot"
if not os.path.exists(plot_path):
    os.makedirs(plot_path)
fig.suptitle('Results from grid gearch for ' + tag)
plt.savefig("{}/concordance_plot_{}.png".format(plot_path,tag))

print('penalizer:', penalizers)




from preprocess import load_csv
def get_concordances(cph, X_tr, y_tr, X_eicu, y_eicu, X_mimic, y_mimic):
    pred_tr = cph.predict_partial_hazard(X_tr)
    pred_eicu = cph.predict_partial_hazard(X_eicu)
    pred_mimic = cph.predict_partial_hazard(X_mimic)
    c_tr = concordance_index(y_tr[duration_col], -pred_tr, y_tr[event_col])
    c_eicu = concordance_index(y_eicu[duration_col], -pred_eicu, y_eicu[event_col])
    c_mimic = concordance_index(y_mimic[duration_col], -pred_mimic, y_mimic[event_col])
    #print("best CI (train, te_eicu, te_mimic):", c_tr, c_eicu, c_mimic)
    return c_tr, c_eicu, c_mimic
def neq_zero(a, prec=1e-6):
    return (a>prec) | (a< -prec)


def show_results(i, cph_results, best_cphs, figures):
    print(cph_results[i])
    print("\n\n*****test assumptions***")
    figures[i].figure
    best_cphs[i].check_assumptions(tr_dataset)

model_path = "models"
if not os.path.exists(model_path):
    os.makedirs(model_path)

best_ps = [0.025, 0.02]

print('best penalties:', best_ps)
cph_results = {}
best_cphs = []
figures = []
l = 1.0
for i, p in enumerate(best_ps):
    best_params = {"l1_ratio":l, "penalizer":p}
    best_cph = CoxPHFitter(**best_params)
    best_cph.fit(tr_dataset, duration_col=
                 duration_col, event_col=event_col, step_size=0.15)
    ctr, ceicu, cmimic = get_concordances(best_cph,X_tr, y_tr, X_te_eicu, y_te_eicu, X_te_mimic, y_te_mimic)
    nzeros = neq_zero(best_cph.params_)
    coefs = nzeros.index[nzeros.values].to_list()
    coefs_val = best_cph.params_[nzeros.values].tolist()

    summary = {
        "penalizer":p,
        "C_train": ctr,
        "C_eicu:":ceicu,
        "C_mimic":cmimic,
        "nfeatures":len(coefs),
        "features":coefs,
        "coefs": coefs_val,
        "df": pd.DataFrame({"features":coefs, "coefs":coefs_val})
    }
    cph_results[best_ps[i]]=summary
    best_cphs.append(best_cph)
    plt.rcParams['figure.figsize'] = [5, 10]
    fig = best_cph.plot()
    figures.append(fig)
    plt.close()
    print(summary)
    
with open("{}/{}_summary.pkl".format(model_path, tag), "wb") as fout:
    pickle.dump(cph_results, fout)

print(cph_results)                          
