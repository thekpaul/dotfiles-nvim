--[=[
LaTeX editing with VimTeX.
Compilation wired to latexmk when existing; on machines without a TeX toolchain
the editing layer (motions, text objects, syntax) still works and
only the compile commands are absent.
--]=]

local vimtex = { "lervag/vimtex" }

-- VimTeX is a filetype plugin and lazy-loads itself:
-- startup only sources its ftdetect files and a small command shim (~0.5 ms);
-- the real work waits for a TeX buffer.
-- Manager-side lazy-loading is discouraged upstream — a filetype gate would
-- skip VimTeX's own ftdetect refinements and break during inverse search
-- called by PDF viewers through global `:VimtexInverseSearch`.
vimtex.lazy = false
vimtex.init = function()
	vim.g.vimtex_mappings_prefix = "<localleader>"
	-- Insert-mode symbol abbreviations (e.g. leader plus `a` for \alpha),
	-- expanded only inside math zones;
	-- moved from the default backtick leader to `@`.
	vim.g.vimtex_imaps_leader = "@"
	if vim.fn.executable("latexmk") == 1 then
		vim.g.vimtex_compiler_method = "latexmk"
	else
		vim.g.vimtex_compiler_enabled = 0
	end
	-- Keep source text readable: no concealment of markup.
	vim.g.vimtex_syntax_conceal_disable = 1
end

return { vimtex }
