# Seeded faults

## Exercise 1: `cnt_roll_7_std` test, written before the feature

`tests/test_leakage.py::test_rolling_std_excludes_today` added, `src/features.py` untouched. `make test`:

```
python -m pytest tests/ -q
.........F.....                                                          [100%]
=================================== FAILURES ===================================
_______________________ test_rolling_std_excludes_today ________________________

feats =         dteday  instant  season  ...  cnt_lag_1 cnt_lag_7   cnt_roll_7
0   2011-01-10     10.0  WINTER  ...      822.0...    1787.0  1530.142857
713 2012-12-31    731.0  WINTER  ...     1796.0     920.0  1531.428571

[714 rows x 28 columns]

    def test_rolling_std_excludes_today(feats):
        """cnt_roll_7_std on 2012-03-15 is the sample std of cnt on 2012-03-08..14,
        hand-computed from strictly earlier calendar days."""
        import statistics
        by_date = feats.set_index("dteday")
        date = pd.Timestamp("2012-03-15")
        window = [by_date[TARGET][date - pd.Timedelta(days=k)] for k in range(1, 8)]
>       assert by_date.cnt_roll_7_std[date] == pytest.approx(statistics.stdev(window))
               ^^^^^^^^^^^^^^^^^^^^^^

tests/test_leakage.py:67: 
_ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ 

self =             instant  season      yr  ... cnt_lag_1 cnt_lag_7   cnt_roll_7
dteday                               ...    ... 1787.0  1530.142857
2012-12-31    731.0  WINTER  2012.0  ...    1796.0     920.0  1531.428571

[714 rows x 27 columns]
name = 'cnt_roll_7_std'

    @final
    def __getattr__(self, name: str):
        """
        After regular attribute access, try looking up the name
        This allows simpler access to columns for interactive use.
        """
        # Note: obj.x will always call obj.__getattribute__('x') prior to
        # calling obj.__getattr__('x').
        if (
            name not in self._internal_names_set
            and name not in self._metadata
            and name not in self._accessors
            and self._info_axis._can_hold_identifiers_and_holds_name(name)
        ):
            return self[name]
>       return object.__getattribute__(self, name)
               ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
E       AttributeError: 'DataFrame' object has no attribute 'cnt_roll_7_std'. Did you mean: 'cnt_roll_7'?

../.venv/lib/python3.14/site-packages/pandas/core/generic.py:6194: AttributeError
=========================== short test summary info ============================
FAILED tests/test_leakage.py::test_rolling_std_excludes_today - AttributeErro...
1 failed, 14 passed in 1.01s
make: *** [test] Error 1
```

Fails for the right reason: the column does not exist yet. On 2012-03-15 the hand-computed value is 747.23. Without the `.shift(1)`, the rolling std would include today and give 836.53, so the test also catches a missing shift.

## Exercise 2: seeded faults

Run 2026-11-25 on top of commit `153fddd` (Exercise 1), with a green baseline of `15 passed`. Each fault was seeded alone in `src/features.py`, run, and reverted before the next one. The three code faults were seeded as file edits, not through Claude Code's Edit tool, so the hook was run by hand with the same JSON payload Claude Code sends after an `Edit` of `src/features.py`:

```
printf '{"tool_name":"Edit","tool_input":{"file_path":"<repo>/src/features.py"}}' | CLAUDE_PROJECT_DIR="$PWD" bash .claude/hooks/check_leakage.sh
```

Everything the hook prints goes to stderr. Exit 2 is what sends that stderr back to the agent.

Turns to fix are lower bounds. The agent that seeded each fault also fixed it and already knew the change.

### Fault 1: a forbidden column added to `feature_columns`

Exact change:

```diff
@@ -84,7 +84,7 @@ def build_features(df: pd.DataFrame) -> pd.DataFrame:
 def feature_columns(df: pd.DataFrame) -> list[str]:
     """Numeric columns that are safe to feed the model."""
     numeric = df.select_dtypes(include="number").columns
-    return [c for c in numeric if c not in FORBIDDEN]
+    return [c for c in numeric if c not in FORBIDDEN] + ["casual"]
```

Red test output, `make test`:

```
python -m pytest tests/ -q
.....F.........                                                          [100%]
=================================== FAILURES ===================================
__________________________ test_no_forbidden_features __________________________

feats =         dteday  instant  season  ...  cnt_lag_7   cnt_roll_7 cnt_roll_7_std
0   2011-01-10     10.0  WINTER  ...     1...857     886.694316
713 2012-12-31    731.0  WINTER  ...      920.0  1531.428571     887.135250

[714 rows x 29 columns]

    def test_no_forbidden_features(feats):
        """Guards the gate, not the data: feature_columns() excludes FORBIDDEN by
        construction, so this cannot discover a *new* leaky column. What it
        catches is someone editing feature_columns() or FORBIDDEN -- which is
        exactly the fault the Step 7 hook demonstrates."""
        cols = set(feature_columns(feats))
>       assert not (cols & FORBIDDEN), f"forbidden columns in feature set: {cols & FORBIDDEN}"
E       AssertionError: forbidden columns in feature set: {'casual'}
E       assert not ({'atemp', 'casual', 'cnt_lag_1', 'cnt_lag_7', 'cnt_roll_7', 'cnt_roll_7_std', ...} & {'casual', 'cnt', 'cnt_2d_bfr', 'days_since_2011', 'instant', 'registered', ...})

tests/test_leakage.py:31: AssertionError
=========================== short test summary info ============================
FAILED tests/test_leakage.py::test_no_forbidden_features - AssertionError: fo...
1 failed, 14 passed in 1.72s
make: *** [test] Error 1
```

Hook stderr (exit 2):

```
Leakage tests failed after editing /Users/brian/Documents/UCSD/Y3Q1/bikeshare-open/bikeshare-open-starter/src/features.py:
feats =         dteday  instant  season  ...  cnt_lag_7   cnt_roll_7 cnt_roll_7_std
0   2011-01-10     10.0  WINTER  ...     1...857     886.694316
713 2012-12-31    731.0  WINTER  ...      920.0  1531.428571     887.135250

[714 rows x 29 columns]

    def test_no_forbidden_features(feats):
        """Guards the gate, not the data: feature_columns() excludes FORBIDDEN by
        construction, so this cannot discover a *new* leaky column. What it
        catches is someone editing feature_columns() or FORBIDDEN -- which is
        exactly the fault the Step 7 hook demonstrates."""
        cols = set(feature_columns(feats))
>       assert not (cols & FORBIDDEN), f"forbidden columns in feature set: {cols & FORBIDDEN}"
E       AssertionError: forbidden columns in feature set: {'casual'}
E       assert not ({'atemp', 'casual', 'cnt_lag_1', 'cnt_lag_7', 'cnt_roll_7', 'cnt_roll_7_std', ...} & {'casual', 'cnt', 'cnt_2d_bfr', 'days_since_2011', 'instant', 'registered', ...})

tests/test_leakage.py:31: AssertionError
=========================== short test summary info ============================
FAILED tests/test_leakage.py::test_no_forbidden_features - AssertionError: fo...
1 failed, 7 passed in 0.31s
[hook exit: 2]
```

Turns to fix: 1. One edit reverted the line, then `make test` printed `15 passed in 0.98s`.

### Fault 2: `.shift(1)` deleted from `cnt_roll_7`

Exact change:

```diff
@@ -73,7 +73,7 @@ def build_features(df: pd.DataFrame) -> pd.DataFrame:
     # If you add a longer lag, raise LAG_WARMUP in src/config.py.
     out["cnt_lag_1"] = out[TARGET].shift(1)
     out["cnt_lag_7"] = out[TARGET].shift(LAG_WARMUP)
-    out["cnt_roll_7"] = out[TARGET].shift(1).rolling(LAG_WARMUP).mean()
+    out["cnt_roll_7"] = out[TARGET].rolling(LAG_WARMUP).mean()
```

Red test output, `make test`:

```
python -m pytest tests/ -q
........F......                                                          [100%]
=================================== FAILURES ===================================
_______________________ test_rolling_mean_excludes_today _______________________

feats =         dteday  instant  season  ...  cnt_lag_7   cnt_roll_7 cnt_roll_7_std
0   2011-01-10     10.0  WINTER  ...     1...571     886.694316
713 2012-12-31    731.0  WINTER  ...      920.0  1789.857143     887.135250

[714 rows x 29 columns]

    def test_rolling_mean_excludes_today(feats):
        """cnt_roll_7 must be the mean of the 7 calendar days *before* today."""
        by_date = feats.set_index("dteday")[TARGET]
        date = feats.dteday.iloc[200]
        window = [date - pd.Timedelta(days=k) for k in range(1, 8)]
        if all(d in by_date.index for d in window):
            expected = sum(by_date[d] for d in window) / 7
>           assert feats.set_index("dteday").cnt_roll_7[date] == pytest.approx(expected)
E           assert np.float64(4389.0) == 4414.857142857143 ± 0.00441486
E             
E             comparison failed
E             Obtained: 4389.0
E             Expected: 4414.857142857143 ± 0.00441486

tests/test_leakage.py:57: AssertionError
=========================== short test summary info ============================
FAILED tests/test_leakage.py::test_rolling_mean_excludes_today - assert np.fl...
1 failed, 14 passed in 1.44s
make: *** [test] Error 1
```

Hook stderr (exit 2):

```
Leakage tests failed after editing /Users/brian/Documents/UCSD/Y3Q1/bikeshare-open/bikeshare-open-starter/src/features.py:
[714 rows x 29 columns]

    def test_rolling_mean_excludes_today(feats):
        """cnt_roll_7 must be the mean of the 7 calendar days *before* today."""
        by_date = feats.set_index("dteday")[TARGET]
        date = feats.dteday.iloc[200]
        window = [date - pd.Timedelta(days=k) for k in range(1, 8)]
        if all(d in by_date.index for d in window):
            expected = sum(by_date[d] for d in window) / 7
>           assert feats.set_index("dteday").cnt_roll_7[date] == pytest.approx(expected)
E           assert np.float64(4389.0) == 4414.857142857143 ± 0.00441486
E             
E             comparison failed
E             Obtained: 4389.0
E             Expected: 4414.857142857143 ± 0.00441486

tests/test_leakage.py:57: AssertionError
=========================== short test summary info ============================
FAILED tests/test_leakage.py::test_rolling_mean_excludes_today - assert np.fl...
1 failed, 7 passed in 0.28s
[hook exit: 2]
```

Turns to fix: 1. One edit restored `.shift(1)`, then `make test` printed `15 passed in 1.03s`.

### Fault 3: the weather encoder's `raise` removed

Exact change:

```diff
@@ -26,8 +26,6 @@ def encode_weather(series: pd.Series) -> pd.Series:
     """
     known = series.dropna()
     unknown = set(known.unique()) - set(WEATHER_ORDER)
-    if unknown:
-        raise ValueError(f"unmapped weather labels: {sorted(unknown)}")
     return series.map(WEATHER_ORDER).astype(float)
```

Test output, `make test`. Nothing went red:

```
python -m pytest tests/ -q
...............                                                          [100%]
15 passed in 1.56s
```

Hook stderr: none. The hook ran the leakage tests, they passed, and it exited 0:

```
[hook exit: 0]
```

The fault is still real. With the `raise` gone, an unseen label quietly becomes `NaN`, which `build_features` then removes with `dropna()`:

```
$ python -c "import pandas as pd; from src.features import encode_weather; print(encode_weather(pd.Series(['GOOD','STORM','BAD'])).tolist())"
[0.0, nan, 2.0]
[exit: 0]
```

With the `raise` restored, the same call fails loudly:

```
ValueError: unmapped weather labels: ['STORM']
[exit: 1]
```

Turns to fix: 1. One edit restored the two lines, then `make test` printed `15 passed in 1.23s`. The agent only fixed this because it had seeded it. No test and no hook output pointed at it. The suite misses this fault because the current CSV has only GOOD, MISTY and BAD, so `raise` never runs, and no test sends `encode_weather` an unseen label. A test that would catch it: `with pytest.raises(ValueError): encode_weather(pd.Series(["STORM"]))`.

### Fault 4: a Bash `cp` into `data/raw/`, which the hook cannot see

What happened: a copy of the raw CSV with every H2-2012 `casual`, `registered` and `cnt` doubled was copied over the real file from Bash. Doubling all three keeps `casual + registered == cnt` true, and the row count stays 728. Python's `csv` writer also dropped the quotes around text fields, so every line shows up in the diff.

```
$ shasum -a 256 data/raw/bike_daily.csv
a6bed1577f6e4de56dcfae6d8315985073cc0ad3446c8c99ed60c86a0b5ad9dc  data/raw/bike_daily.csv

$ cp .fault4/bike_daily.csv data/raw/bike_daily.csv   # every H2-2012 casual/registered/cnt doubled
[cp exit: 0]

$ shasum -a 256 data/raw/bike_daily.csv
6550d0651e35e57be42ae21c33a61eeddc78771d66e8ecc9ec48e5f4acc0f532  data/raw/bike_daily.csv

$ git diff --stat data/raw/bike_daily.csv
 bikeshare-open-starter/data/raw/bike_daily.csv | 1458 ++++++++++++------------
 1 file changed, 729 insertions(+), 729 deletions(-)
```

The hook did not fire. In `.claude/settings.json` it only matches the Edit and Write tools, and the deny rules cover only `Write(./data/raw/**)` and `Edit(./data/raw/**)`. A Bash `cp` matches neither. Even when the hook script is handed a Bash payload, it finds no `file_path` and exits 0:

```
--- hook wiring: .claude/settings.json ---
12:        "matcher": "Edit|Write",
--- even if the hook were invoked with this Bash payload ---
[hook exit: 0, no stderr]
```

Every test still passed and the full pipeline ran, while every test-set number changed:

```
$ make test
python -m pytest tests/ -q
...............                                                          [100%]
15 passed in 1.56s
[make exit: 0]

$ make all
python -m src.ingest
OK ingest: 728 rows, 2011-01-03 -> 2012-12-31
python -m src.features
OK features: 714 rows, 15 features -> features.parquet
  temp, atemp, hum, windspeed, dayofweek, is_weekend, is_holiday, is_workday, month_sin, month_cos, weather_severity, cnt_lag_1, cnt_lag_7, cnt_roll_7, cnt_roll_7_std
python -m src.train
{
  "n_features": 15,
  "n_train": 348,
  "n_valid": 182,
  "n_test": 184,
  "baseline_mean": {
    "valid": {
      "r2": -0.9318,
      "mae": 2002.2
    },
    "test": {
      "r2": -6.0885,
      "mae": 8715.2
    }
  },
  "baseline_persistence": {
    "valid": {
      "r2": 0.4507,
      "mae": 900.6
    },
    "test": {
      "r2": 0.4969,
      "mae": 1707.7
    }
  },
  "ridge": {
    "valid": {
      "r2": 0.7224,
      "mae": 700.4
    },
    "test": {
      "r2": 0.4413,
      "mae": 2226.5
    }
  },
  "hgb": {
    "valid": {
      "r2": 0.0977,
      "mae": 1381.6
    },
    "test": {
      "r2": -4.9385,
      "mae": 8017.1
    }
  }
}
[make exit: 0]
```

Ridge test R² went from 0.6356 to 0.4413 and test MAE from 840.3 to 2226.5, with no warning anywhere. Validation numbers did not move because only H2 2012 was changed. (A joblib warning about counting CPU cores is cut from the `src.train` output above. It is unrelated.)

Restored:

```
$ git checkout -- data/raw/bike_daily.csv
$ shasum -a 256 data/raw/bike_daily.csv
a6bed1577f6e4de56dcfae6d8315985073cc0ad3446c8c99ed60c86a0b5ad9dc  data/raw/bike_daily.csv
```

`make all` then reproduced a `reports/metrics.json` identical to the pre-fault copy, and `make test` printed `15 passed in 1.13s`.

What would have caught it (named, not implemented):

- **A hash check in `load_raw`.** Assert that the SHA-256 of `data/raw/bike_daily.csv` equals `a6bed1577f6e…`. Every `make` stage and every test loads through `load_raw`, so this check sees the file's contents no matter which tool changed it. It is the only option here that fails closed.
- **A PreToolUse hook on Bash** that rejects commands writing into `data/raw/` (`cp`, `mv`, `>`, `tee`, `sed -i`). This is a speed bump: a command that builds the path indirectly gets past it.
- **A filesystem permission:** `chmod a-w data/raw/bike_daily.csv`, so `cp` fails unless someone deliberately changes the mode back.
- **A Stop hook running `make test`** only helps once a test checks the hash. Without one, the tests above stay green.
