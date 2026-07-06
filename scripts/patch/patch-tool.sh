#!/usr/bin/env bash
# Git plumbing for regenerating BSP patches (u-boot/kernel/...) from a real
# source tree, so patch files are never hand-edited. See AGENTS.md.

set -euo pipefail

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

note() {
    printf '%s\n' "$*"
}

usage() {
    cat << 'EOF'
Usage: patch-tool.sh <command> [options]

Commands:
  check    --tree <path> --diff <file>
  apply    --tree <path> --diff <file> --message <file> --author "Name <email>"
  reword   --tree <path> --commit <sha> --message <file> [--base <ref>]
  finalize --tree <path> --out <dir> --names "0001-foo.patch 0002-bar.patch" [--base <ref>]
  abort    --tree <path>

Two ways to build a series, tracked via marker files inside the tree's
.git dir - don't mix them in the same series:

- apply: the code doesn't exist yet as a commit. Applies a real diff file
  and commits it for real (moves the tree's HEAD and working dir). Call
  once per patch. finalize/abort will `git reset --hard` the tree back to
  where it started.
- reword: the code already exists as a commit in the tree (e.g. a past
  build left one with a correct diff but a garbled message). Rebuilds
  that commit with a corrected message via `git commit-tree`, using the
  exact same tree (no diff, no re-apply) - pure plumbing that never
  touches the tree's real HEAD or working dir. The first call needs
  --base (the parent to build on, e.g. the commit before the one you're
  rewording). finalize/abort will NOT touch the tree at all in this mode.

finalize emits the series as patch files and cleans up either way. abort
discards an in-progress series instead of finalizing it.

If commits were made by hand instead of via apply (no marker exists), pass
--base explicitly to finalize, e.g. --base HEAD~1 for a single hand-made
commit, or --base HEAD~2 for two.
EOF
}

require_tree() {
    local tree="$1"
    [ -n "$tree" ] || die "--tree is required"
    git -C "$tree" rev-parse --git-dir > /dev/null 2>&1 || die "not a git tree: $tree"
}

base_marker_path() {
    printf '%s/PATCHTOOL_BASE' "$(git -C "$1" rev-parse --git-dir)"
}

tip_marker_path() {
    printf '%s/PATCHTOOL_TIP' "$(git -C "$1" rev-parse --git-dir)"
}

cmd_check() {
    local tree="" diff=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --tree)
                tree="$2"
                shift 2
                ;;
            --diff)
                diff="$2"
                shift 2
                ;;
            *) die "unknown option: $1" ;;
        esac
    done
    require_tree "$tree"
    if [ -z "$diff" ] || [ ! -f "$diff" ]; then
        die "--diff <file> is required"
    fi

    if git -C "$tree" apply --check "$diff"; then
        note "check: OK - $diff applies cleanly to $tree"
    else
        die "check: FAILED - $diff does not apply to $tree"
    fi
}

cmd_apply() {
    local tree="" diff="" message="" author=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --tree)
                tree="$2"
                shift 2
                ;;
            --diff)
                diff="$2"
                shift 2
                ;;
            --message)
                message="$2"
                shift 2
                ;;
            --author)
                author="$2"
                shift 2
                ;;
            *) die "unknown option: $1" ;;
        esac
    done
    require_tree "$tree"
    if [ -z "$diff" ] || [ ! -f "$diff" ]; then
        die "--diff <file> is required"
    fi
    if [ -z "$message" ] || [ ! -f "$message" ]; then
        die "--message <file> is required"
    fi
    [ -n "$author" ] || die '--author "Name <email>" is required'
    [ -f "$(tip_marker_path "$tree")" ] &&
        die "a 'reword' series is already in progress for $tree; finish it or run patch-abort first"

    local name email marker
    name="${author%% <*}"
    email="${author#*<}"
    email="${email%>*}"
    if [ -z "$name" ] || [ -z "$email" ] || [ "$email" = "$author" ]; then
        die 'author must look like "Name <email>"'
    fi

    git -C "$tree" config user.name "$name"
    git -C "$tree" config user.email "$email"

    marker="$(base_marker_path "$tree")"
    if [ ! -f "$marker" ]; then
        git -C "$tree" rev-parse HEAD > "$marker"
        note "apply: started new series, base=$(cat "$marker")"
    fi

    git -C "$tree" apply "$diff"
    git -C "$tree" add -A
    git -C "$tree" commit --quiet -F "$message" --author="$author"
    note "apply: committed $(git -C "$tree" rev-parse --short HEAD) from $diff"
}

cmd_reword() {
    local tree="" commit="" message="" base=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --tree)
                tree="$2"
                shift 2
                ;;
            --commit)
                commit="$2"
                shift 2
                ;;
            --message)
                message="$2"
                shift 2
                ;;
            --base)
                base="$2"
                shift 2
                ;;
            *) die "unknown option: $1" ;;
        esac
    done
    require_tree "$tree"
    [ -n "$commit" ] || die "--commit <sha> is required"
    if [ -z "$message" ] || [ ! -f "$message" ]; then
        die "--message <file> is required"
    fi

    local base_marker tip_marker parent src_tree new_sha
    base_marker="$(base_marker_path "$tree")"
    tip_marker="$(tip_marker_path "$tree")"

    if [ -f "$tip_marker" ]; then
        parent="$(cat "$tip_marker")"
    elif [ -f "$base_marker" ]; then
        die "an 'apply' series is already in progress for $tree; finish it or run patch-abort first"
    else
        [ -n "$base" ] || die "--base <ref> is required for the first reword call in a series"
        parent="$(git -C "$tree" rev-parse "$base")"
        printf '%s\n' "$parent" > "$base_marker"
        note "reword: started new series, base=$parent"
    fi

    src_tree="$(git -C "$tree" show -s --format=%T "$commit")"
    new_sha="$(git -C "$tree" commit-tree "$src_tree" -p "$parent" -F "$message")"
    printf '%s\n' "$new_sha" > "$tip_marker"
    note "reword: $commit -> $new_sha"
}

cmd_finalize() {
    local tree="" out="" names="" base_flag=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --tree)
                tree="$2"
                shift 2
                ;;
            --out)
                out="$2"
                shift 2
                ;;
            --names)
                names="$2"
                shift 2
                ;;
            --base)
                base_flag="$2"
                shift 2
                ;;
            *) die "unknown option: $1" ;;
        esac
    done
    require_tree "$tree"
    [ -n "$out" ] || die "--out <dir> is required"
    [ -n "$names" ] || die '--names "a.patch b.patch" is required'

    local base_marker tip_marker base tip mode count tmpdir
    base_marker="$(base_marker_path "$tree")"
    tip_marker="$(tip_marker_path "$tree")"

    if [ -n "$base_flag" ]; then
        base="$(git -C "$tree" rev-parse "$base_flag")"
        tip="$(git -C "$tree" rev-parse HEAD)"
        mode="apply"
    elif [ -f "$tip_marker" ]; then
        base="$(git -C "$tree" rev-parse "$(cat "$base_marker")")"
        tip="$(cat "$tip_marker")"
        mode="reword"
    elif [ -f "$base_marker" ]; then
        base="$(git -C "$tree" rev-parse "$(cat "$base_marker")")"
        tip="$(git -C "$tree" rev-parse HEAD)"
        mode="apply"
    else
        die "no in-progress series for $tree and no --base given; use patch-apply/patch-reword first, or pass --base <ref> (e.g. HEAD~1) if you committed by hand"
    fi

    read -r -a name_list <<< "$names"
    count="$(git -C "$tree" rev-list --count "$base..$tip")"
    [ "$count" -eq "${#name_list[@]}" ] ||
        die "series has $count commit(s) but ${#name_list[@]} --names given"

    mkdir -p "$out"
    tmpdir="$(mktemp -d)"
    trap 'rm -rf "$tmpdir"' RETURN

    git -C "$tree" format-patch "$base".."$tip" --zero-commit -o "$tmpdir" > /dev/null

    local i=0 f
    for f in "$tmpdir"/*.patch; do
        cp "$f" "$out/${name_list[$i]}"
        note "finalize: wrote $out/${name_list[$i]}"
        i=$((i + 1))
    done

    if [ "$mode" = "apply" ]; then
        git -C "$tree" reset --hard "$base" > /dev/null
        note "finalize: reset $tree back to $base"
    else
        note "finalize: reword series done, $tree was never modified"
    fi
    rm -f "$base_marker" "$tip_marker"
}

cmd_abort() {
    local tree=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --tree)
                tree="$2"
                shift 2
                ;;
            *) die "unknown option: $1" ;;
        esac
    done
    require_tree "$tree"

    local base_marker tip_marker base
    base_marker="$(base_marker_path "$tree")"
    tip_marker="$(tip_marker_path "$tree")"

    if [ -f "$tip_marker" ]; then
        rm -f "$base_marker" "$tip_marker"
        note "abort: discarded in-progress reword series for $tree ($tree was never modified)"
    elif [ -f "$base_marker" ]; then
        base="$(cat "$base_marker")"
        git -C "$tree" reset --hard "$base" > /dev/null
        rm -f "$base_marker"
        note "abort: reset $tree back to $base"
    else
        die "nothing to abort for $tree"
    fi
}

[ $# -ge 1 ] || {
    usage
    exit 1
}
cmd="$1"
shift
case "$cmd" in
    check) cmd_check "$@" ;;
    apply) cmd_apply "$@" ;;
    reword) cmd_reword "$@" ;;
    finalize) cmd_finalize "$@" ;;
    abort) cmd_abort "$@" ;;
    -h | --help) usage ;;
    *)
        usage
        die "unknown command: $cmd"
        ;;
esac
