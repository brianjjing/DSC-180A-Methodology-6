---
name: seed-fault
description: Break the pipeline on purpose with one described fault, record the exact diff, the `make test` output and the PostToolUse hook's stderr in docs/SEEDED_FAULTS.md, then restore. Use when asked to seed a fault, break the pipeline on purpose, or check whether a test or the hook catches a change.
argument-hint: <fault, e.g. "delete the .shift(1) from cnt_roll_7">
allowed-tools: Read, Edit, Bash(make*), Bash(git status*), Bash(git diff*), Bash(git checkout -- src/*), Bash(bash .claude/skills/seed-fault/run_hook.sh*)
---

# Seeding a fault: $ARGUMENTS

Work in this order. Paste real output at every step; never paraphrase it,
trim it into something it did not say, or invent it.

1. **Check the tree is clean.** Run `git status --short src/ tests/` and
   `make test`. If either shows changes or failures, stop and say so: a
   fault seeded on a dirty tree cannot be cleanly undone. Note the pass count.

2. **Seed it.** Make the single smallest Edit under `src/` that implements
   the fault. Do not touch `tests/`. Never write to `data/raw/`; if the
   fault is about raw data, say that it must be seeded by hand and stop.

3. **Record the change:** `git diff src/`.

4. **Run the tests:** `make test`. Keep the full output.

5. **Run the hook:** `bash .claude/skills/seed-fault/run_hook.sh src/<file>.py`.
   This sends `.claude/hooks/check_leakage.sh` the same payload Claude Code
   sends after an Edit, so its stderr and exit code can be recorded word for
   word.

6. **If `make test` stayed green, that is the finding.** The suite missed
   this fault. Say so plainly and name the test that would catch it. Do not
   write that test unless asked.

7. **Restore:** `git checkout -- src/<file>.py`, then `make test`. The pass
   count must match step 1. Count the turns from the first red output to
   the restored green run.

8. **Record it.** Append a section to `docs/SEEDED_FAULTS.md`, titled
   `### Fault: $ARGUMENTS`, with four parts: the exact change (step 3), the
   test output (step 4), the hook's stderr and exit code (step 5), and the
   number of turns to fix (step 7). Say the count is a lower bound, because
   the agent that seeded the fault already knew the fix.

Finish with three lines: red or green, the hook's exit code, and the number
of turns to fix.
