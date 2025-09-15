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

-- Text objects ride the same module system;
-- branches must pair with the nvim-treesitter branch (`master` with `master`).
local textobjects = { "nvim-treesitter/nvim-treesitter-textobjects" }

textobjects.branch = "master"

local treesitter = { "nvim-treesitter/nvim-treesitter" }

treesitter.branch = textobjects.branch
treesitter.lazy = false
treesitter.build = has_c_compiler() and ":TSUpdate" or nil
treesitter.dependencies = { textobjects }

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
		indent = {
			enable = true,
			-- Delegated to VimTeX
			disable = { "latex" },
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
end

return { treesitter }
