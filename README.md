Neovim Configurations
===

This repository tracks configurations for the Neovim text editor.

## Installation Methods

Install this repository at `$XDG_CONFIG_HOME/nvim`:

### Git Worktree (Recommended)

Create a new Git worktree from the submodule copy inside your
local superproject installation to the destination path:
```sh
git worktree add $XDG_CONFIG_HOME/nvim -b main --track <remote_name>/main
```
where `remote_name` is the name of the "remote" repository from which
your superproject installation is cloned.

### Standalone Installation from Remote

```sh
git clone https://github.com/thekpaul/dotfiles-nvim.git $XDG_CONFIG_HOME/nvim
```

### (Sym)link from Local Superproject Installation (Not recommended)

> [!CAUTION]
> Modifications made through the link are committed from
> inside the superproject installation:
> with this repository integrated as a subtree, they land in
> the superproject's history instead of this repository, and
> with a submodule they leave the superproject's recorded pin unsynchronised.
> Prefer a worktree, which always commits to this repository directly.

- Unix-based systems where `ln` is available:
  ```sh
  ln -s <SUPERPROJECT_INSTALLATION_PATH>/nvim $XDG_CONFIG_HOME/nvim
  ```
  Using the `-s` flag creates a "symbolic" ("soft") link, which is
  most likely to be the only type of link possible to create for directories
  on Unix-based systems.
  Omitting the `-s` flag creates a "hard" link, which is
  possible for **individual files**.
- Windows systems with PowerShell, using the `New-Item` cmdlet:
  ```pwsh
  New-Item -Path $env:XDG_CONFIG_HOME\nvim -ItemType Junction -Value <SUPERPROJECT_INSTALLATION_PATH>\nvim
  ```
  `ItemType` may be changed to `HardLink` for **individual files** or
  `SymbolicLink` to create "shortcut"s ("symbolic" links).

Make sure to use the _full path_ for `<SUPERPROJECT_INSTALLATION_PATH>`.

## Superproject Integration

Any superproject may import this repository in either of two ways —
the author's own [dotfiles][dotfiles] is one such superproject,
not a privileged one.
Both methods track the same `main` branch, and
neither changes how the configurations behave once installed.

### As a Submodule

```sh
git submodule add https://github.com/thekpaul/dotfiles-nvim.git nvim
```
The superproject pins an exact commit of this repository;
refresh the pin to the latest `main` with:
```sh
git submodule update --remote nvim
```

### As a Subtree

```sh
git subtree add --prefix=nvim https://github.com/thekpaul/dotfiles-nvim.git main --squash
```
The configurations are copied into the superproject's own tree;
import later updates with:
```sh
git subtree pull --prefix=nvim https://github.com/thekpaul/dotfiles-nvim.git main --squash
```

## Structure

- `init.lua`: the version guard, then ordered module loading.
- [`lua/thekpaul/`](./lua/thekpaul/): the plugin-free core modules —
  - `options.lua` — the built-in option baseline.
  - `filetype.lua` — extra detection rules (shebang-aware shell split).
  - `keymaps.lua` — mappings over built-in functionality only.
  - `format.lua` — the `gq` dispatcher (see Formatting).
  - `plugins.lua` — the lazy.nvim bootstrap and spec loading.
- [`lua/plugins/`](./lua/plugins/):
  one plugin spec file per concern (colours, finder, LSP, git, …).
- [`after/ftplugin/`](./after/ftplugin/): per-language buffer refinements.
- `tests/run-checks.sh`: the check suite (see Testing).

## Version Expectations

Development floor is Neovim **0.11**; `init.lua` refuses to load on
older versions, and there are no compatibility branches for earlier releases.
Newer capabilities are layered behind `vim.fn.has("nvim-0.12")` gates —
one configuration catering to both releases with version awareness.
Currently gated:

- LSP inline (ghost-text) completion, enabled per buffer
  for servers that announce it: `<leader>lc` toggles it, and
  insert-mode `<C-l>` accepts the pending suggestion.
- LSP linked editing range: cursor-synchronised edits of identical ranges for
  servers that support it.

CI (see below) exercises the floor with the gates off,
the 0.12 line with them on, and whatever release is current.

## Plugin Versioning

Plugin versions deliberately track their upstream default branches.
`lazy-lock.json` is ignored rather than committed: instead of
replaying a frozen graph, the check suite proves the configuration
against live plugin heads — the sandboxed cold-start check
installs everything from nothing and requires the following boot to be silent.
Update with `:Lazy update`, then run the suite.

## External Tool Assumptions

Beyond Neovim itself only `git` is required —
it bootstraps lazy.nvim and installs plugins.
Everything else is probed at runtime, and
absence disables the capability that needed it rather than breaking startup:

- A C compiler (`cc`, `gcc` or `clang`) —
  compiles the extra tree-sitter parsers; without one,
  the parsers bundled with Neovim keep working and the extras are skipped.
  Interactive sessions never block on those compiles: missing parsers are
  built by a detached headless instance that exits on its own, and a
  message announces completion — buffers opened afterwards pick the
  parsers up automatically, `:e` re-applies buffers already open.
  Headless sessions compile missing parsers synchronously on the boot
  that notices them, which is exactly what that background instance
  relies on.
- `ripgrep` — powers the live-grep picker; file-based pickers work without.
- Language servers — installed through `:Mason` (fetches `lua_ls` on its own);
  any server Mason installs is enabled automatically.
  The one exception is Nushell, whose server ships inside the shell binary
  (`nu --lsp`): it is enabled whenever `nu` is on `$PATH`.
  basedpyright resolves its interpreter per workspace:
  an activated `$VIRTUAL_ENV`, then a `.venv/` or Pixi default environment,
  then `python3` from `$PATH`.
- `latexmk` — VimTeX compilation; the TeX editing layer works without it.
- WakaTime — loads only in interactive sessions, so scripted and headless runs
  never touch it; the first interactive session without stored credentials
  prompts for an API key.

## Filetype Behaviour

- Shell scripts are split by shebang into `bash` and `sh`, and
  the two get different indentation profiles under `after/ftplugin/`:
  four-space indentation for Bash and two-space indentation for POSIX sh.
- Project-local `.nvim.lua` files are honoured (`exrc` is on).
  They only execute after explicit approval through `:trust`, so
  cloning a repository never runs its editor configuration unprompted.

## Formatting

`gq` dispatches by what the selected lines are (`lua/thekpaul/format.lua`):

- Comment and docstring ranges keep Vim's internal comment-aware
  formatting, wrapped at a per-filetype *prose width*: Python comments and
  docstrings reflow at 72 columns (PEP 8) while its code keeps the
  79-column `textwidth`; filetypes without an entry wrap prose at the
  buffer's own width.
- Ranges containing any code line are delegated whole to the language
  server's range formatting. Without a capable server the internal
  formatter takes over at the buffer's `textwidth`, so buffers with no
  server keep stock `gq` behaviour throughout.

Classification is per line, sampled at the first non-blank character:
tree-sitter highlight captures where a highlighter is active (docstrings
included, via `@string.documentation`), the `commentstring` leader
otherwise. Known limits, all deliberate:

- Mixed selections are never split — code plus comments goes to the
  server, which typically reformats the code and leaves the prose alone.
- A line of code with a trailing comment counts as code.
- Docstring detection needs the tree-sitter highlighter; without a parser
  attached, docstrings classify as code and take the server path.
- The reflow is the internal greedy wrap: a closing `"""` sitting directly
  under body text (no blank line between) belongs to the same paragraph
  and multi-line motions will pull it up; PEP 257-shaped docstrings —
  summary line, blank line, body, closing quotes — are unaffected.
- `gw` bypasses `formatexpr` by definition (it is also what the dispatcher
  itself drives), so it always wraps at the buffer's `textwidth`.

## Inside VS Code

With the [vscode-neovim] extension, this same configuration runs
as VS Code's editing engine.
Panels and painting belong to VS Code, so plugins stay unloaded by default and
only specs that opt in with `cond = true` (pure operator/command plugins
such as nvim-surround and vim-abolish) participate.
Finder-shaped mappings — `<leader>ff`, `<leader>fg`, etc. — are bridged to
their matching VS Code commands, as is most of the `<leader>g` family, which
drives VS Code's own staging, reset and diff commands.
The LSP mappings follow suit, reaching VS Code's navigation, peek and
formatting commands in place of a language server of their own, so
muscle memory carries over unchanged.
Some keys belonging to gated-out plugins carry over where VS Code can stand in:
`<leader>ft` searches the annotation keywords todo-comments would have listed.

[vscode-neovim]: https://github.com/vscode-neovim/vscode-neovim

## Testing

Run the check suite locally:
```sh
bash tests/run-checks.sh                    # offline groups
NVIM_CHECK_FULL=1 bash tests/run-checks.sh  # plus the sandboxed cold start
NVIM_BIN=/path/to/nvim bash tests/run-checks.sh
```
This exercises a `loadfile()` syntax sweep over every tracked Lua file,
a plugin-free load of the core modules, a simulated VS Code load
proving the gating no-ops without the extension present,
an application check for each `after/ftplugin/` profile, and
a `gq` dispatch check (prose wraps at its prose width, code does not);
the gated group copies the tracked tree into throwaway `HOME`/XDG directories,
cold-installs the plugin graph, and asserts a silent boot —
plain and again with the VS Code gate active — no real editor state is touched.
Silence is the contract throughout: any output fails.

## CI

GitHub Actions (`.github/workflows/ci.yml`) runs Luacheck and StyLua in
check mode, then the full check suite — cold start included — on
push and pull request against `main`, across a Pixi-provisioned Neovim matrix:
the oldest supported 0.11 line proving the floor with gates off,
a 0.12 line proving the gated additions, and
an open leg tracking the current release.

## Meta

Authored and maintained by [Paul Kim](https://thekpaul.dev).

Distributed under the [MIT License](./LICENSE).

[dotfiles]: https://github.com/thekpaul/dotfiles
