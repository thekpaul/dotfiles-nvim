--[=[
Git integration:
gitsigns for in-buffer change decoration and hunk operations,
fugitive for whole-repository porcelain when a hunk-level view is not enough.
--]=]

local gitsigns = { "lewis6991/gitsigns.nvim" }

gitsigns.event = { "BufReadPre", "BufNewFile" }
gitsigns.opts = {
	on_attach = function(bufnr)
		local gs = require("gitsigns")
		local function bufmap(mode, lhs, rhs, desc)
			vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
		end
		-- All git operations live on the <leader>g prefix and
		-- are named for the operation, not the backing plugin, so
		-- the backend can be swapped without retraining muscle memory.
		bufmap("n", "<leader>gn", function()
			gs.nav_hunk("next")
		end, "Next hunk")
		bufmap("n", "<leader>gp", function()
			gs.nav_hunk("prev")
		end, "Previous hunk")
		bufmap("n", "<leader>gs", gs.stage_hunk, "Stage hunk")
		bufmap("n", "<leader>gr", gs.reset_hunk, "Reset hunk")
		bufmap("v", "<leader>gs", function()
			gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
		end, "Stage selected lines")
		bufmap("v", "<leader>gr", function()
			gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
		end, "Reset selected lines")
		bufmap("n", "<leader>gS", gs.stage_buffer, "Stage buffer")
		-- Deprecated upstream, still supported: :h gitsigns.undo_stage_hunk()
		bufmap("n", "<leader>gu", gs.undo_stage_hunk, "Undo last stage-hunk")
		bufmap("n", "<leader>gR", gs.reset_buffer, "Reset buffer")
		bufmap("n", "<leader>gv", gs.preview_hunk, "Preview hunk")
		bufmap("n", "<leader>gb", function()
			gs.blame_line({ full = true })
		end, "Blame line")
		bufmap(
			"n",
			"<leader>gtb",
			gs.toggle_current_line_blame,
			"Toggle line blame"
		)
		bufmap("n", "<leader>gd", gs.diffthis, "Diff against index")
		bufmap("n", "<leader>gD", function()
			gs.diffthis("~")
		end, "Diff against HEAD")
		-- Deprecated upstream, still supported: :h gitsigns.toggle_deleted()
		bufmap("n", "<leader>gtd", gs.toggle_deleted, "Toggle deleted lines")
		bufmap({ "o", "x" }, "ih", gs.select_hunk, "Select hunk")
	end,
}

-- Fugitive loads eagerly: command triggers would miss its other entry points
-- (fugitive:// buffers, the .git/index status window,
-- per-buffer repository detection for its statusline hook), and
-- its plugin shim is thin —
-- the heavy autoload core only loads on first real use anyway.
local fugitive = { "tpope/vim-fugitive" }

fugitive.lazy = false

return { gitsigns, fugitive }
