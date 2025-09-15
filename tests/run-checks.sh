#!/usr/bin/env bash
# Check harness for this Neovim configuration.
#
# Offline groups, in order:
#   syntax   — every tracked Lua file must compile under loadfile().
#   core     — the plugin-free modules (options, filetype, keymaps) must
#              load into a clean instance without producing any output.
#   ftplugin — every after/ftplugin file must apply cleanly to
#              a buffer of its filetype.
#
# Environment:
#   NVIM_BIN   Neovim executable to check against (default: nvim).
set -euo pipefail

NVIM_BIN=${NVIM_BIN:-nvim}
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$REPO_ROOT"

fail=0
group() { printf '\n=== %s ===\n' "$*"; }

run_quiet() {
    # Run Neovim headless; any output at all counts as a failure of
    # the calling group, so capture everything for the caller to inspect.
    "$NVIM_BIN" --headless "$@" +quitall 2>&1
}

group "syntax ($("$NVIM_BIN" --version | head -n1))"
checker=$(mktemp)
trap 'rm -f "$checker"' EXIT
cat >"$checker" <<'EOF'
local ok = true
for _, file in ipairs(_G.arg) do
    local chunk, err = loadfile(file)
    if chunk then
        io.write("ok: ", file, "\n")
    else
        io.stderr:write("FAIL: ", tostring(err), "\n")
        ok = false
    end
end
os.exit(ok and 0 or 1)
EOF
if ! git ls-files -z -- '*.lua' \
    | xargs -0 "$NVIM_BIN" --headless -u NONE -l "$checker"; then
    fail=1
fi

group "core: plugin-free module load"
out=$(run_quiet --clean \
    --cmd "set runtimepath+=$REPO_ROOT" \
    --cmd "lua for _, m in ipairs({ 'options', 'filetype', 'keymaps' }) do require('thekpaul.' .. m) end")
if [ -n "$out" ]; then
    printf 'FAIL: core modules produced output:\n%s\n' "$out"
    fail=1
else
    echo "ok: thekpaul.{options,filetype,keymaps}"
fi

group "ftplugin: apply each filetype profile"
for f in after/ftplugin/*.lua; do
    ft=$(basename "$f" .lua)
    out=$(run_quiet --clean \
        --cmd "set runtimepath+=$REPO_ROOT,$REPO_ROOT/after" \
        --cmd "filetype plugin on" \
        "+setfiletype $ft")
    if [ -n "$out" ]; then
        printf 'FAIL: %s produced output:\n%s\n' "$f" "$out"
        fail=1
    else
        echo "ok: $f"
    fi
done

if [ "$fail" -ne 0 ]; then
    echo
    echo "Checks FAILED."
    exit 1
fi
echo
echo "All checks passed."
