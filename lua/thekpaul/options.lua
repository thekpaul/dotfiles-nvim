--[=[
Baseline editor behaviour, expressed through built-in options and interfaces.

Anything that needs a plugin (or a filetype) to make sense lives elsewhere;
this module must stay loadable on a bare Neovim.
--]=]

-- Interface ------------------------------------------------------------------
vim.o.number = true
vim.o.relativenumber = true
-- Show absolute and relative numbers together, each anchored in place:
-- relative left-justified beside the signs, absolute flush right, so
-- neither column shifts as digit counts change
-- (a relative distance past 999 widens only its own row); the literal space
-- after the relative field keeps a gap even when both sides run three digits.
-- Both options above stay on — they enable the column and populate `v:relnum`.
-- Continuation rows of wrapped lines (prose filetypes) render neither.
vim.o.statuscolumn = "%s%{v:virtnum ? '' : printf('%-3d', v:relnum)} "
	.. "%=%{v:virtnum ? '' : v:lnum} "
vim.o.signcolumn = "yes"
vim.o.cursorline = true
vim.o.cursorcolumn = true
vim.o.scrolloff = 4
vim.o.termguicolors = true
vim.o.showmode = false
vim.o.list = true
vim.opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }
vim.opt.fillchars = { eob = " " } -- no end-of-buffer tildes
vim.opt.colorcolumn = { "80", "120" }
-- One logical line per grid row:
-- long lines scroll horizontally in steps instead of soft-wrapping;
-- prose filetypes opt back in per-ftplugin.
vim.o.wrap = false
vim.o.sidescroll = 8

-- Windows --------------------------------------------------------------------
vim.o.splitright = true
vim.o.splitbelow = true

-- Indentation defaults (filetypes refine these under after/ftplugin/) --------
vim.o.tabstop = 4
vim.o.shiftwidth = 4
vim.o.softtabstop = 4
vim.o.expandtab = false
vim.o.smartindent = true

-- Search ---------------------------------------------------------------------
vim.o.ignorecase = true
vim.o.smartcase = true
vim.o.inccommand = "split"

-- Diagnostics ----------------------------------------------------------------
-- Rendering for diagnostics from any producer
-- (LSP servers today, anything feeding vim.diagnostic later): severity-sorted,
-- with a source-annotated rounded float and per-severity sign glyphs.
vim.diagnostic.config({
	severity_sort = true,
	virtual_text = { spacing = 2 },
	float = { border = "rounded", source = true },
	signs = {
		text = {
			[vim.diagnostic.severity.ERROR] = "✘",
			[vim.diagnostic.severity.WARN] = "▲",
			[vim.diagnostic.severity.INFO] = "●",
			[vim.diagnostic.severity.HINT] = "○",
		},
	},
	-- Make the default ]d / [d / ]D / [D jumps open the detail float on
	-- arrival: the built-in maps read this key (:h vim.diagnostic.Opts.Jump).
	jump = { float = true },
})

-- Files and state ------------------------------------------------------------
-- Keep EUC-KR in the detection chain for legacy Korean files.
vim.opt.fileencodings = { "ucs-bom", "utf-8", "euc-kr", "default", "latin1" }
vim.o.undofile = true
vim.o.swapfile = false
vim.o.updatetime = 300
vim.o.timeoutlen = 500

-- Project-local configuration ------------------------------------------------
-- Allow per-project .nvim.lua files.
-- Executed only after being explicitly approved through the `:trust` database,
-- so enabling exrc does not run arbitrary code from checked-out repositories.
vim.o.exrc = true
