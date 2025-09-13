--[=[
Plugin management through lazy.nvim.

Plugin specs live one file per concern under lua/plugins/.
An empty spec directory is a valid state —
fresh checkout before any spec lands, or a deliberately plugin-free profile —
so in that case this module loads nothing and stays silent
instead of warning on every startup.

Plugin versions deliberately track their upstream default branches:
the lazy-lock.json snapshot is not part of the repository (see .gitignore).
--]=]

local specdir = vim.fn.stdpath("config") .. "/lua/plugins"
if vim.fn.glob(specdir .. "/*.lua") == "" then
	return
end

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
	local out = vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"--branch=stable",
		"https://github.com/folke/lazy.nvim.git",
		lazypath,
	})
	if vim.v.shell_error ~= 0 then
		vim.notify("Failed to clone lazy.nvim:\n" .. out, vim.log.levels.ERROR)
		return
	end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
	spec = { { import = "plugins" } },
	change_detection = { notify = false },
	install = { colorscheme = { "default" } },
})
