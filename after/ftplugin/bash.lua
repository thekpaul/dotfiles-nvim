--[=[
Bash scripts: four-space indentation,
the style shared across this dotfiles collection's shell modules.
Foreign hard tabs — system scripts arrive here via the shebang split —
display at the conventional eight columns.
--]=]

vim.opt_local.expandtab = true
vim.opt_local.shiftwidth = 4
vim.opt_local.tabstop = 8
vim.opt_local.softtabstop = 4
vim.opt_local.textwidth = 80
