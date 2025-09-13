--[=[
Entry point for modularised personal Neovim configuration.

Everything of substance lives in Lua modules under `./lua/thekpaul/`, which
this file loads in a deliberate order.
The configuration is written directly against the Neovim 0.11 API surface and
makes no attempt to run on anything older.
--]=]
if vim.fn.has("nvim-0.11") == 0 then
	vim.notify(
		"This configuration targets Neovim 0.11 or newer; refusing to load.",
		vim.log.levels.ERROR
	)
	return
end

require("thekpaul.options")
require("thekpaul.filetype")
require("thekpaul.keymaps")
require("thekpaul.plugins")
