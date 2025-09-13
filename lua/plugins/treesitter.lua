--[=[
Tree-sitter based highlighting and indentation.

Pinned to the master branch:
upstream's main-branch rewrite replaces the plugin's entire module surface, and
this configuration tracks the stable API until that settles.
Parser compilation needs a C compiler; when none is present,
the parsers bundled with Neovim keep working and
the extra ones are simply skipped instead of failing every startup.
--]=]

local function has_c_compiler()
	return vim.fn.executable("cc") == 1
		or vim.fn.executable("gcc") == 1
		or vim.fn.executable("clang") == 1
end

local treesitter = { "nvim-treesitter/nvim-treesitter" }

treesitter.branch = "master"
treesitter.lazy = false
treesitter.build = has_c_compiler() and ":TSUpdate" or nil

treesitter.config = function()
	require("nvim-treesitter.configs").setup({
		ensure_installed = has_c_compiler() and {
			"bash",
			"c",
			"cpp",
			"fish",
			"git_rebase",
			"gitcommit",
			"gitignore",
			"lua",
			"markdown",
			"markdown_inline",
			"nu",
			"python",
			"vim",
			"vimdoc",
			"yaml",
		} or {},
		sync_install = false,
		auto_install = false,
		highlight = {
			enable = true,
			disable = {
				"latex",
				-- "dockerfile",
			},
		},
		indent = { enable = true },
	})
end

return { treesitter }
