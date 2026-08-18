--[=[
Tree-sitter based highlighting and indentation for Neovim 0.12.

Pinned to the master branch: upstream's main-branch rewrite
replaces the plugin's entire module surface and requires Neovim 0.12, which
this module is designed to handle exclusively.
Parser compilation needs a C compiler; when none is present,
the parsers bundled with Neovim keep working and
the extra ones are simply skipped instead of failing every startup.
--]=]
local common = require("plugins.treesitter.common")
local install_dir = common.install_dir("main")

-- Main's rewritten API needs the external CLI, not just a C compiler, to
-- build parsers from source; the version check is nontrivial enough to
-- isolate from the combined `has_toolchain()` gate below.
local function has_cli()
	if not common.executable("tree-sitter") then
		return false
	end
	local output = vim.fn.system({ "tree-sitter", "--version" })
	if vim.v.shell_error ~= 0 then
		return false
	end
	local major, minor, patch = output:match("(%d+)%.(%d+)%.(%d+)")
	if not major then
		return false
	end
	major, minor, patch = tonumber(major), tonumber(minor), tonumber(patch)
	return major > 0 or minor > 26 or (minor == 26 and patch >= 1)
end

-- Shared by the Lazy build hook and `config()`: both need the identical
-- "can we compile parsers" gate, so the four-way check lives once here
-- instead of being repeated at each call site.
local function has_toolchain()
	return common.has_c_compiler()
		and common.executable("curl")
		and common.executable("tar")
		and has_cli()
end

local textobjects = { "nvim-treesitter/nvim-treesitter-textobjects" }

textobjects.name = "nvim-treesitter-textobjects-main"
textobjects.branch = "main"

local treesitter = { "nvim-treesitter/nvim-treesitter" }

treesitter.name = "nvim-treesitter-main"
treesitter.branch = textobjects.branch
treesitter.lazy = false
treesitter.dependencies = { textobjects }

-- Lazy's build hook fires only on install/update, not on every startup;
-- it force-updates every tracked parser and asserts success,
-- unlike `config()`'s fill-only-what's-missing behavior below.
treesitter.build = function()
	if not has_toolchain() then
		return
	end
	local treesitter = require("nvim-treesitter")
	treesitter.setup({ install_dir = install_dir })
	assert(
		treesitter.update():wait(300000),
		"Tree-sitter parser update failed"
	)
end

-- Main's textobjects module exposes bare select/move functions instead of
-- accepting a keymaps table like master's, so hand-wiring is necessary for it;
-- buffer-scoped since keymaps must bind per attaching buffer.
local function set_textobject_maps(buf)
	-- Closures bind capture/method args `vim.keymap.set` can't pass through;
	-- each key needs its own zero-arg callback.
	local function select(capture)
		return function()
			require("nvim-treesitter-textobjects.select").select_textobject(
				capture,
				"textobjects"
			)
		end
	end
	local function move(method, capture)
		return function()
			require("nvim-treesitter-textobjects.move")[method](
				capture,
				"textobjects"
			)
		end
	end
	local opts = { buffer = buf, silent = true }
	for lhs, capture in pairs({
		["af"] = "@function.outer",
		["if"] = "@function.inner",
		["ac"] = "@class.outer",
		["ic"] = "@class.inner",
		["aa"] = "@parameter.outer",
		["ia"] = "@parameter.inner",
	}) do
		vim.keymap.set({ "x", "o" }, lhs, select(capture), opts)
	end
	for lhs, target in pairs({
		["]m"] = { "goto_next_start", "@function.outer" },
		["]M"] = { "goto_next_end", "@function.outer" },
		["[m"] = { "goto_previous_start", "@function.outer" },
		["[M"] = { "goto_previous_end", "@function.outer" },
	}) do
		vim.keymap.set(
			{ "n", "x", "o" },
			lhs,
			move(target[1], target[2]),
			opts
		)
	end
end

-- Lazy calls exactly one function on plugin load; this ties core setup,
-- missing-parser install, and per-buffer wiring together as that
-- single entry point rather than splitting them across separate Lazy hooks.
treesitter.config = function()
	local treesitter = require("nvim-treesitter")
	treesitter.setup({ install_dir = install_dir })
	require("nvim-treesitter-textobjects").setup({
		select = { lookahead = true },
		move = { set_jumps = true },
	})

	local ensure = has_toolchain() and common.parser_names or {}
	-- Passed to the shared `common.install_in_background()`;
	-- kept local since the missing-path template (install_dir/parser/lang.so)
	-- is specific to main's install layout, unlike master's.
	local function missing()
		return vim.tbl_filter(function(lang)
			return vim.fn.filereadable(
				install_dir .. "/parser/" .. lang .. ".so"
			) == 0
		end, ensure)
	end
	local absent = missing()
	if #absent > 0 then
		if #vim.api.nvim_list_uis() > 0 then
			common.install_in_background(missing)
		else
			-- Rewritten installer is asynchronous internally; waiting makes
			-- this headless process sole owner of the complete missing set.
			-- `install()` otherwise treats a surviving query directory as an
			-- installed language even when its parser binary has disappeared.
			assert(
				treesitter.install(absent, { force = true }):wait(300000),
				"Tree-sitter parser installation failed"
			)
		end
	end

	-- Main's core has no all-in-one highlight/indent config table like
	-- master's setup() call; each buffer must opt in individually
	-- once its FileType fires, replacing master's declarative fields.
	local group = vim.api.nvim_create_augroup("thekpaul.treesitter", {})
	vim.api.nvim_create_autocmd("FileType", {
		group = group,
		callback = function(ev)
			local ft = vim.bo[ev.buf].filetype
			if ft == "latex" then
				return
			end
			local lang = vim.treesitter.language.get_lang(ft) or ft
			if not pcall(vim.treesitter.start, ev.buf, lang) then
				return
			end
			if ft ~= "markdown" then
				local ok, query =
					pcall(vim.treesitter.query.get, lang, "indents")
				if ok and query then
					vim.bo[ev.buf].indentexpr =
						"v:lua.require'nvim-treesitter'.indentexpr()"
				end
			end
			local ok, query =
				pcall(vim.treesitter.query.get, lang, "textobjects")
			if ok and query then
				set_textobject_maps(ev.buf)
			end
		end,
	})
end

return { treesitter }
