--[=[
Language servers, configured through the native vim.lsp.config() surface:
nvim-lspconfig supplies the base definitions,
mason.nvim provides the installer for the server binaries themselves, and
mason-lspconfig enables whatever Mason has installed.
--]=]

-- Interpreter resolution for Python servers:
-- prefer an explicitly activated environment, then
-- well-known project-local environment layouts, then
-- whatever python3 is on PATH.
local function resolve_python(root)
	if vim.env.VIRTUAL_ENV then
		return vim.env.VIRTUAL_ENV .. "/bin/python"
	end
	for _, rel in ipairs({
		"/.venv/bin/python",
		"/.pixi/envs/default/bin/python",
	}) do
		local candidate = root .. rel
		if vim.uv.fs_stat(candidate) then
			return candidate
		end
	end
	return vim.fn.exepath("python3")
end

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

	vim.lsp.config("lua_ls", {
		-- Neovim-tailored settings through the documented on_init pattern:
		-- workspace .luarc declarations are kept, with no bleed-through;
		-- luarc-less workspaces and the Neovim config get the tailoring below.
		on_init = function(client)
			if client.workspace_folders then
				local path = client.workspace_folders[1].name
				if
					path ~= vim.fn.stdpath("config")
					and (
						vim.uv.fs_stat(path .. "/.luarc.json")
						or vim.uv.fs_stat(path .. "/.luarc.jsonc")
					)
				then
					return
				end
			end
			client.config.settings.Lua =
				vim.tbl_deep_extend("force", client.config.settings.Lua, {
					runtime = {
						version = "LuaJIT",
						path = { "lua/?.lua", "lua/?/init.lua" },
					},
					workspace = {
						checkThirdParty = false,
						-- ${3rd}/luv/library supplies the vim.uv typings
						-- that $VIMRUNTIME's meta files do not cover.
						library = {
							vim.env.VIMRUNTIME,
							"${3rd}/luv/library",
						},
					},
					diagnostics = { globals = { "vim" } },
				})
		end,
		-- Base table the tailoring above extends; kept explicit so
		-- the extend always has a Lua table to build on.
		settings = { Lua = {} },
	})

	vim.lsp.config("basedpyright", {
		before_init = function(_, config)
			local root = config.root_dir or vim.uv.cwd()
			config.settings =
				vim.tbl_deep_extend("force", config.settings or {}, {
					python = { pythonPath = resolve_python(root) },
				})
		end,
	})

	-- Auto-enable every Mason-installed server —
	-- including ones installed from the :Mason UI mid-session, which
	-- attach to already-open buffers without a restart.
	-- Runs after the configs above so enabled servers pick them up.
	require("mason-lspconfig").setup({
		ensure_installed = { "lua_ls" },
	})

	-- Nushell serves its language server from the shell binary itself
	-- (`nu --lsp`), requiring manual enabling.
	-- Guarded on binary existence to keep Nushell-less environments quiet.
	if vim.fn.executable("nu") == 1 then
		vim.lsp.enable("nushell")
	end
end

return { nvim_lspconfig }
