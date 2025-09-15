--[=[
Keymap discovery: which-key pops up pending-key help and
gives the `<leader>` prefixes their human-readable group names.
--]=]

local which_key = { "folke/which-key.nvim" }

which_key.event = "VeryLazy"
which_key.opts = {
	spec = {
		{ "<leader>b", group = "Buffers" },
		{ "<leader>f", group = "Find" },
		{ "<leader>g", group = "Git" },
		{ "<leader>gt", group = "Toggles" },
		{ "<leader>l", group = "LSP" },
		{ "<leader>t", group = "Todo" },
	},
}
which_key.keys = {
	{
		"<leader>?",
		function()
			require("which-key").show({ global = false })
		end,
		desc = "Buffer-local keymaps",
	},
}

return { which_key }
