#!/bin/bash
# Build a standalone bash-prompts.sh from lib/bash-prompts.sh and its modules.
# Usage: bash scripts/bundle.sh [--output path]
# Defaults to dist/bash-prompts.sh under the repository root. The module
# inclusion order is read from the entry file, so it stays single-sourced.

set -u
export LC_ALL=C

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P) || exit 1
OUT=$ROOT/dist/bash-prompts.sh
while (($#)); do
    case $1 in
        --output) shift; OUT=${1-}; [[ -n $OUT ]] || { printf 'bundle: --output needs a path\n' >&2; exit 2; } ;;
        --output=*) OUT=${1#--output=} ;;
        -h|--help) printf 'Usage: %s [--output path]\n' "$0"; exit 0 ;;
        *) printf 'bundle: unknown argument %s\n' "$1" >&2; exit 2 ;;
    esac
    shift
done

ENTRY=$ROOT/lib/bash-prompts.sh
MODULE_DIR=$ROOT/lib/bash-prompts

mkdir -p "$(dirname -- "$OUT")" || exit 1
tmp=$OUT.tmp
rm -f "$tmp"
trap 'rm -f "$tmp"' EXIT

{
    printf '# Generated from lib/bash-prompts.sh and lib/bash-prompts/; do not edit.\n'
    printf '# Sources: https://github.com/undervoke/bash-prompts (MIT).\n'
    prefix='source "$_BASH_PROMPTS_DIR/bash-prompts/'
    suffix='" || return 1'
    while IFS= read -r line; do
        # Tolerate ordinary indentation and trailing whitespace, so
        # reformatting the entry cannot silently leave a runtime
        # sibling-file dependency in the bundle.
        trimmed=${line#"${line%%[! 	]*}"}
        trimmed=${trimmed%"${trimmed##*[! 	]}"}
        case $trimmed in
            "$prefix"*"$suffix")
                mod=${trimmed#"$prefix"}
                mod=${mod%"$suffix"}
                cat "$MODULE_DIR/$mod" || exit 1
                ;;
            *) printf '%s\n' "$line" ;;
        esac
    done < "$ENTRY"
} > "$tmp" || exit 1

trap - EXIT
mv -f "$tmp" "$OUT" || exit 1
printf '%s\n' "$OUT"
