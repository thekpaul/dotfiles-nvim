--[=[
`gq` routing: prose to the internal formatter, code to the language server.

`vim.lsp.formatexpr()` is the obvious 'formatexpr', but servers format
code, not prose: `gq` over a comment block reflows badly or not at all,
while Vim's internal formatter understands 'comments', 'commentstring',
leaders and continuation lines. This module owns 'formatexpr' instead and
dispatches on what the requested lines actually are.

Each line is classified at its first non-blank character: tree-sitter
highlight captures where a highlighter is active (`@comment*` and
`@string.documentation`, so docstrings count as prose), and the
'commentstring' leader as the plain-syntax fallback. A line of code with
a trailing comment therefore counts as code, and a range containing any
code line is delegated whole to the server — never split. Prose-only
ranges format natively, wrapped at a per-filetype prose width.

Buffers without a capable server lose nothing: the delegated call
declines (returns non-zero) and Vim's internal formatting takes over at
the buffer's own 'textwidth'.
--]=]

local M = {}

-- Wrap width for prose (comments and docstrings), by filetype.
-- Filetypes without an entry wrap prose at the buffer's 'textwidth';
-- Python follows PEP 8: code at 79 columns, prose at 72.
M.prose_width = {
	python = 72,
}

-- Classify one (1-indexed) line as "prose", "code" or "blank".
local function classify(buf, lnum)
	local line = vim.api.nvim_buf_get_lines(buf, lnum - 1, lnum, true)[1]
	local col = line:find("%S")
	if not col then
		return "blank"
	end
	local ok, captures =
		pcall(vim.treesitter.get_captures_at_pos, buf, lnum - 1, col - 1)
	if ok and #captures > 0 then
		for _, capture in ipairs(captures) do
			if
				capture.capture:find("^comment")
				or capture.capture:find("^string%.documentation")
			then
				return "prose"
			end
		end
		return "code"
	end
	-- No highlighter, or nothing captured here: fall back to matching
	-- the 'commentstring' leader. Docstrings are indistinguishable from
	-- code in this mode and take the server path.
	local leader = vim.bo[buf].commentstring:match("^(.-)%%s")
	leader = leader and vim.trim(leader) or ""
	if leader ~= "" and vim.startswith(vim.trim(line), leader) then
		return "prose"
	end
	return "code"
end

-- The 'formatexpr' entry point (:h formatexpr): reads v:lnum, v:count
-- and v:char; returning 0 claims the formatting, and any non-zero return
-- declines, making Vim fall back to its internal comment-aware
-- formatting.
function M.formatexpr()
	-- Insert-mode auto-wrap stays native: cheap and comment-aware.
	if vim.v.char ~= "" then
		return 1
	end
	local buf = vim.api.nvim_get_current_buf()
	local first, count = vim.v.lnum, vim.v.count
	local prose = false
	for lnum = first, first + count - 1 do
		local kind = classify(buf, lnum)
		if kind == "code" then
			-- Returns non-zero itself when no attached server
			-- offers range formatting, so buffers without one
			-- keep stock behaviour.
			return vim.lsp.formatexpr()
		end
		prose = prose or kind == "prose"
	end
	if not prose then
		return 1 -- blank lines only
	end
	local saved = vim.bo[buf].textwidth
	local width = M.prose_width[vim.bo[buf].filetype] or saved
	if width == 0 or width == saved then
		return 1 -- the internal fallback already wraps correctly
	end
	-- Reflow under the prose width: `gw` ignores 'formatexpr' (:h gw),
	-- so driving the internal formatter from inside it cannot recurse.
	local view = vim.fn.winsaveview()
	vim.bo[buf].textwidth = width
	vim.api.nvim_win_set_cursor(0, { first, 0 })
	local ok = pcall(vim.cmd, ("silent keepjumps normal! %dgww"):format(count))
	vim.bo[buf].textwidth = saved
	vim.fn.winrestview(view)
	return ok and 0 or 1
end

return M
