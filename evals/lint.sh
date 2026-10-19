#!/usr/bin/env bash
# lint.sh — structural checks for the skills repo. Used by CI (lint-skills.yml)
# and runnable locally from the repo root.
#
# Checks:
#   1. every skills/*/SKILL.md exists, frontmatter has name + description,
#      and name matches the directory name
#   2. SKILL.md stays under 500 lines (legacy oversized files are grandfathered
#      below with a TODO to split them into references/)
#   3. evals/corpus.json is valid JSON, every eval has the required fields,
#      ids are unique, and every reference_test exists in a checkout of the
#      main compiler repo (BSC_MAIN_REPO, default: ../BiShengCLanguage)
set -u
cd "$(dirname "$0")/.."

fail=0
err() { echo "LINT FAIL: $*" >&2; fail=1; }

# TODO(split): these two predate the 500-line rule; split their bodies into
# references/*.md and then remove them from this allowlist.
grandfathered="c-to-bsc bsc-common-mistakes"

for d in skills/*/; do
  s=$(basename "$d")
  f=$d/SKILL.md
  if [ ! -f "$f" ]; then err "$s: missing SKILL.md"; continue; fi

  fm=$(awk '/^---$/{c++; next} c==1{print} c>=2{exit}' "$f")
  echo "$fm" | grep -q '^name:' || err "$s: frontmatter missing name"
  echo "$fm" | grep -q '^description:' || err "$s: frontmatter missing description"
  fm_name=$(echo "$fm" | sed -n 's/^name:[[:space:]]*//p' | tr -d '"' | head -1)
  [ "$fm_name" = "$s" ] || err "$s: frontmatter name '$fm_name' != directory name"

  lines=$(wc -l < "$f" | tr -d ' ')
  if [ "$lines" -ge 500 ]; then
    case " $grandfathered " in
      *" $s "*) echo "LINT WARN: $s: SKILL.md has $lines lines (grandfathered, see TODO(split))" >&2 ;;
      *) err "$s: SKILL.md has $lines lines (limit 500)" ;;
    esac
  fi
done

corpus=evals/corpus.json
if ! jq empty "$corpus" 2>/dev/null; then
  err "corpus.json is not valid JSON"
else
  jq -e '[.evals[] | select((.id? and .feature? and .prompt? and .reference_test? and .judge?) | not)] | length == 0' \
    "$corpus" >/dev/null || err "corpus.json: eval missing required field (id/feature/prompt/reference_test/judge)"
  dups=$(jq -r '.evals[].id' "$corpus" | sort | uniq -d)
  [ -z "$dups" ] || err "corpus.json: duplicate ids: $dups"

  main_repo=${BSC_MAIN_REPO:-../BiShengCLanguage}
  if [ ! -d "$main_repo" ]; then
    err "main compiler repo not found at '$main_repo' (set BSC_MAIN_REPO); cannot verify reference_test paths"
  else
    while IFS= read -r p; do
      [ -f "$main_repo/$p" ] || err "corpus.json: reference_test does not exist: $p"
    done < <(jq -r '.evals[].reference_test' "$corpus")
  fi
fi

if [ "$fail" -eq 0 ]; then echo "lint: all checks passed"; else exit 1; fi
