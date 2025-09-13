--[=[
Directories as editable buffers through oil.nvim,
replacing netrw for both `nvim <directory>` and in-session browsing.
--]=]

local oil = { "stevearc/oil.nvim" }

oil.dependencies = { "nvim-tree/nvim-web-devicons" }
-- Loaded eagerly so `nvim <directory>` opens oil instead of netrw.
oil.lazy = false
oil.opts = {
	columns = { -- :help oil-columns
		"permissions",
		"size",
		{ "mtime", format = "%y/%m/%d %H:%M" },
		"icon",
	},
	view_options = { show_hidden = true },
	delete_to_trash = true, -- :help oil-trash
}
oil.keys = {
	{ "-", "<Cmd>Oil<CR>", desc = "Edit parent directory" },
}

return { oil }
