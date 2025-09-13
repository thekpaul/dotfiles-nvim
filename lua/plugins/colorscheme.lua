--[=[
External Plugins for Colourschemes.
seoul256 is a muted 256-colour scheme that stays readable on both
dark and light terminals; the dark variant is the daily driver.

Every colorscheme spec shares one loading profile through `scheme()`, so
installing an alternative scheme later is a one-spec addition.
Comments are forced italic through a `ColorScheme` autocmd
rather than per-scheme options, so the tweak survives switching schemes.
--]=]

-- Shared profile for colorscheme plugins:
-- load eagerly, before every other plugin, so
-- highlight groups are final from the first frame.
local function scheme(spec)
	return vim.tbl_extend("force", { lazy = false, priority = 1000 }, spec)
end

-- Force italicised comments (pairs well with cursive fonts),
-- applied after any colorscheme loads.
vim.api.nvim_create_autocmd("ColorScheme", {
	group = vim.api.nvim_create_augroup("ItalicComments", { clear = true }),
	callback = function()
		local hl = vim.api.nvim_get_hl(0, { name = "Comment", link = false })
		hl = vim.tbl_extend("force", hl, { italic = true })
		vim.api.nvim_set_hl(0, "Comment", hl)
	end,
	desc = "Italicise comments after any colorscheme load",
})

local seoul256 = scheme({ "junegunn/seoul256.vim" })

seoul256.init = function()
	-- Dark-variant background shade: 233 (darkest) to 239.
	vim.g.seoul256_background = 234
end

seoul256.config = function()
	vim.cmd.colorscheme("seoul256")
end

return { seoul256 }
