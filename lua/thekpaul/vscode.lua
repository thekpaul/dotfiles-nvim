--[=[
Inside VS Code, the vscode-neovim extension embeds Neovim as the editing engine
while VS Code itself owns every panel, list and prompt.
This module bridges finder-, git- and LSP-shaped muscle memory to
matching VS Code commands so the same keystrokes land in either environment.

It is a silent no-op everywhere else — including simulated runs where
`vim.g.vscode` is set but the extension's Lua module is absent.
--]=]
if not vim.g.vscode then
	return
end

local ok, vscode = pcall(require, "vscode")
if not ok then
	return
end

-- The nvim-treesitter plugin is deliberately disabled in VS Code
-- (see `./lua/plugins/treesitter/init.lua`), so its `setup()` never exposes
-- the separately installed parsers and queries on 'runtimepath'.
-- Core ftplugins may still use Tree-sitter (Markdown does), so
-- make that runtime discoverable without loading the plugin itself.
-- The generation gate mirrors init.lua's, and
-- the path comes from `common.install_dir()` rather than a literal, so
-- neither can drift out of sync with the canonical Tree-sitter configurations.
local treesitter_common = require("plugins.treesitter.common")
local generation = vim.fn.has("nvim-0.12") == 1 and "main" or "master"
local ts_runtime = vim.fs.normalize(treesitter_common.install_dir(generation))
if
	vim.uv.fs_stat(ts_runtime)
	and not vim.tbl_contains(vim.opt.runtimepath:get(), ts_runtime)
then
	vim.opt.runtimepath:prepend(ts_runtime)
end

-- Anything in `opts` reaches the command as its argument list;
-- a plain table is wrapped into one, which is
-- the shape object-taking commands such as the search below expect.
local function action(name, opts)
	return function()
		vscode.action(name, opts)
	end
end

local map = vim.keymap.set

-- Pickers: VS Code owns the lists, so the snacks keys open its own.
-- Unsupported:
-- - `<leader>fh` (help tags): No support for Neovim help docs in VS Code.
map("n", "<leader>ff", action("workbench.action.quickOpen"), {
	desc = "Find files (VS Code)",
})
map("n", "<leader>fg", action("workbench.action.findInFiles"), {
	desc = "Live grep (VS Code)",
})
map("n", "<leader>fb", action("workbench.action.showAllEditors"), {
	desc = "Find buffers (VS Code)",
})
map("n", "<leader>fr", action("workbench.action.openRecent"), {
	desc = "Recent files (VS Code)",
})
-- The Problems view is workspace-wide and groups by file, so
-- the buffer-local variant collapses onto the same panel.
map("n", "<leader>fd", action("workbench.actions.view.problems"), {
	desc = "Diagnostics (VS Code)",
})
map("n", "<leader>fD", action("workbench.actions.view.problems"), {
	desc = "Buffer diagnostics (VS Code)",
})
-- todo-comments is gated out, but its picker has a built-in stand-in:
-- a workspace search for the same keyword shapes.
-- Unsupported:
-- - `<leader>tn` and `<leader>tp`: jump between annotations unsupported.
map(
	"n",
	"<leader>ft",
	action("workbench.action.findInFiles", {
		args = {
			query = "\\b(TODO|FIXME|FIX|BUG|HACK|WARN|XXX|PERF|NOTE|TEST):",
			isRegex = true,
			triggerSearch = true,
		},
	}),
	{ desc = "Find annotation comments (VS Code)" }
)
-- Closes editor while preserving layout, mirroring `snacks.bufdelete`.
map("n", "<leader>bd", action("workbench.action.closeActiveEditor"), {
	desc = "Delete buffer (VS Code)",
})

-- Git operations: VS Code exposes the same operations as commands,
-- which are used instead of Git-related plugins to mirror functionality.
-- Unsupported:
-- - `<leader>gv` and `<leader>gtd` are moot where
--   the gutter paints hunks and deletions permanently;
-- - `<leader>gb` (blame popup): no built-in command;
-- - `<leader>gD` (diff against arbitrary revision): no built-in command.
map("n", "<leader>gn", action("workbench.action.editor.nextChange"), {
	desc = "Next hunk (VS Code)",
})
map("n", "<leader>gp", action("workbench.action.editor.previousChange"), {
	desc = "Previous hunk (VS Code)",
})
map({ "n", "x" }, "<leader>gs", action("git.stageSelectedRanges"), {
	desc = "Stage hunk (VS Code)",
})
map({ "n", "x" }, "<leader>gr", action("git.revertSelectedRanges"), {
	desc = "Reset hunk (VS Code)",
})
map("n", "<leader>gS", action("git.stage"), {
	desc = "Stage buffer (VS Code)",
})
-- Nearest available: VS Code unstages the range under the cursor,
-- rather than undoing whichever hunk was staged last.
map("n", "<leader>gu", action("git.unstageSelectedRanges"), {
	desc = "Unstage hunk (VS Code)",
})
map("n", "<leader>gR", action("git.clean"), {
	desc = "Reset buffer (VS Code)",
})
map("n", "<leader>gd", action("git.openChange"), {
	desc = "Diff against index (VS Code)",
})
map("n", "<leader>gtb", action("git.blame.toggleEditorDecoration"), {
	desc = "Toggle line blame (VS Code)",
})

-- Language servers: Supported in VS Code by default, so LSP keybindings are
-- always enabled; finder-opening keybindings open VS Code's peek widgets.
-- Unsupported:
-- - `<leader>lh` (inlay hints): a setting, with no command to flip it.
map("n", "gd", action("editor.action.revealDefinition"), {
	desc = "Go to definition (VS Code)",
})
map("n", "gD", action("editor.action.revealDeclaration"), {
	desc = "Go to declaration (VS Code)",
})
map("n", "<leader>ld", action("editor.action.peekDefinition"), {
	desc = "Pick definitions (VS Code)",
})
map("n", "<leader>lD", action("editor.action.peekDeclaration"), {
	desc = "Pick declarations (VS Code)",
})
map("n", "<leader>lr", action("editor.action.goToReferences"), {
	desc = "Pick references (VS Code)",
})
map("n", "<leader>li", action("editor.action.goToImplementation"), {
	desc = "Pick implementations (VS Code)",
})
map("n", "<leader>lt", action("editor.action.goToTypeDefinition"), {
	desc = "Pick type definitions (VS Code)",
})
map("n", "<leader>lf", action("editor.action.formatDocument"), {
	desc = "LSP format buffer (VS Code)",
})

-- Keymap hints through `<leader>?` unsupported: Neovim mappings that
-- which-key's popup describes cannot be enumerated in VS Code.
