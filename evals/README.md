# BSC eval harness

Objective benchmark for one question: **do these skills actually make an AI
generate correct BiSheng C?** The compiler is the only judge.

## Pieces

| File | Role |
|---|---|
| `corpus.json` | 33 evals across 8 feature areas (Ownership, Trait, Generic, SafeZone, NullabilityCheck, OwnedStruct, Coroutine, Method). Each has a natural-language task a real user would ask, a grounding `reference_test` in the compiler repo's `clang/test/BSC/Positive/`, and `expected_skills` for the trigger metric. |
| `judge.sh <file.cbs>` | Compiles the file with `$BSC_CLANG`; exit code is the verdict. Default `-fsyntax-only` (all BSC semantic checks — ownership, borrow, safe zone, nullability — run in Sema). `BSC_JUDGE_MODE=binary` additionally links. On macOS the SDK sysroot is auto-detected via `xcrun`. |
| `run.sh` | Bare-model vs with-skills comparison. For each eval × arm × rep it runs `claude -p` in an isolated project (`--setting-sources project`): the *bare* arm sees no skills, the *skill* arm gets the repo installed via `install.sh -a claude`. Bash is disallowed during generation — this measures one-shot generation, not compile-and-repair loops. Outputs `results.json`, `results.md`, `runs.jsonl`. |
| `lint.sh` | Structural checks (skill frontmatter, 500-line limit, corpus validity + reference paths). Run by CI on every PR. |

## Metrics

- **pass rate** — per eval per arm, fraction of N reps whose `solution.cbs`
  passes `judge.sh`; overall reported as mean ± stddev across evals.
- **skill-trigger hit rate** — in the skill arm, fraction of runs where at
  least one `expected_skills` entry actually fired (parsed from the
  `stream-json` event log). Answers "does the model pick the right skill for
  the scenario", not just "were skills present".
- **duration / tokens / cost** — from the `claude -p` result event.

## Running locally

```bash
export BSC_CLANG=/path/to/bsc/build/bin/clang

# small sample (3 evals, both arms, N=3)
evals/run.sh --ids ownership-linked-list-safezone-02,trait-dynamic-dispatch-02,method-on-int-03 --n 3

# full corpus
evals/run.sh
```

Knobs: `EVAL_MODEL` (default `sonnet` — pin it when publishing numbers),
`EVAL_N`, `EVAL_PARALLEL`, `EVAL_TIMEOUT`, `EVAL_MAX_TURNS`.

Needs: `jq`, `claude` (logged in or `ANTHROPIC_API_KEY`), a built BSC clang,
and a checkout of the compiler repo if you want `lint.sh` to verify
`reference_test` paths (`BSC_MAIN_REPO`, default `../BiShengCLanguage`).

## Corpus discipline

Prompts are written as a user would speak (scenario-first, colloquial allowed)
and never quote the reference test's code. Every `reference_test` was verified
to exist **and** to pass `judge.sh` with the real compiler before being added.
When adding evals, keep both properties, and run `evals/lint.sh` before
pushing.
