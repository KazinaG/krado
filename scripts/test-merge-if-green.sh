#!/bin/sh
# Offline API fixtures; jq evaluates the production gh --jq expressions.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' 0
trap 'exit 1' HUP INT TERM
cat > "$work/gh" <<'STUB'
#!/bin/sh
set -eu
command=$1
shift
endpoint=
if [ "$command" = api ]; then
    for arg do
        case "$arg" in repos/*|graphql) endpoint=$arg ;; esac
    done
fi
filter=
previous=
slurp=false
formatted=false
for arg do
    if [ "$previous" = --jq ]; then filter=$arg; fi
    case "$arg" in
        --slurp) slurp=true ;;
        --jq|--template) formatted=true ;;
    esac
    previous=$arg
done
if [ "$slurp" = true ] && [ "$formatted" = true ]; then
    echo 'the `--slurp` option is not supported with `--jq` or `--template`' >&2
    exit 1
fi
case "$command:$*" in
    repo:*) printf 'test/repo\n'; exit ;;
    'pr:merge '*) printf '%s\n' "$*" > "$MERGE_LOG"; exit ;;
    'pr:view '*)
        draft=false
        [ "$SCENARIO" != draft ] || draft=true
        sha=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
        if [ "$SCENARIO" = changed ]; then
            if [ -f "$CALL_LOG" ]; then sha=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb; fi
            : > "$CALL_LOG"
        fi
        printf 'OPEN %s main %s\n' "$draft" "$sha"; exit ;;
esac
case "$endpoint" in
    */check-runs*)
        conclusion=success
        status=completed
        case "$SCENARIO" in
            failure) conclusion=failure ;;
            neutral) conclusion=neutral ;;
            pending) conclusion=null; status=in_progress ;;
            skipped) conclusion=skipped ;;
        esac
        if [ "$conclusion" = null ]; then value=null; else value="\"$conclusion\""; fi
        # Two pages: rerun supersedes failure, separate app cannot mask failure.
        data='[{"check_runs":[{"id":1,"app":{"id":1},"name":"tests","status":"completed","conclusion":"failure"}]},{"check_runs":[{"id":2,"app":{"id":1},"name":"tests","status":"completed","conclusion":"success"},{"id":3,"app":{"id":2},"name":"Gatekeeper","status":"'"$status"'","conclusion":'"$value"'}]}]'
        case "$SCENARIO" in
            newer-success|newer-failure)
                newest=success
                [ "$SCENARIO" != newer-failure ] || newest=failure
                data='[{"check_runs":[{"id":9,"app":{"id":1},"name":"tests","status":"completed","conclusion":"'"$newest"'"}]},{"check_runs":[{"id":1,"app":{"id":1},"name":"tests","status":"completed","conclusion":"failure"}]}]'
                ;;
        esac
        [ "$SCENARIO" != empty ] || data='[{"check_runs":[]}]'
        [ "$SCENARIO" != api-error ] || exit 1
        ;;
    */statuses*)
        value=success
        [ "$SCENARIO" != bad-status ] || value=pending
        data='[[{"id":1,"context":"codex-verdict","state":"failure"}],[{"id":2,"context":"codex-verdict","state":"'"$value"'"}]]'
        ;;
    graphql)
        resolved=true
        [ "$SCENARIO" != codex ] || resolved=false
        data='[{"data":{"repository":{"pullRequest":{"reviewThreads":{"nodes":[]}}}}},{"data":{"repository":{"pullRequest":{"reviewThreads":{"nodes":[{"isResolved":'"$resolved"',"comments":{"nodes":[{"author":{"login":"chatgpt-codex-connector"}}]}}]}}}}}]'
        ;;
    *) echo 'Unexpected gh invocation' >&2; exit 1 ;;
esac
printf '%s\n' "$data" | jq -r ".[] | ($filter)"
STUB
chmod +x "$work/gh"
PATH="$work:$PATH"
export PATH
MERGE_LOG="$work/merge"
CALL_LOG="$work/calls"
export MERGE_LOG CALL_LOG
# Keep the stub's incompatible-option guard covered independently of production.
for format in --jq --template; do
    result=0
    gh api --paginate --slurp repos/test/repo/statuses "$format" . > "$work/output" 2>&1 || result=$?
    [ "$result" = 1 ]
    expected='the `--slurp` option is not supported with `--jq` or `--template`'
    [ "$(cat "$work/output")" = "$expected" ]
    printf 'PASS incompatible-options %s\n' "$format"
done
for SCENARIO in green skipped newer-success newer-failure failure neutral pending codex draft empty bad-status changed api-error; do
    export SCENARIO
    rm -f "$MERGE_LOG" "$CALL_LOG"
    result=0
    sh "$root/scripts/merge-if-green.sh" 42 > "$work/output" 2>&1 || result=$?
    case "$SCENARIO" in
        green|skipped|newer-success)
            [ "$result" = 0 ] && [ -s "$MERGE_LOG" ] || { cat "$work/output"; exit 1; }
            expected='merge 42 --repo test/repo --squash --match-head-commit aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
            [ "$(cat "$MERGE_LOG")" = "$expected" ] || exit 1 ;;
        *) [ "$result" = 1 ] && [ ! -f "$MERGE_LOG" ] || { cat "$work/output"; exit 1; } ;;
    esac
    printf 'PASS %s\n' "$SCENARIO"
done
SCENARIO=green
export SCENARIO
rm -f "$MERGE_LOG"
sh "$root/scripts/merge-if-green.sh" 42 --dry-run > "$work/output"
[ ! -f "$MERGE_LOG" ]
printf 'PASS dry-run\n'
