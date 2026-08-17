--[=[
Tree-sitter based highlighting and indentation for Neovim.

nvim-treesitter's rewritten main branch requires Neovim 0.12, while
the frozen master branch preserves the legacy API for Neovim 0.11.
lazy.nvim evaluates an import's condition before loading that module, so
only the matching generation enters the plugin graph.
--]=]
local modern = vim.fn.has("nvim-0.12") == 1
local active = not vim.g.vscode

return {
	{
		import = "plugins.treesitter.master",
		cond = active and not modern,
	},
	{
		import = "plugins.treesitter.main",
		cond = active and modern,
	},
}
