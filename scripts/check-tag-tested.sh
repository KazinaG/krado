#!/bin/sh
# Release gate for a tag: the tagged commit must be on main, must have come from a merged pull
# request, must have the same tree as that pull request's head, and that head must have passed
# the CI checks (changelog, tests) from GitHub Actions. Then the Release workflow need not re-run
# the tests. Usage: scripts/check-tag-tested.sh OWNER/REPO SHA   (needs gh and GH_TOKEN)
set -eu
repo=$1
sha=$2
fail() { echo "::error::$*" >&2; exit 1; }

# 1. On main: main is the same as, or ahead of, the tagged commit.
rel=$(gh api "repos/$repo/compare/$sha...main" --jq .status)
case "$rel" in
    identical | ahead) echo "Tag commit ${sha} is on main ($rel)." ;;
    *) fail "Tag commit $sha is not on main (compare status: $rel). Tag only main commits." ;;
esac

# 2. The pull request that merged it into main.
head=$(gh api "repos/$repo/commits/$sha/pulls" \
    --jq "[.[] | select(.merged_at != null and .base.ref == \"main\" and .merge_commit_sha == \"$sha\") | .head.sha][0] // empty")
[ -n "$head" ] || fail "No merged pull request into main has merge commit $sha."
echo "Merged from pull request head $head."

# 3. Same tree as the tested head (true for squash merges of up-to-date branches).
t_main=$(gh api "repos/$repo/git/commits/$sha" --jq .tree.sha)
t_head=$(gh api "repos/$repo/git/commits/$head" --jq .tree.sha)
[ "$t_main" = "$t_head" ] || fail "Tree of $sha ($t_main) differs from the tested head $head ($t_head)."
echo "Tree $t_main is the same as the tested head."

# 4. The latest changelog and tests check runs from GitHub Actions on that head succeeded.
for name in changelog tests; do
    c=$(gh api "repos/$repo/commits/$head/check-runs?check_name=$name&filter=latest&per_page=100" \
        --jq '[.check_runs[] | select(.app.slug == "github-actions")] | sort_by(.completed_at) | last | .conclusion // empty')
    [ "$c" = success ] || fail "Check $name on $head is '${c:-missing}', not success."
    echo "Check $name on $head: success."
done
