# Audit (Exercise 3)

## Repository audited

Teammate: https://github.com/viki-sh/DSC180A-Methodology-6, at commit `9d38a1e` ("report: REPORT.md"). The diff under review is everything since their unmodified starter commit `b46d3bf`, limited to `src/` and `tests/`. That covers `src/config.py`, `src/features.py`, `src/ingest.py`, `src/train.py`, `tests/test_contract.py`, `tests/test_leakage.py` and `tests/test_report.py`.

## How it was run

2026-11-25. The `leakage-auditor` subagent from this repo's `.claude/agents/leakage-auditor.md` (unchanged from the starter) ran headless through Claude Code. It could read files and run commands, and Edit, Write and NotebookEdit were blocked:

```
cd bikeshare-open-starter
claude -p "Use the leakage-auditor subagent to review the teammate repository at <clone> (https://github.com/viki-sh/DSC180A-Methodology-6). The diff under review is everything the teammate changed since their unmodified starter commit: git -C <clone> diff b46d3bf HEAD -- src tests. Read src/config.py in that repo, not this one. To run code, cd into that repo and use <venv>/bin/python. Do not modify any files. When the subagent finishes, output its report verbatim and nothing else." \
  --add-dir <clone> --allowedTools "Task,Agent,Read,Grep,Glob,Bash" \
  --disallowedTools "Edit,Write,NotebookEdit" --output-format json
```

Model: `claude-opus-5-5`, hosted. The local `qwen3.5:9b` (`bikeshare-coder`) took about 10 minutes per turn on this 18 GB laptop, so a git-ignored `.claude/settings.local.json` switched the model and endpoint for this run. Run metadata: `subtype: success`, 2 turns, 242.7 s, $1.07.

## `/leakage-auditor` output, verbatim

I found one rule violation in the diff, and it's low severity: the Exercise 4 path reports model scores without either baseline. It doesn't change any number or flip any conclusion. Rules 1–3 and row accounting are clean, and every committed number reproduces from the code.

### Finding

**Exercise 4 scores are reported with no baselines.** Rule 4, low severity, confirmed by running the code.
- **Where:** `/Users/brian/Documents/UCSD/Y3Q1/bikeshare-open/.audit/teammate/src/train.py:134-147`. `exercise4()` only scores the requested `(model, transform)` pairs.
- **Effect:** `--target-transform` prints validation scores with no mean or persistence row. The one-shot test record, `reports/exercise4_test.json`, holds three model scores and no baseline. REPORT.md's Exercise 4 validation table (lines 56-62) shows no baselines. Its test table (87-93) adds persistence by hand from `metrics.json` but leaves out the mean baseline.
- **Scenario:** someone reading `exercise4_test.json` on its own sees hgb + `ratio_roll_7` at test R² 0.6301. They can't tell that persistence scores 0.5099 / MAE 840.1, so the MAE lead is only 6.4 rides a day.
- **Conclusion unchanged:** I reran the baselines on the same splits (persistence valid 0.4507 / 900.6, mean valid -0.9318 / 2002.2). hgb + `ratio_roll_7` beats both on validation and test, and REPORT.md already states the 6-ride margin.
- **Minimal fix:** in `exercise4()`, before the pairs loop, fit `clone(MODELS["baseline_mean"])` and `clone(MODELS["baseline_persistence"])` on `train[cols]`. Add their r2/mae for the same `splits` to `out`, so both the printed output and `EX4_TEST` carry them.

### Rules the diff passes

- **Rule 1, leakage (confirmed by running):**
  - The teammate didn't change `FORBIDDEN`, `TRAIN_END`, `VALID_END` or `LAG_WARMUP`. The `config.py` additions (`RAW_SHA256`, `CLASSIFIED`) only make the checks stricter.
  - The feature list is still derived from `FORBIDDEN`. The 15 features overlap none of the forbidden columns.
  - A least-squares fit of all 15 features on all rows gets R² 0.837, so no combination of features restates `cnt`.
  - The Exercise 4 transforms convert back to ride counts using only `cnt_lag_1` / `cnt_roll_7`, which are known at prediction time.
- **Rule 2, temporal split (confirmed by running and from git history):**
  - Split boundaries fall at 2011-12-31 / 2012-01-01 and 2012-06-30 / 2012-07-01, giving 348 / 182 / 184 rows.
  - `StandardScaler` sits inside the pipeline, and `TargetTransformed` copies its model and fits on train only.
  - Only one commit (`a1b8ae3`) writes `exercise4_test.json`, and the chosen pairs were committed 29 seconds earlier in `c916fe6`.
- **Rule 3, calendar lags (confirmed by running):**
  - `weather_severity_lag_1` (`features.py:74`) is a plain `.shift(1)` applied after `reindex_to_calendar`. It's a lag, not an aggregation, and it has a test in `tests/test_leakage.py:60`.
  - That test fails, as it should, when the lag is swapped for same-day or next-day weather.
  - A row-based shift would give identical values on every kept row, because the rows after 2011-03-10 are dropped anyway.
- **Silent row loss (confirmed by running):** 14 rows are lost, exactly the 14 that `test_only_expected_rows_are_dropped` allows. The new feature adds no loss. `encode_weather` still raises on labels it doesn't know.
- **Reproducibility:** all 23 tests pass. Every value in `reports/metrics.json` and `reports/exercise4_test.json` reproduces from the current code.

### Gaps in test coverage

- **Rule 4:** nothing tests `exercise4()` or `TargetTransformed`. `test_persistence_baseline_is_reported` (`tests/test_contract.py:102`) only checks that the key exists in `MODELS`. `test_beats_the_mean_baseline` (line 93, from the starter) asserts ridge test R² > 0.4, which is below persistence's 0.5099, so ridge could lose to persistence and the suite would stay green.
- **Rule 2:** `tests/test_split.py` (from the starter) imports `TRAIN_END` and `VALID_END` but never uses them. If the split dates in `config.py` moved, the suite would stay green. This isn't a live problem, because the dates are unchanged.
- **Rules 1 and 3:** covered.

### Side effects of this audit

- **One file write:** my first ad-hoc `python -c` ran before I disabled bytecode writing, so it created a gitignored `/Users/brian/Documents/UCSD/Y3Q1/bikeshare-open/.audit/teammate/src/__pycache__/` (4 `.pyc` files). Deleting files was also off-limits, so I left it; it's safe to delete.
- **Everything else read-only:** later runs, including pytest, wrote nothing to the repo.
- **Unregistered test scores:** to reproduce the results, I computed in memory test scores for the transform pairs the teammate did not pre-register. I've left them out of this report on purpose so their one-shot test stays clean.

## Verdict

None of the auditor's findings change a number in the teammate's repo. I agree with all of it, and before reading its report I had reached the same reading of the diff. `weather_severity_lag_1` is a plain one-day shift on the gap-free calendar, the split and the scaler are untouched, `FORBIDDEN` still controls the feature list, and the new SHA-256 and column-classification checks only make the pipeline stricter. The one rule violation is that the Exercise 4 output carries no mean or persistence baseline. That is real, but it is a reporting gap: the auditor reran both baselines on the same splits, the teammate's conclusion that hgb with `ratio_roll_7` beats persistence still holds, and their REPORT.md already gives the 6.4-rides-per-day MAE margin. I also agree with the two coverage gaps, and they are starter code, not the teammate's. `test_beats_the_mean_baseline` sets a bar (ridge test R² > 0.4) below persistence's 0.5099, and `tests/test_split.py` never checks the split dates. Neither is wrong today. They would only let a future regression through. The same R² > 0.4 test is in this repo, and `agent/audit.py` flagged it here too (see `reports/audit.jsonl`).

## `agent/audit.py` on this repo

`AUDIT_MODEL=claude-opus-5-5 python agent/audit.py . --out reports/audit.jsonl` printed `audited 1 repos; 0 flagged -> reports/audit.jsonl`. It returned `leakage: none`, `temporal_ok: true`, `baseline_reported: true`, `reproducible: true` and `confidence: high`, plus four findings that are not leakage:

- the R² > 0.4 test is run on the test split and sits below persistence;
- same-day observed weather makes the scores an upper bound on real day-ahead accuracy;
- no test covers `cnt_lag_7`;
- `src/ingest.py` checks neither an exact row count nor a file hash.

None of the four change a reported number.
