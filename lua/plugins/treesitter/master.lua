--[=[
Tree-sitter based highlighting and indentation for Neovim 0.11.

Pinned to the master branch: upstream's main-branch rewrite
replaces the plugin's entire module surface and requires Neovim 0.12, while
this legacy configuration retains the legacy `master`-side API.
Parser compilation needs a C compiler; when none is present,
the parsers bundled with Neovim keep working and
the extra ones are simply skipped instead of failing every startup.
Interactive boots never block on parser compiles: missing parsers are
built by a detached headless instance of this same configuration, which
takes the synchronous branch and therefore exits on its own when done.
--]=]

local common = require("plugins.treesitter.common")
local install_dir = common.install_dir("master")

-- Text objects ride the same module system;
-- branches must pair with the nvim-treesitter branch (`master` with `master`).
local textobjects = { "nvim-treesitter/nvim-treesitter-textobjects" }

textobjects.name = "nvim-treesitter-textobjects-master"
textobjects.branch = "master"

local treesitter = { "nvim-treesitter/nvim-treesitter" }

treesitter.name = "nvim-treesitter-master"
treesitter.branch = textobjects.branch
treesitter.lazy = false
treesitter.build = common.has_c_compiler() and ":TSUpdate" or nil
treesitter.dependencies = { textobjects }

treesitter.config = function()
	local ensure = common.has_c_compiler() and common.parser_names or {}
	-- A UI attached means a human is waiting; headless instances —
	-- scripts, CI, and the background installer spawned below —
	-- can afford to block on parser compiles.
	local interactive = #vim.api.nvim_list_uis() > 0

	-- Keep 0.11-compatible parsers and queries out of the modern runtime.
	-- The legacy API creates parser/ and queries/ beneath this runtime root.
	vim.opt.runtimepath:prepend(install_dir)
	require("nvim-treesitter.configs").setup({
		parser_install_dir = install_dir,
		-- Headless boots compile missing parsers synchronously,
		-- blocking until done: the cost lands once, on the boot that notices,
		-- instead of leaking asynchronous installer output into later ones.
		-- Interactive boots opt out of installing here entirely and
		-- delegate such blocking behaviour to a detached headless instance
		-- at the bottom of this function.
		ensure_installed = interactive and {} or ensure,
		sync_install = true,
		auto_install = false,
		highlight = {
			enable = true,
			disable = {
				"latex",
				-- "dockerfile",
			},
		},
		indent = {
			enable = true,
			disable = {
				-- Delegated to VimTeX.
				"latex",
				-- Markdown reflow creates incomplete nodes whose query returns
				-- column zero; native autoindent preserves paragraph indent.
				"markdown",
			},
		},
		textobjects = {
			select = {
				enable = true,
				-- Jump ahead to the next object when not inside one.
				lookahead = true,
				keymaps = {
					["af"] = "@function.outer",
					["if"] = "@function.inner",
					["ac"] = "@class.outer",
					["ic"] = "@class.inner",
					["aa"] = "@parameter.outer",
					["ia"] = "@parameter.inner",
				},
			},
			move = {
				enable = true,
				set_jumps = true,
				-- Same-intent overwrite of the built-in method motions,
				-- generalised beyond curly-brace languages;
				-- buffer-local, only where a parser attaches.
				goto_next_start = { ["]m"] = "@function.outer" },
				goto_next_end = { ["]M"] = "@function.outer" },
				goto_previous_start = { ["[m"] = "@function.outer" },
				goto_previous_end = { ["[M"] = "@function.outer" },
			},
		},
	})

	-- The delegation.
	-- The spawned instance boots this configuration headless,
	-- takes the synchronous branch above and exits on its own
	-- once every parser has landed.
	-- Nothing in this session ever blocks: buffers opened after a parser lands
	-- attach through the ordinary FileType path, and
	-- the completion notice points at `:e` for buffers that were already open.
	if not interactive or #ensure == 0 then
		return
	end
	-- "Installed" must mean what the installer means by it —
	-- a parser in the plugin's own install directory.
	-- Probing the runtimepath instead would let the Neovim-bundled parsers
	-- mask the plugin's matching-revision copies and skip their install.
	local dir = require("nvim-treesitter.configs").get_parser_install_dir()
	if not dir then
		return
	end
	local function missing()
		return vim.tbl_filter(function(lang)
			return vim.fn.filereadable(dir .. "/" .. lang .. ".so") == 0
		end, ensure)
	end
	common.install_in_background(missing)
end

return { treesitter }
