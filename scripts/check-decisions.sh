#!/usr/bin/env bash
# Decision-record consistency check (PR_PROCESS.md, "Required checks").
# Every decisions/NNNN-*.md file has a unique ID, a matching "# ADR NNNN"
# title, and a linked row in decisions/README.md.
set -euo pipefail
cd "$(dirname "$0")/.."

status=0
fail() { echo "::error file=$1::$2"; status=1; }

dupes=$(ls decisions/[0-9][0-9][0-9][0-9]-*.md | sed 's#decisions/\([0-9]*\)-.*#\1#' | sort | uniq -d)
for id in $dupes; do
  fail "decisions/README.md" "ADR $id is used by more than one file: $(ls decisions/"$id"-*.md | xargs)"
done

for file in decisions/[0-9][0-9][0-9][0-9]-*.md; do
  name=${file#decisions/}
  id=${name%%-*}
  title=$(head -n 1 "$file")
  [[ $title == "# ADR $id:"* ]] ||
    fail "$file" "first line should start with '# ADR $id:', found '$title'"
  grep -Fq "| [$id]($name) |" decisions/README.md ||
    fail "decisions/README.md" "no index row links ADR $id as [$id]($name)"
done

exit $status
