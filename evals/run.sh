#!/usr/bin/env bash
# run.sh — bare-model vs with-skills comparison runner for the BSC eval corpus.
#
# For every selected eval, runs `claude -p` in two arms:
#   bare  : empty project, --setting-sources project → no skills visible
#   skill : project with BiShengCSkills installed via install.sh -a claude
# each N times, writes the generated solution.cbs through evals/judge.sh, and
# aggregates pass rates, duration, tokens, and skill-trigger metrics.
#
# The generator is NOT allowed to run the compiler (Bash is disallowed): this
# measures one-shot generation quality, not an agentic repair loop.
#
# Usage:
#   evals/run.sh [--ids id1,id2,...] [--n N] [--out DIR] [--corpus FILE]
#
# Environment:
#   BSC_CLANG      (required) BiSheng C clang for judge.sh
#   EVAL_MODEL     model passed to claude -p (default: sonnet; pin for benchmarks)
#   EVAL_N         reps per eval per arm (default 3; --n wins)
#   EVAL_PARALLEL  concurrent generation jobs (default 4)
#   EVAL_TIMEOUT   per-run wall clock limit in seconds (default 600)
#   EVAL_MAX_TURNS max agent turns per run (default 25)
set -u

EVALS_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(dirname "$EVALS_DIR")

CORPUS=$EVALS_DIR/corpus.json
N=${EVAL_N:-3}
OUT=""
IDS=""
MODEL=${EVAL_MODEL:-sonnet}
PARALLEL=${EVAL_PARALLEL:-4}
TIMEOUT=${EVAL_TIMEOUT:-600}
MAX_TURNS=${EVAL_MAX_TURNS:-25}

while [ $# -gt 0 ]; do
  case "$1" in
    --ids)    IDS=$2; shift 2 ;;
    --n)      N=$2; shift 2 ;;
    --out)    OUT=$2; shift 2 ;;
    --corpus) CORPUS=$2; shift 2 ;;
    *) echo "run.sh: unknown arg $1" >&2; exit 64 ;;
  esac
done

for dep in jq claude; do
  command -v "$dep" >/dev/null 2>&1 || { echo "run.sh: missing dependency: $dep" >&2; exit 69; }
done
[ -n "${BSC_CLANG:-}" ] && [ -x "$BSC_CLANG" ] || { echo "run.sh: BSC_CLANG must point to a BiSheng C clang" >&2; exit 78; }
jq -e '.evals | length > 0' "$CORPUS" >/dev/null || { echo "run.sh: bad corpus: $CORPUS" >&2; exit 65; }

[ -n "$OUT" ] || OUT=$EVALS_DIR/results/$(date +%Y%m%d-%H%M%S)
mkdir -p "$OUT/records" "$OUT/runs"

if [ -n "$IDS" ]; then
  SELECTED=$(jq -r --arg ids "$IDS" '.evals[] | select(.id as $i | ($ids | split(",")) | index($i)) | .id' "$CORPUS")
else
  SELECTED=$(jq -r '.evals[].id' "$CORPUS")
fi
[ -n "$SELECTED" ] || { echo "run.sh: no evals selected (check --ids)" >&2; exit 65; }

# One shared with-skills project template.
SKILL_TMPL=$OUT/_skill_template
mkdir -p "$SKILL_TMPL"
( cd "$SKILL_TMPL" && bash "$REPO_ROOT/install.sh" -a claude </dev/null >/dev/null 2>&1 ) \
  || { echo "run.sh: install.sh -a claude failed" >&2; exit 70; }

WRITE_INSTR="请把最终的毕昇C代码写入当前目录下的 solution.cbs(单个文件、自包含、可直接编译)。不要运行编译器或任何命令,写完文件即可结束。"

# one_run <id> <arm> <rep>
one_run() {
  id=$1; arm=$2; rep=$3
  dir=$OUT/runs/$id/$arm/$rep
  rec=$OUT/records/${id}__${arm}__${rep}.json
  mkdir -p "$dir"

  prompt=$(jq -r --arg id "$id" '.evals[] | select(.id==$id) | .prompt' "$CORPUS")
  feature=$(jq -r --arg id "$id" '.evals[] | select(.id==$id) | .feature' "$CORPUS")
  expected=$(jq -c --arg id "$id" '.evals[] | select(.id==$id) | .expected_skills // []' "$CORPUS")

  if [ "$arm" = "skill" ]; then
    cp -R "$SKILL_TMPL/.claude" "$dir/.claude"
    cp "$SKILL_TMPL/CLAUDE.md" "$dir/CLAUDE.md"
  fi

  start=$(date +%s)
  ( cd "$dir" && claude -p "$prompt

$WRITE_INSTR" \
      --output-format stream-json --verbose \
      --setting-sources project \
      --allowedTools "Write Edit Read Glob Grep Skill" \
      --disallowedTools "Bash WebSearch WebFetch Task Agent" \
      --max-turns "$MAX_TURNS" \
      --model "$MODEL" \
      > events.jsonl 2> stderr.log ) &
  pid=$!
  ( sleep "$TIMEOUT" && kill -TERM "$pid" 2>/dev/null ) &
  watcher=$!
  wait "$pid" 2>/dev/null
  gen_rc=$?
  kill "$watcher" 2>/dev/null
  wait "$watcher" 2>/dev/null
  dur=$(( $(date +%s) - start ))

  # Skills invoked during the run (names normalised: strip plugin prefixes).
  triggered=$(jq -c -s '[ .[] | select(.type=="assistant") | .message.content[]?
      | select(.type=="tool_use" and .name=="Skill") | .input.skill
      | split(":") | last ] | unique' "$dir/events.jsonl" 2>/dev/null || echo '[]')
  usage=$(jq -c -s '[ .[] | select(.type=="result") ] | last
      | {output_tokens: (.usage.output_tokens // null),
         input_tokens: (.usage.input_tokens // null),
         cost_usd: (.total_cost_usd // null),
         num_turns: (.num_turns // null)}' "$dir/events.jsonl" 2>/dev/null || echo '{}')

  if [ -f "$dir/solution.cbs" ] && "$EVALS_DIR/judge.sh" "$dir/solution.cbs" \
        > "$dir/judge.log" 2>&1; then
    pass=true
  else
    pass=false
  fi

  jq -n -c \
    --arg id "$id" --arg feature "$feature" --arg arm "$arm" \
    --argjson rep "$rep" --argjson pass "$pass" --argjson dur "$dur" \
    --argjson gen_rc "$gen_rc" --argjson triggered "$triggered" \
    --argjson expected "$expected" --argjson usage "$usage" \
    '{id:$id, feature:$feature, arm:$arm, rep:$rep, pass:$pass,
      duration_s:$dur, gen_exit:$gen_rc,
      skills_triggered:$triggered, expected_skills:$expected,
      expected_hit: ([$triggered[] | select(. as $t | $expected | index($t))] | length > 0),
      usage:$usage}' > "$rec"
  echo "[$id/$arm/$rep] pass=$pass dur=${dur}s skills=$triggered" >&2
}

# Fan out with a simple slot limiter.
for id in $SELECTED; do
  for arm in bare skill; do
    rep=1
    while [ "$rep" -le "$N" ]; do
      while [ "$(jobs -pr | wc -l)" -ge "$PARALLEL" ]; do sleep 2; done
      one_run "$id" "$arm" "$rep" &
      rep=$((rep + 1))
    done
  done
done
wait

cat "$OUT"/records/*.json > "$OUT/runs.jsonl"

# ---------- aggregation ----------
jq -s '
  def mean: if length == 0 then null else add / length end;
  def stddev: if length < 2 then 0 else (mean as $m | (map((. - $m) * (. - $m)) | add / length) | sqrt) end;

  group_by(.id) | map({
    id: .[0].id, feature: .[0].feature,
    expected_skills: .[0].expected_skills,
    arms: (group_by(.arm) | map({
      key: .[0].arm,
      value: {
        n: length,
        pass: (map(select(.pass)) | length),
        pass_rate: ((map(select(.pass)) | length) / length),
        mean_duration_s: (map(.duration_s) | mean),
        mean_output_tokens: (map(.usage.output_tokens | select(. != null)) | mean),
        skills_triggered: (map(.skills_triggered[]) | unique),
        expected_hit_rate: ((map(select(.expected_hit)) | length) / length)
      }
    }) | from_entries)
  }) as $per_eval
  | {
      per_eval: $per_eval,
      overall: (["bare", "skill"] | map({
        key: .,
        value: (. as $arm | ($per_eval | map(.arms[$arm] | select(. != null))) | {
          evals: length,
          mean_pass_rate: (map(.pass_rate) | mean),
          stddev_pass_rate: (map(.pass_rate) | stddev),
          mean_duration_s: (map(.mean_duration_s | select(. != null)) | mean),
          mean_output_tokens: (map(.mean_output_tokens | select(. != null)) | mean),
          expected_hit_rate: (map(.expected_hit_rate) | mean)
        })
      }) | from_entries)
    }
' "$OUT/runs.jsonl" > "$OUT/results.json"

# Config block merged in afterwards (kept out of the big jq for readability).
jq --arg model "$MODEL" --argjson n "$N" --arg corpus "$CORPUS" \
   --argjson timeout "$TIMEOUT" --argjson max_turns "$MAX_TURNS" \
   '. + {config: {model:$model, n_per_arm:$n, corpus:$corpus,
                  timeout_s:$timeout, max_turns:$max_turns,
                  judge: "compile (evals/judge.sh, -fsyntax-only)",
                  bash_disallowed: true}}' \
   "$OUT/results.json" > "$OUT/results.tmp" && mv "$OUT/results.tmp" "$OUT/results.json"

# ---------- markdown table ----------
{
  echo "# BSC eval results"
  echo
  jq -r '"Model: `\(.config.model)` · N=\(.config.n_per_arm) per arm · judge: \(.config.judge)"' "$OUT/results.json"
  echo
  echo "| eval | feature | bare pass | skill pass | Δ | expected skills | triggered (skill arm) | hit |"
  echo "|---|---|---|---|---|---|---|---|"
  jq -r '.per_eval[] |
    "| \(.id) | \(.feature) | \(.arms.bare.pass)/\(.arms.bare.n) | \(.arms.skill.pass)/\(.arms.skill.n) | \((.arms.skill.pass_rate - .arms.bare.pass_rate) * 100 | round)pp | \(.expected_skills | join(", ")) | \(.arms.skill.skills_triggered | join(", ")) | \(.arms.skill.expected_hit_rate * 100 | round)% |"' \
    "$OUT/results.json"
  echo
  jq -r '.overall | "**Overall**: bare \((.bare.mean_pass_rate * 100) | round)% ± \((.bare.stddev_pass_rate * 100) | round)pp · skill \((.skill.mean_pass_rate * 100) | round)% ± \((.skill.stddev_pass_rate * 100) | round)pp · skill-trigger hit rate \((.skill.expected_hit_rate * 100) | round)%"' \
    "$OUT/results.json"
} > "$OUT/results.md"

echo "results: $OUT/results.json" >&2
echo "table:   $OUT/results.md" >&2
