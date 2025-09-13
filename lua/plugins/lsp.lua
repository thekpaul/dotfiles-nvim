--[=[
Language servers, configured through the native vim.lsp.config() surface:
nvim-lspconfig supplies the base definitions,
mason.nvim provides the installer for the server binaries themselves, and
mason-lspconfig enables whatever Mason has installed.
--]=]

local nvim_lspconfig = { "neovim/nvim-lspconfig" }

nvim_lspconfig.dependencies = {
	"mason-org/mason.nvim",
	"mason-org/mason-lspconfig.nvim",
	"saghen/blink.cmp",
}
nvim_lspconfig.event = { "BufReadPre", "BufNewFile" }
nvim_lspconfig.config = function()
	-- Mason first: mason-lspconfig's auto-enable below needs its registry, and
	-- servers spawn from the $PATH Mason prepends.
	require("mason").setup({
		ui = {
			border = "rounded",
			icons = {
				package_installed = "✓ ",
				package_pending = "➜ ",
				package_uninstalled = "✗ ",
			},
		},
	})

	-- Buffer-local mappings on attach.
	-- The 0.11 defaults already cover most of the surface;
	-- only additions live here.
	vim.api.nvim_create_autocmd("LspAttach", {
		group = vim.api.nvim_create_augroup("thekpaul.lsp", {}),
		callback = function(ev)
			local function bufmap(lhs, rhs, desc)
				vim.keymap.set("n", lhs, rhs, { buffer = ev.buf, desc = desc })
			end
			bufmap("gd", vim.lsp.buf.definition, "Go to definition")
			bufmap("gD", vim.lsp.buf.declaration, "Go to declaration")
			bufmap("<leader>ld", function()
				require("snacks").picker.lsp_definitions()
			end, "Pick definitions")
			bufmap("<leader>lD", function()
				require("snacks").picker.lsp_declarations()
			end, "Pick declarations")
			bufmap("<leader>lr", function()
				require("snacks").picker.lsp_references()
			end, "Pick references")
			bufmap("<leader>li", function()
				require("snacks").picker.lsp_implementations()
			end, "Pick implementations")
			bufmap("<leader>lt", function()
				require("snacks").picker.lsp_type_definitions()
			end, "Pick type definitions")
			bufmap("<leader>lh", function()
				local on = vim.lsp.inlay_hint.is_enabled({ bufnr = ev.buf })
				vim.lsp.inlay_hint.enable(not on, { bufnr = ev.buf })
			end, "Toggle inlay hints")
			-- Keep gq on Vim's comment-aware internal formatting;
			-- LSP formatting stays an explicit request instead.
			vim.bo[ev.buf].formatexpr = ""
			bufmap("<leader>lf", vim.lsp.buf.format, "LSP format buffer")
		end,
	})

	-- Completion capabilities for every server.
	vim.lsp.config("*", {
		capabilities = require("blink.cmp").get_lsp_capabilities(),
	})

	-- Auto-enable every Mason-installed server —
	-- including ones installed from the :Mason UI mid-session, which
	-- attach to already-open buffers without a restart.
	-- Runs after the configs above so enabled servers pick them up.
	require("mason-lspconfig").setup({})
end

return { nvim_lspconfig }
