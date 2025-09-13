--[=[
Statusline and tabline.
lualine draws a compact line matched to the seoul256 palette;
`showmode` is already off in the options module since
the statusline carries the mode indicator.
The tabline treats buffers as first-class citizens —
indexed, clickable, jumpable — with tabpages on the right.
--]=]

local lualine = { "nvim-lualine/lualine.nvim" }

lualine.dependencies = { "nvim-tree/nvim-web-devicons" }
lualine.opts = {
	options = {
		theme = "seoul256",
		section_separators = "",
		component_separators = "|",
	},
	sections = {
		-- Restating the default b trio:
		-- a provided section replaces the default wholesale, and
		-- only the branch icon changes.
		lualine_b = {
			{ "branch", icon = "" },
			"diff",
			"diagnostics",
		},
		lualine_c = { { "filename", path = 1 } },
		lualine_x = { "filetype" },
	},
	tabline = {
		-- mode 2 = show buffer name and position index together, so
		-- the <leader>b jumps below match what the line shows.
		lualine_a = { { "buffers", mode = 2 } },
		lualine_z = { "tabs" },
	},
}
lualine.config = function(_, opts)
	require("lualine").setup(opts)
	-- Jump straight to a buffer by its displayed tabline index —
	-- 0 goes to the last buffer; the bang keeps out-of-range presses silent.
	for i = 0, 9 do
		local pos = i == 0 and "$" or tostring(i)
		vim.keymap.set(
			"n",
			"<leader>b" .. i,
			("<Cmd>LualineBuffersJump! %s<CR>"):format(pos),
			{ desc = i == 0 and "Go to last buffer" or "Go to buffer " .. i }
		)
	end
end

return { lualine }
