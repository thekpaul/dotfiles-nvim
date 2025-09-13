--[=[
Keymaps that rely on built-in functionality only.
Plugin-provided mappings live next to the plugin that owns them;
this module must keep working on a bare Neovim.

The leader keys are set here because this module loads before any plugin does —
mappings defined later all see the final values.
--]=]

vim.g.mapleader = " "
vim.g.maplocalleader = ","

local map = vim.keymap.set
local nx = { "n", "x" }

-- Interface ------------------------------------------------------------------
-- Strip trailing whitespace, then write — from either mode,
-- without disturbing the view, the jumplist or the last search pattern.
map({ "n", "i" }, "<C-s>", function()
	local view = vim.fn.winsaveview()
	vim.cmd("keepjumps keeppatterns %s/\\s\\+$//e")
	vim.cmd.update()
	vim.fn.winrestview(view)
end, { desc = "Strip trailing whitespace and write" })

-- Buffers --------------------------------------------------------------------
map("n", "<leader>bn", "<Cmd>bnext<CR>", { desc = "Next buffer" })
map("n", "<leader>bp", "<Cmd>bprevious<CR>", { desc = "Previous buffer" })

-- Editing --------------------------------------------------------------------
-- These overwrite built-in keys with same-intent wrappers:
-- each map still runs the built-in action, only adding behaviour around it.
-- Keep the visual selection when shifting indentation.
map("v", "<", "<gv", { desc = "Dedent and reselect" })
map("v", ">", ">gv", { desc = "Indent and reselect" })
-- Joins that hold the cursor (and marks) in place, beside the
-- stock `J`/`gJ` pair, whose jump to the join point stays available.
map("n", "<leader>j", function()
	local view = vim.fn.winsaveview()
	vim.cmd("normal! " .. vim.v.count1 .. "J")
	vim.fn.winrestview(view)
end, { desc = "Join line below, keep cursor" })
map("n", "<leader>J", function()
	local view = vim.fn.winsaveview()
	vim.cmd("normal! " .. vim.v.count1 .. "gJ")
	vim.fn.winrestview(view)
end, { desc = "Join without spaces, keep cursor" })

-- Line moves -----------------------------------------------------------------
-- Move the current line or selection down/up (unimpaired-style keys).
-- Count-aware: `3]e` moves three lines down, clamped at buffer edges.
map("n", "]e", function()
	local room = vim.api.nvim_buf_line_count(0) - vim.fn.line(".")
	local n = math.min(vim.v.count1, room)
	if n > 0 then
		vim.cmd("move +" .. n)
	end
end, { desc = "Move line down" })
map("n", "[e", function()
	local n = math.min(vim.v.count1, vim.fn.line(".") - 1)
	if n > 0 then
		vim.cmd("move -" .. (n + 1))
	end
end, { desc = "Move line up" })
map("x", "]e", function()
	return ":move '>+" .. vim.v.count1 .. "<CR>gv=gv"
end, { expr = true, silent = true, desc = "Move selection down" })
map("x", "[e", function()
	return ":move '<-" .. (vim.v.count1 + 1) .. "<CR>gv=gv"
end, { expr = true, silent = true, desc = "Move selection up" })

-- Registers ------------------------------------------------------------------
-- Black-hole variants: delete/change without touching any register.
map(nx, "<leader>d", '"_d', { desc = "Delete, keep registers" })
map(nx, "<leader>D", '"_D', { desc = "Delete to EOL, keep registers" })
map(nx, "<leader>c", '"_c', { desc = "Change, keep registers" })
map(nx, "<leader>C", '"_C', { desc = "Change to EOL, keep registers" })
-- Paste over a selection without losing the unnamed register: built-in
-- `v_P` already behaves this way, so simply alias it.
map("x", "<leader>p", "P", { desc = "Paste over selection, keep register" })
-- System clipboard access without setting 'clipboard' globally.
map(nx, "<leader>y", '"+y', { desc = "Yank to clipboard" })
-- Built-in line-wise `Y` on purpose, not the default `y$` mapping.
map("n", "<leader>Y", '"+Y', { desc = "Yank line to clipboard" })

-- Scrolling ------------------------------------------------------------------
-- Same-intent wrappers over built-in keys again:
-- keep the cursor centred while jumping through search hits and pages.
map("n", "n", "nzzzv", { desc = "Next match, centred" })
map("n", "N", "Nzzzv", { desc = "Previous match, centred" })
map("n", "<C-d>", "<C-d>zz", { desc = "Half page down, centred" })
map("n", "<C-u>", "<C-u>zz", { desc = "Half page up, centred" })
map("n", "<C-f>", "<C-f>zz", { desc = "Full page down, centred" })
map("n", "<C-b>", "<C-b>zz", { desc = "Full page up, centred" })

-- Terminal -------------------------------------------------------------------
-- Double-tap to leave terminal mode:
-- single <Esc> still reaches programs inside terminal after 'timeoutlen', so
-- TUIs that use <Esc> themselves keep working.
map("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })
