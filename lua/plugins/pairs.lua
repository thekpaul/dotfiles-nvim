--[=[
Character pairing: automatic closing pairs in insert mode, and
operators for adding, changing and deleting surrounding pairs.
--]=]

local autopairs = { "windwp/nvim-autopairs" }

autopairs.event = "InsertEnter"
autopairs.config = function()
	require("nvim-autopairs").setup({
		-- Respect treesitter nodes where parsers exist, so pairs
		-- are not inserted inside strings and comments blindly.
		check_ts = true,
		-- Providing this option replaces the default list wholesale,
		-- so restate it (snacks_picker_input keeps pairing out of
		-- picker prompts) before adding plain text buffers.
		disable_filetype = {
			"TelescopePrompt",
			"spectre_panel",
			"snacks_picker_input",
			"text",
		},
	})
	-- Typing a space just inside a bracket pair pads both sides,
	-- keeping the cursor centered: `(|)` plus space gives `( | )`.
	local rule = require("nvim-autopairs.rule")
	require("nvim-autopairs").add_rules({
		rule(" ", " "):with_pair(function(opts)
			local pair = opts.line:sub(opts.col - 1, opts.col)
			return vim.tbl_contains({ "()", "[]", "{}" }, pair)
		end),
	})
end

local surround = { "kylechui/nvim-surround" }

surround.event = { "BufReadPre", "BufNewFile" }
-- Normal-mode operator semantics work identically inside VS Code,
-- so this spec opts back in to loading there.
surround.cond = true
surround.opts = {}
-- The stock visual-mode `S` would clobber the built-in
-- linewise-change; keep that and take surround-the-selection to
-- `<leader>s` instead (`<leader>S` for delimiters on their own
-- lines). The flag must be set before the plugin loads, hence init.
surround.init = function()
	vim.g.nvim_surround_no_visual_mappings = true
end
surround.keys = {
	{
		"<leader>s",
		"<Plug>(nvim-surround-visual)",
		mode = "x",
		desc = "Surround selection",
	},
	{
		"<leader>S",
		"<Plug>(nvim-surround-visual-line)",
		mode = "x",
		desc = "Surround selection, delimiters on own lines",
	},
}

return { autopairs, surround }
