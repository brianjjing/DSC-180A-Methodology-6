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

The naive evaluation is invalid. Given `casual` and `registered`, a model
scores test R² 1.000 (`python -m src.leakage_demo`), because those two columns
add up exactly to `cnt`. Under the temporal split (train on 2011, test on H2
2012), the honest numbers are:

- **Mean baseline:** predicting the 2011 average gives test R² −2.1441,
  because ridership grew.
- **Persistence:** predicting yesterday's count gives 0.5099.
- **Ridge:** 0.6356. It beats persistence by 0.126 R², but the two tie on MAE
  (840.3 vs 840.1 rides a day).
- **Gradient boosting:** −0.6959. It still beats the mean baseline, but it
  cannot predict above the highest 2011 count of 6,043 rides, and 56.5% of
  test days are higher than that.

So ridge wins, and only because it can extrapolate a growth trend that the
tree cannot. My feature, `cnt_roll_7_std`, raised ridge validation R² from
0.6475 to 0.7224 and lowered hgb from 0.2185 to 0.0977; I kept it for ridge.

## Exercise 4: target transformation

**The problem.** A tree predicts a constant in each leaf, so it can never
predict more than the highest value it saw in training. The highest 2011
count is 6,043 rides. 39.0% of validation days and 56.5% of test days are
above it, which is why untransformed hgb scores validation R² 0.0977 and
test R² −0.6959.

**What I tried.** In each version, the model is fit to a transformed target
and its predictions are converted back to ride counts. Every inversion uses
only a column known on the day being predicted: `cnt_lag_1` (yesterday) or
`cnt_roll_7` (the mean of the previous 7 days). The code is in
`src/train.py`, behind `--target-transform`. Plain `python -m src.train`, and
so `reports/metrics.json`, stays untransformed.

| Transform | What the model predicts | Ridge valid R² | Ridge valid MAE | hgb valid R² | hgb valid MAE |
|---|---|---:|---:|---:|---:|
| none | `cnt` | 0.7224 | 700.4 | 0.0977 | 1381.6 |
| `log` | `log(cnt)` | −0.9243 | 1755.2 | −0.0339 | 1501.2 |
| `diff_lag_1` | `cnt − cnt_lag_1` | 0.7220 | 699.9 | 0.5642 | 885.8 |
| `diff_roll_7` | `cnt − cnt_roll_7` | 0.7263 | 690.5 | 0.7167 | 725.9 |
| `ratio_roll_7` | `cnt / cnt_roll_7` | 0.6128 | 857.3 | 0.7483 | 685.5 |

For reference, persistence scores validation R² 0.4507 and MAE 900.6.

`log` does not help the tree. The log of a count is still capped at the log
of the 2011 maximum, so the trend is still there. The three transforms that
compare each day with a recent level do help, because they replace an
unbounded count with a change or ratio whose range was already seen in 2011.

**Test set, touched once.** I chose `ratio_roll_7` on validation, because it
gave hgb its best score there, and committed to it before looking at any test
number. I then ran `python -m src.train --target-transform ratio_roll_7
--touch-test` once. It scores ridge and hgb under that transform; the other
rows come from `reports/metrics.json`. No other transform was scored on test.

| Model | Valid R² | Valid MAE | Test R² | Test MAE |
|---|---:|---:|---:|---:|
| baseline_persistence | 0.4507 | 900.6 | 0.5099 | 840.1 |
| ridge, untransformed | 0.7224 | 700.4 | 0.6356 | 840.3 |
| hgb, untransformed | 0.0977 | 1381.6 | −0.6959 | 2108.4 |
| ridge, `ratio_roll_7` | 0.6128 | 857.3 | 0.1977 | 1323.3 |
| hgb, `ratio_roll_7` | 0.7483 | 685.5 | 0.6280 | 832.8 |

**Is it defensible?** The transformation is. The comparison it seems to win
is not.

The transformation is a legitimate model. It uses no information from the
day being predicted, because `cnt_roll_7` is built from the 7 days before. I
chose it because of the extrapolation failure diagnosed above, before seeing
any transformed score. And it is a standard way to remove a level trend:
model each day relative to the recent level, then multiply back. It closes a
1.32-point test R² gap, from −0.6959 to 0.6280.

"Gradient boosting beats ridge" is not a defensible conclusion, for three
reasons:

1. **The transform was picked for the tree.** I chose the best of four
   transforms for hgb on validation and compared it against untransformed
   ridge. Under the same transform, ridge collapses (test R² 0.1977). Under
   `diff_roll_7`, the two are level on validation (0.7263 vs 0.7167).
2. **The validation margin is noise-sized.** hgb leads untransformed ridge by
   0.026 R² on validation. In Exercise 1, the 95% interval for a single
   feature change was about ±0.035 wide.
3. **On test it is a tie.** hgb with `ratio_roll_7` scores R² 0.6280 and MAE
   832.8. Ridge scores 0.6356 and 840.3, and persistence 840.1. All three
   are within 8 rides a day on MAE.

My conclusion: the tree fails because of the trend, not because the model
family is worse. Once the trend is removed it matches ridge, but it does not
beat ridge, and neither model clearly beats persistence on MAE. The committed
pipeline stays untransformed.

## Exercise 5: ridge vs persistence

_TODO_

## Attribution

_TODO_
