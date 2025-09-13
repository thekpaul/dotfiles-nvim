--[=[
Fuzzy finding through the snacks.nvim picker module.

snacks.nvim bundles quite a few quality-of-life modules behind one plugin;
only `picker` and `input` are enabled here.
The unused modules stay dormant — snacks loads a module on first use, so
the rest cost nothing, preventing any possible collisions with
our configuration's own statuscolumn or indent handling.
--]=]

local snacks = { "folke/snacks.nvim" }

-- snacks manages its own internal laziness; upstream asks for
-- an eager, high-priority load instead of lazy-loading the shell.
snacks.lazy = false
snacks.priority = 900
snacks.opts = {
	picker = {},
	-- input dresses vim.ui.input prompts (LSP rename and friends)
	-- in a floating box beside the cursor.
	input = {},
}

local function pick(lhs, source, desc)
	return {
		lhs,
		function()
			require("snacks").picker[source]()
		end,
		desc = desc,
	}
end

snacks.keys = {
	pick("<leader>ff", "files", "Find files"),
	pick("<leader>fg", "grep", "Live grep"),
	pick("<leader>fb", "buffers", "Find buffers"),
	pick("<leader>fh", "help", "Find help"),
	pick("<leader>fr", "recent", "Recent files"),
	pick("<leader>fd", "diagnostics", "Diagnostics"),
	pick("<leader>fD", "diagnostics_buffer", "Buffer diagnostics"),
	-- snacks.bufdelete removes a buffer while keeping the window
	-- that showed it; :bdelete would collapse that window.
	{
		"<leader>bd",
		function()
			require("snacks").bufdelete()
		end,
		desc = "Delete buffer",
	},
}

return { snacks }
