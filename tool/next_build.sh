#!/bin/bash
# (02-11-2026) THE NEXT BUILD NUMBER of the app – used by release.yml and beta.yml (one at a time: their concurrency group "release").
# One more than the highest of ALL the releases of this repository (beta and stable, the versions of the web only too), and never
# lower than 100 + this run's number (the numbering of before). Android installs an update only when its number is higher.
#   needs GH_TOKEN and GITHUB_REPOSITORY (the build machine's); prints the number
set -euo pipefail
MAX=$(gh api "repos/$GITHUB_REPOSITORY/releases?per_page=100" --paginate --jq '.[].tag_name' | sed -n 's/^v.*-\([0-9][0-9]*\)$/\1/p' | sort -n | tail -1)
N=$(( ${MAX:-0} + 1 )); M=$(( 100 + ${GITHUB_RUN_NUMBER:-0} ))
echo $(( N > M ? N : M ))
