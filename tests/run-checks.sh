#!/usr/bin/env bash
# Check harness for this Neovim configuration.
#
# Offline groups, in order:
#   syntax   — every tracked Lua file must compile under loadfile().
#   core     — the plugin-free modules (options, filetype, keymaps,
#              format) must load into a clean instance without producing
#              any output.
#   vscode   — the same load with the VS Code gate raised must stay silent
#              where the extension's own Lua module is absent.
#   ftplugin — every after/ftplugin file must apply cleanly to
#              a buffer of its filetype.
#   format   — the gq dispatcher must wrap a Python comment at its
#              72-column prose width while a code line keeps the
#              ftplugin's 79-column textwidth (no server attached).
#
# Gated group (network access, several minutes on a cold run):
#   startup  — the tracked tree is copied into a throwaway HOME/XDG sandbox,
#              every plugin is installed from scratch,
#              a subsequent boot must be completely silent,
#              a Bash heredoc must parse without an injection error,
#              a minimal TeX buffer must then open with VimTeX initialised,
#              a Python docstring must reflow at the dispatcher's prose width
#              (the tree-sitter leg the offline group cannot reach), and
#              both headless and UI-triggered installer sessions must restore
#              a deleted parser set before later sessions resume silently.
#              Enabled by NVIM_CHECK_FULL=1, or automatically under CI.
#
# Environment:
#   NVIM_BIN         Neovim executable to check against (default: nvim).
#   NVIM_CHECK_FULL  Set to 1 to enable the sandboxed startup group.
set -euo pipefail

NVIM_BIN=${NVIM_BIN:-nvim}
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$REPO_ROOT"

modern=$(
    "$NVIM_BIN" --clean --headless \
        '+lua io.write(vim.fn.has("nvim-0.12"))' +quitall 2>/dev/null
)
modern_cli=0
if command -v tree-sitter >/dev/null 2>&1; then
    version=$(tree-sitter --version 2>/dev/null || true)
    if [[ $version =~ ([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
        ts_major=${BASH_REMATCH[1]}
        ts_minor=${BASH_REMATCH[2]}
        ts_patch=${BASH_REMATCH[3]}
        if ((ts_major > 0 || ts_minor > 26 \
            || (ts_minor == 26 && ts_patch >= 1))); then
            modern_cli=1
        fi
    fi
fi

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
    --cmd "lua for _, m in ipairs({ 'options', 'filetype', 'keymaps', 'format' }) do require('thekpaul.' .. m) end")
if [ -n "$out" ]; then
    printf 'FAIL: core modules produced output:\n%s\n' "$out"
    fail=1
else
    echo "ok: thekpaul.{options,filetype,keymaps,format}"
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

group "format: gq prose/code dispatch"
# No plugins and no server here, so classification runs on the
# 'commentstring' fallback and the code path exercises the internal
# fallback of vim.lsp.formatexpr(): a 77-column Python comment must wrap
# at the 72-column prose width with its leader repeated, while a
# 75-column code line stays put under the ftplugin's 79-column textwidth.
out=$(run_quiet --clean \
    --cmd "set runtimepath+=$REPO_ROOT,$REPO_ROOT/after" \
    --cmd "filetype plugin on" \
    --cmd "lua require('thekpaul.options')" \
    "+setfiletype python" \
    "+call setline(1, ['# ' . repeat('abcd ', 15), \"x = '\" . repeat('abc ', 17) . \"z'\"])" \
    "+lua assert(vim.bo.formatexpr:find('thekpaul'), 'formatexpr not wired')" \
    "+normal! gggqq" \
    "+lua assert(vim.fn.line('\$') == 3 and #vim.fn.getline(1) <= 72 and #vim.fn.getline(2) <= 72 and vim.fn.getline(2):find('^# '), 'comment did not wrap at 72 with its leader')" \
    "+normal! Ggqq" \
    "+lua assert(vim.fn.line('\$') == 3 and #vim.fn.getline(3) == 75, 'code line was rewrapped')" \
    "+set nomodified")
if [ -n "$out" ]; then
    printf 'FAIL: gq dispatch produced output:\n%s\n' "$out"
    fail=1
else
    echo "ok: gq wraps prose at 72, leaves code to the fallback"
fi

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
    sandboxed_ui() {
        env -i HOME="$sandbox" PATH="$PATH" TERM=xterm-256color \
            NVIM_TEST_BIN="$NVIM_BIN" \
            XDG_CONFIG_HOME="$sandbox/config" \
            XDG_DATA_HOME="$sandbox/data" \
            XDG_STATE_HOME="$sandbox/state" \
            XDG_CACHE_HOME="$sandbox/cache" \
            script -qefc '"$NVIM_TEST_BIN" +quitall!' /dev/null
    }
    # First boot: bootstrap lazy.nvim and install every plugin from cold cache;
    # only the exit status matters.
    if ! sandboxed "+Lazy! install" >"$sandbox/install.log" 2>&1; then
        printf 'FAIL: plugin installation boot\n'
        tail -n 20 "$sandbox/install.log"
        fail=1
    else
        # Force-sync the active branch's parser set so
        # the silent boot cannot race a half-compiled parser.
        # The legacy API has a synchronous command;
        # the modern API exposes a waitable asynchronous task.
        # The list mirrors `./lua/plugins/treesitter.lua`, including
        # its toolchain-dependent opt-out.
        parsers_ok=1
        have_parsers=0
        if command -v cc >/dev/null 2>&1 \
            || command -v gcc >/dev/null 2>&1 \
            || command -v clang >/dev/null 2>&1; then
            have_parsers=1
        fi
        if [ "$modern" -eq 1 ] \
            && { ! command -v curl >/dev/null 2>&1 \
                || ! command -v tar >/dev/null 2>&1 \
                || [ "$modern_cli" -eq 0 ]; }; then
            have_parsers=0
        fi
        parsers="bash c cpp fish git_rebase gitcommit gitignore lua"
        parsers="$parsers markdown markdown_inline nu python vim vimdoc yaml"
        if [ "$have_parsers" -eq 1 ]; then
            if [ "$modern" -eq 1 ]; then
                install="require('nvim-treesitter').install"
                languages="{'bash','c','cpp','fish','git_rebase',"
                languages="$languages'gitcommit','gitignore','lua','markdown',"
                languages="$languages'markdown_inline','nu','python','vim',"
                languages="$languages'vimdoc','yaml'}"
                parser_cmd="+lua assert($install($languages):wait(300000), 'parser install failed')"
            else
                parser_cmd="+TSInstallSync! $parsers"
            fi
            if ! sandboxed "$parser_cmd" >"$sandbox/parsers.log" 2>&1; then
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
            if [ "$modern" -eq 1 ]; then
                active_plugin=nvim-treesitter-main
                inactive_plugin=nvim-treesitter-master
            else
                active_plugin=nvim-treesitter-master
                inactive_plugin=nvim-treesitter-main
            fi
            out=$(sandboxed \
                "+lua local p = require('lazy.core.config').plugins; assert(p['$active_plugin'], 'active Tree-sitter generation missing'); assert(not p['$inactive_plugin'], 'inactive Tree-sitter generation imported')" \
                2>&1)
            if [ -n "$out" ]; then
                printf 'FAIL: Tree-sitter import gate produced output:\n%s\n' \
                    "$out"
                fail=1
            else
                echo "ok: only $active_plugin entered the plugin graph"
            fi
            if [ "$have_parsers" -eq 1 ]; then
                printf '%s\n' '#!/usr/bin/env bash' 'cat <<EOF' 'body' 'EOF' \
                    >"$sandbox/heredoc.sh"
                out=$(sandboxed "$sandbox/heredoc.sh" \
                    '+lua assert(vim.bo.filetype == "bash", "not a Bash buffer")' \
                    '+lua vim.treesitter.get_parser(0):parse(true)' \
                    '+redraw' '+set nomodified' 2>&1)
                if [ -n "$out" ]; then
                    printf 'FAIL: Bash heredoc highlighting produced output:\n%s\n' \
                        "$out"
                    fail=1
                else
                    echo "ok: Bash heredoc parsed without injection errors"
                fi
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
            # VimTeX must initialise on this binary:
            # the version gate in lua/plugins/tex.lua picks a checkout
            # per Neovim version, and a rejected load announces itself with
            # an `echoerr` this boot captures.
            # Offline by construction — the sandbox has no TeX toolchain, so
            # tex.lua disables the compiler and
            # only the editing layer is exercised.
            printf '%s\n' '\documentclass{article}' '\begin{document}' \
                'x' '\end{document}' >"$sandbox/min.tex"
            out=$(sandboxed "$sandbox/min.tex" \
                "+lua assert(vim.b.vimtex, 'VimTeX did not initialise')" \
                "+lua assert(vim.bo.comments:find('%%'), 'TeX comments')" \
                2>&1)
            if [ -n "$out" ]; then
                printf 'FAIL: TeX buffer produced output:\n%s\n' "$out"
                fail=1
            else
                echo "ok: VimTeX initialised silently in a TeX buffer"
            fi
            # Markdown uses the native formatter
            # rather than the global comment/code dispatcher.
            # Its tree-sitter indent query returns column zero for
            # incomplete continuation nodes while `gq` is creating them, so
            # indentation is disabled while highlighting remains active.
            printf '  %s\n' "$(printf 'word %.0s' $(seq 24))end" \
                >"$sandbox/fmt.md"
            out=$(sandboxed "$sandbox/fmt.md" \
                '+setlocal textwidth=40' \
                '+lua assert(vim.bo.indentexpr == "", "Markdown indentexpr still active")' \
                '+lua assert(vim.bo.formatexpr == "", "Markdown formatexpr not native")' \
                '+silent normal! gg0gqq' \
                '+lua local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false); assert(#lines == 4, "Markdown paragraph did not reflow"); for _, line in ipairs(lines) do assert(line:find("^  %S"), "Markdown continuation lost indentation") end' \
                '+set nomodified' 2>&1)
            if [ -n "$out" ]; then
                printf 'FAIL: Markdown paragraph reflow produced output:\n%s\n' \
                    "$out"
                fail=1
            else
                echo "ok: Markdown reflow preserved paragraph indentation"
            fi
            # The gq dispatcher's docstring leg needs a tree-sitter
            # highlighter, which only exists where the python parser
            # was compiled: the 77-column docstring body must reflow
            # at the 72-column prose width and the closing quotes must
            # stay on their own line. The explicit parse() removes any
            # dependence on a headless redraw having parsed the tree.
            if [ "$have_parsers" -eq 1 ]; then
                printf '%s\n' 'def f():' '    """Summary.' '' \
                    "    $(printf 'abcd %.0s' $(seq 14))end" '    """' \
                    >"$sandbox/fmt.py"
                out=$(sandboxed "$sandbox/fmt.py" \
                    '+lua vim.treesitter.get_parser(0):parse(true)' \
                    '+lua assert(vim.bo.indentexpr ~= "", "Python indentexpr not configured")' \
                    '+lua assert(vim.fn.maparg("af", "o", false, true).buffer == 1, "Python text object not mapped")' \
                    '+4' '+normal! gqq' \
                    '+lua assert(vim.fn.line("$") == 6, "docstring did not wrap at 72")' \
                    '+lua assert(#vim.fn.getline(4) <= 72 and #vim.fn.getline(5) <= 72, "docstring line over 72 columns")' \
                    '+lua assert(vim.trim(vim.fn.getline(6)) == [["""]], "closing quotes were disturbed")' \
                    '+set nomodified' 2>&1)
                if [ -n "$out" ]; then
                    printf 'FAIL: docstring gq produced output:\n%s\n' \
                        "$out"
                    fail=1
                else
                    echo "ok: docstring reflowed at the 72-column width"
                fi
                # Both generations must uphold the same installation contract:
                # one headless installer restores every missing parser
                # before it exits, and a UI boot delegates that blocking work to
                # one detached headless process.
                # The following session must then
                # have nothing left to install and remain silent.
                # Runs last so earlier silence checks see a settled tree.
                if [ "$modern" -eq 1 ]; then
                    gi="$sandbox/data/nvim/treesitter-main/parser/gitignore.so"
                    bash_parser="$sandbox/data/nvim/treesitter-main/parser/bash.so"
                else
                    gi="$sandbox/data/nvim/treesitter-master/parser/gitignore.so"
                    bash_parser="$sandbox/data/nvim/treesitter-master/parser/bash.so"
                fi
                rm -f "$gi" "$bash_parser"
                if sandboxed >"$sandbox/reinstall.log" 2>&1 \
                    && [ -f "$gi" ] && [ -f "$bash_parser" ]; then
                    echo "ok: one headless boot restored all deleted parsers"
                else
                    printf 'FAIL: headless boot did not restore parser set\n'
                    tail -n 10 "$sandbox/reinstall.log"
                    fail=1
                fi
                out=$(sandboxed 2>&1)
                if [ -n "$out" ]; then
                    printf 'FAIL: post-install boot produced output:\n%s\n' \
                        "$out"
                    fail=1
                else
                    echo "ok: session after headless install stayed silent"
                fi

                if command -v script >/dev/null 2>&1; then
                    rm -f "$gi" "$bash_parser"
                    if sandboxed_ui >"$sandbox/ui-install.log" 2>&1; then
                        ts_attempts=0
                        while { [ ! -f "$gi" ] \
                            || [ ! -f "$bash_parser" ]; } \
                            && [ "$ts_attempts" -lt 3000 ]; do
                            sleep 0.1
                            ts_attempts=$((ts_attempts + 1))
                        done
                        if [ -f "$gi" ] && [ -f "$bash_parser" ]; then
                            echo "ok: one UI boot delegated all deleted parsers"
                        else
                            printf 'FAIL: UI boot did not restore parser set\n'
                            tail -n 10 "$sandbox/ui-install.log"
                            fail=1
                        fi
                    else
                        printf 'FAIL: pseudo-terminal UI boot\n'
                        tail -n 10 "$sandbox/ui-install.log"
                        fail=1
                    fi
                    out=$(sandboxed 2>&1)
                    if [ -n "$out" ]; then
                        printf 'FAIL: post-background boot produced output:\n%s\n' \
                            "$out"
                        fail=1
                    else
                        echo "ok: session after background install stayed silent"
                    fi
                else
                    echo "skipped UI installer check (`script` unavailable)"
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
