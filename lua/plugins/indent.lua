--[=[
Indentation guides.
Thin scope-aware guides from indent-blankline; the current scope is
underlined by treesitter information where a parser is available and
degrades to plain guides where not.
--]=]

local indent_blankline = { "lukas-reineke/indent-blankline.nvim" }

indent_blankline.main = "ibl"
indent_blankline.event = { "BufReadPre", "BufNewFile" }
indent_blankline.opts = {
	indent = {
		-- tab_char keeps tab-indented files on the same thin guide;
		-- without it, ibl falls back to the listchars tab glyph.
		char = "▏",
		tab_char = "▏",
		highlight = { "NonText" },
	},
	whitespace = {
		remove_blankline_trail = false,
		highlight = { "IndentOdd", "IndentEven" },
	},
	scope = { highlight = "ScopeFG", show_start = false, show_end = false },
}
indent_blankline.config = function(_, opts)
	-- Alternating per-level background stripes behind indentation whitespace;
	-- defined here because ibl only takes group names.
	vim.api.nvim_set_hl(0, "IndentOdd", { ctermbg = 233, bg = "#181818" })
	vim.api.nvim_set_hl(0, "IndentEven", { ctermbg = 235, bg = "#303030" })
	-- seoul256's LineNr foreground without its background, so
	-- the scope guide keeps its hue while the stripes show through;
	-- the default IblScope would copy LineNr's background too.
	vim.api.nvim_set_hl(0, "ScopeFG", { ctermfg = 101, fg = "#999872" })
	require("ibl").setup(opts)

	-- Guides and stripes stay visible inside a selection, and
	-- the first column never picks up the Visual highlight, so
	-- hide the plugin for the duration of visual and select modes.
	local group = vim.api.nvim_create_augroup("thekpaul.ibl", {})
	vim.api.nvim_create_autocmd("ModeChanged", {
		group = group,
		pattern = "*:[vV\x16]*",
		command = "IBLDisable",
		desc = "Hide indent guides in visual modes",
	})
	vim.api.nvim_create_autocmd("ModeChanged", {
		group = group,
		pattern = "[vV\x16]*:*",
		command = "IBLEnable",
		desc = "Show indent guides outside visual modes",
	})
end

return { indent_blankline }
