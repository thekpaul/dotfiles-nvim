#!/usr/bin/env bash
# Check harness for this Neovim configuration.
#
# Offline groups, in order:
#   syntax   — every tracked Lua file must compile under loadfile().
#   core     — the plugin-free modules (options, filetype, keymaps) must
#              load into a clean instance without producing any output.
#   vscode   — the same load with the VS Code gate raised must stay silent
#              where the extension's own Lua module is absent.
#   ftplugin — every after/ftplugin file must apply cleanly to
#              a buffer of its filetype.
#
# Gated group (network access, several minutes on a cold run):
#   startup  — the tracked tree is copied into a throwaway HOME/XDG sandbox,
#              every plugin is installed from scratch,
#              a subsequent boot must be completely silent, and
#              a plain headless boot must restore a deleted parser
#              (the contract the background installer relies on).
#              Enabled by NVIM_CHECK_FULL=1, or automatically under CI.
#
# Environment:
#   NVIM_BIN         Neovim executable to check against (default: nvim).
#   NVIM_CHECK_FULL  Set to 1 to enable the sandboxed startup group.
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

group "vscode: simulated embedded load"
out=$(run_quiet --clean \
    --cmd "set runtimepath+=$REPO_ROOT" \
    --cmd "lua vim.g.vscode = 1" \
    --cmd "lua for _, m in ipairs({ 'options', 'filetype', 'keymaps', 'vscode' }) do require('thekpaul.' .. m) end")
if [ -n "$out" ]; then
    printf 'FAIL: simulated VS Code load produced output:\n%s\n' "$out"
    fail=1
else
    echo "ok: thekpaul.vscode no-ops without the extension module"
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

group "startup: sandboxed full boot"
if [ "${NVIM_CHECK_FULL:-0}" = "1" ] || [ -n "${CI:-}" ]; then
    sandbox=$(mktemp -d)
    mkdir -p "$sandbox/config/nvim" "$sandbox/data" "$sandbox/state" \
        "$sandbox/cache"
    git ls-files -z | tar --null --files-from=- -cf - \
        | tar -C "$sandbox/config/nvim" -xf -
    sandboxed() {
        env -i HOME="$sandbox" PATH="$PATH" TERM=dumb \
            XDG_CONFIG_HOME="$sandbox/config" \
            XDG_DATA_HOME="$sandbox/data" \
            XDG_STATE_HOME="$sandbox/state" \
            XDG_CACHE_HOME="$sandbox/cache" \
            "$NVIM_BIN" --headless "$@" +quitall
    }
    # First boot: bootstrap lazy.nvim and install every plugin from cold cache;
    # only the exit status matters.
    if ! sandboxed "+Lazy! install" >"$sandbox/install.log" 2>&1; then
        printf 'FAIL: plugin installation boot\n'
        tail -n 20 "$sandbox/install.log"
        fail=1
    else
        # The install boot's `:TSUpdate` build hook asynchronously queues
        # parser compiles and can exit before they finish;
        # force-sync the parser set so the silent boot
        # cannot race a half-compiled parser (`!` keeps the run promptless).
        # The list mirrors `./lua/plugins/treesitter.lua`, which
        # skips parser installs when no C compiler is present — also mirrored.
        parsers_ok=1
        have_cc=0
        if command -v cc >/dev/null 2>&1 \
            || command -v gcc >/dev/null 2>&1 \
            || command -v clang >/dev/null 2>&1; then
            have_cc=1
            parsers="bash c cpp fish git_rebase gitcommit gitignore lua"
            parsers="$parsers markdown markdown_inline nu python vim"
            parsers="$parsers vimdoc yaml"
            if ! sandboxed "+TSInstallSync! $parsers" \
                >"$sandbox/parsers.log" 2>&1; then
                printf 'FAIL: synchronous parser install\n'
                tail -n 20 "$sandbox/parsers.log"
                fail=1
                parsers_ok=0
            fi
        fi
        if [ "$parsers_ok" -eq 1 ]; then
            out=$(sandboxed 2>&1)
            if [ -n "$out" ]; then
                printf 'FAIL: full startup produced output:\n%s\n' "$out"
                fail=1
            else
                echo "ok: silent full startup after cold install"
            fi
            # Same boot with the VS Code gate raised:
            # gated-out plugins must stay as silent as the full set.
            out=$(sandboxed --cmd "lua vim.g.vscode = 1" 2>&1)
            if [ -n "$out" ]; then
                printf 'FAIL: VS Code-gated startup produced output:\n%s\n' \
                    "$out"
                fail=1
            else
                echo "ok: silent startup with VS Code gating active"
            fi
            if [ "$have_cc" -eq 1 ]; then
                # The background-installer contract: interactive boots
                # delegate parser compiles to a detached headless instance, so
                # a plain headless boot must notice a missing parser and
                # restore it synchronously before exiting.
                # Installer output is expected on that boot;
                # only the restored parser is asserted.
                # Runs last so the silent-boot checks above see a settled tree.
                gi="$sandbox/data/nvim/lazy/nvim-treesitter/parser"
                gi="$gi/gitignore.so"
                rm -f "$gi"
                if sandboxed >"$sandbox/reinstall.log" 2>&1 \
                    && [ -f "$gi" ]; then
                    echo "ok: headless boot restored a deleted parser"
                else
                    printf 'FAIL: headless boot did not restore %s\n' \
                        "$gi"
                    tail -n 10 "$sandbox/reinstall.log"
                    fail=1
                fi
            fi
        fi
    fi
    rm -rf "$sandbox"
else
    echo "skipped (set NVIM_CHECK_FULL=1 to enable)"
fi

if [ "$fail" -ne 0 ]; then
    echo
    echo "Checks FAILED."
    exit 1
fi
echo
echo "All checks passed."
