#!/usr/bin/env bash
# Runs tests/config/shell.qml against the real config/Config.qml in a throwaway
# Quickshell instance with an isolated XDG_CONFIG_HOME. Usage: tests/config.sh
set -u
repo=$(cd "$(dirname "$0")/.." && pwd)
fail=0

run() { # <case> [user file content]
    local tmp; tmp=$(mktemp -d)
    mkdir -p "$tmp/shell" "$tmp/cfg"
    ln -s "$repo/config" "$tmp/shell/config"
    ln -s "$repo/settings.default.json" "$tmp/shell/settings.default.json"
    ln -s "$repo/tests/config/shell.qml" "$tmp/shell/shell.qml"
    if [ $# -ge 2 ]; then mkdir -p "$tmp/cfg/myshell"; printf '%s' "$2" > "$tmp/cfg/myshell/settings.json"; fi
    local out; out=$(TEST_MODE="$1" XDG_CONFIG_HOME="$tmp/cfg" timeout 20 qs -p "$tmp/shell" --no-duplicate 2>&1 | grep -E "PASS|FAIL" | sed 's/.*\(PASS\|FAIL\)/\1/')
    [ -z "$out" ] && out="FAIL $1: no result"
    if [ "$1" = early-set ] && [[ $out == PASS* ]]; then
        local disk; disk=$(tr -d ' \n' < "$tmp/cfg/myshell/settings.json")
        if [[ $disk != *'"palette":"mine"'* || $disk != *'"left":["clock"]'* || $disk != *'"dryRun":true'* ]]; then
            out="FAIL early-set: disk has $disk"
        fi
    fi
    echo "$out"
    [[ $out == PASS* ]] || fail=1
    rm -rf "$tmp"
}

run early-set '{"palette":"mine","bar":{"left":["clock"]}}'
run missing-quiet
exit $fail
