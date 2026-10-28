#!/bin/sh
# Check every app and context, including checks outside the branch ruleset.
set -eu
case $# in 1|2) ;; *) echo "Usage: $0 <pr-number> [--dry-run]" >&2; exit 1 ;; esac
pr=$1
case "$pr" in ''|*[!0-9]*) echo 'PR number must be numeric.' >&2; exit 1 ;; esac
if [ "$#" = 2 ] && [ "$2" != --dry-run ]; then
    echo "Usage: $0 <pr-number> [--dry-run]" >&2; exit 1
fi
problems=0
problem() { printf '%s\n' "$1" >&2; problems=1; }
repo=$(gh repo view --json nameWithOwner --jq .nameWithOwner) || exit 1
metadata() {
    gh pr view "$pr" --repo "$repo" --json state,isDraft,baseRefName,headRefOid \
        --jq '[.state, (.isDraft|tostring), .baseRefName, .headRefOid] | join(" ")'
}
initial=$(metadata) || exit 1
read -r state draft base sha <<EOF_META
$initial
EOF_META
[ "$state" = OPEN ] || problem 'PR is not open.'
[ "$draft" = false ] || problem 'PR is a draft.'
[ "$base" = main ] || problem 'PR base is not main.'
case "$sha" in ''|*[!0-9a-fA-F]*) problem 'Head SHA must be 40 hexadecimal characters.' ;; esac
[ "${#sha}" = 40 ] || problem 'Head SHA must be 40 hexadecimal characters.'
[ "$problems" = 0 ] || exit 1
# filter=all includes reruns and every app. Deduplicate by app and name only
# after collecting every page; a green run from another app cannot hide a failure.
checks=$(gh api --paginate --slurp "repos/$repo/commits/$sha/check-runs?filter=all&per_page=100" --jq '
    [.[].check_runs[]] | group_by([.app.id, .name]) | map(max_by(.id)) |
    if length == 0 then "No check runs on head."
    else .[] | select(.status != "completed" or (.conclusion != "success" and .conclusion != "skipped")) |
    "Check \(.name): \(.status)/\(.conclusion // "pending")" end') || { problem 'Cannot read check runs.'; checks=; }
[ -z "$checks" ] || problem "$checks"
statuses=$(gh api --paginate --slurp "repos/$repo/commits/$sha/statuses?per_page=100" --jq '
    [ .[][] ] | group_by(.context) | map(max_by(.id)) | .[] |
    select(.state != "success") | "Status \(.context): \(.state)"') || { problem 'Cannot read commit statuses.'; statuses=; }
[ -z "$statuses" ] || problem "$statuses"
owner=${repo%/*}
name=${repo#*/}
threads=$(gh api graphql --paginate --slurp -f owner="$owner" -f name="$name" -F number="$pr" -f query='
    query($owner: String!, $name: String!, $number: Int!, $endCursor: String) {
      repository(owner: $owner, name: $name) {
        pullRequest(number: $number) {
          reviewThreads(first: 100, after: $endCursor) {
            nodes { isResolved comments(first: 1) { nodes { author { login } } } }
            pageInfo { hasNextPage endCursor }
          }
        }
      }
    }' --jq '
    .[].data.repository.pullRequest.reviewThreads.nodes[] |
    select(.isResolved == false and .comments.nodes[0].author.login == "chatgpt-codex-connector") |
    "Unresolved Codex review thread."') || { problem 'Cannot read review threads.'; threads=; }
[ -z "$threads" ] || problem "$threads"
# Recheck metadata as well as SHA immediately before the guarded merge.
final=$(metadata) || { problem 'Cannot recheck PR head.'; final=; }
[ "$initial" = "$final" ] || problem 'PR head or merge eligibility changed during checks.'
[ "$problems" = 0 ] || exit 1
if [ "${2:-}" = --dry-run ]; then
    printf 'All checks green for PR %s at %s (dry run).\n' "$pr" "$sha"
else
    gh pr merge "$pr" --repo "$repo" --squash --match-head-commit "$sha"
fi
