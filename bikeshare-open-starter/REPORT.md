# Bikeshare demand: report

## Results

Train 2011, validate H1 2012 (182 days), test H2 2012 (184 days). "Before" is
the starter's 14 features; "after" adds `cnt_roll_7_std` (Exercise 1). After
rows match `reports/metrics.json`.

| Model | Features | Valid R² | Valid MAE | Test R² | Test MAE |
|---|---|---:|---:|---:|---:|
| baseline_mean | before | -0.9318 | 2002.2 | -2.1441 | 2847.7 |
| baseline_persistence | before | 0.4507 | 900.6 | 0.5099 | 840.1 |
| ridge | before | 0.6475 | 832.9 | 0.5833 | 947.1 |
| hgb | before | 0.2185 | 1296.6 | -0.4975 | 1972.6 |
| baseline_mean | after | -0.9318 | 2002.2 | -2.1441 | 2847.7 |
| baseline_persistence | after | 0.4507 | 900.6 | 0.5099 | 840.1 |
| ridge | after | 0.7224 | 700.4 | 0.6356 | 840.3 |
| hgb | after | 0.0977 | 1381.6 | -0.6959 | 2108.4 |

Validation delta from `cnt_roll_7_std`: ridge R² +0.0749 and MAE −132.5; hgb
R² −0.1208 and MAE +85.0. The feature was chosen as the best of 17 candidates
on validation, so the ridge gain is probably overstated. The baselines don't
use the feature, so their rows are the same.

## Headline finding

_TODO_

## Exercise 4: target transformation

_TODO_

## Exercise 5: ridge vs persistence

_TODO_

## Attribution

_TODO_
