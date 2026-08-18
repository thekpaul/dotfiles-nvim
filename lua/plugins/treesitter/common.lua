-- Shared parser inventory and installation lifecycle for both upstream APIs.
local M = {}

M.parser_names = {
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
}

-- `master.lua` and `main.lua` each keep their own generation's parser/query
-- installs under a name-scoped directory; centralized here so
-- a rename cannot drift out of sync with callers outside this pair that
-- need to locate it (`./lua/thekpaul/vscode.lua`'s runtimepath injection).
function M.install_dir(generation)
	return vim.fn.stdpath("data") .. "/treesitter-" .. generation
end

function M.executable(name)
	return vim.fn.executable(name) == 1
end

function M.has_c_compiler()
	return M.executable("cc") or M.executable("gcc") or M.executable("clang")
end

function M.install_in_background(missing)
	local absent = missing()
	if #absent == 0 then
		return
	end
	vim.system(
		{ vim.v.progpath, "--headless", "+quitall!" },
		{ detach = true },
		vim.schedule_wrap(function()
			local left = missing()
			if #left == 0 then
				vim.notify(
					"Tree-sitter parsers installed; "
						.. "re-open buffers with :e to apply."
				)
			else
				vim.notify(
					"Tree-sitter parsers still missing: "
						.. table.concat(left, ", "),
					vim.log.levels.WARN
				)
			end
		end)
	)
	vim.notify(
		(
			"Compiling %d tree-sitter parser(s) in the background; "
			.. ":e applies them once done."
		):format(#absent)
	)
end

return M
