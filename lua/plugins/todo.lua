--[=[
Highlighting and navigation for annotation comments (TODO, FIXME, WARN, etc.),
with project-wide search through the snacks picker.
--]=]

local todo_comments = { "folke/todo-comments.nvim" }

todo_comments.dependencies = { "nvim-lua/plenary.nvim" }
todo_comments.event = { "BufReadPre", "BufNewFile" }
todo_comments.opts = {}
todo_comments.keys = {
	{
		"<leader>tn",
		function()
			require("todo-comments").jump_next()
		end,
		desc = "Next annotation comment",
	},
	{
		"<leader>tp",
		function()
			require("todo-comments").jump_prev()
		end,
		desc = "Previous annotation comment",
	},
	-- Kept on this spec rather than the snacks one: loading
	-- todo-comments is what registers its snacks picker source.
	{
		"<leader>ft",
		function()
			require("snacks").picker.todo_comments()
		end,
		desc = "Find annotation comments",
	},
}

return { todo_comments }
