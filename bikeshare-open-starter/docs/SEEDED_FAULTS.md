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
