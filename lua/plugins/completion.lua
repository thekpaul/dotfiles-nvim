--[=[
Insert-mode completion through blink.cmp.

The LSP, snippet, buffer and path sources ship built-in, so
one plugin replaces the aggregator-and-adapters stack;
the friendly-snippets collection is the single optional extra,
feeding the snippets source.
Tagged releases carry a prebuilt fuzzy-matcher binary, so
no Rust toolchain is needed; without the binary
the pure-Lua matcher takes over after a warning instead of failing startup.
--]=]

local blink = { "saghen/blink.cmp" }

-- Optional collection for the built-in `snippets` source.
blink.dependencies = { "rafamadriz/friendly-snippets" }
-- A release tag is what makes the prebuilt matcher downloadable;
-- tracking `main` would require building it with a Rust toolchain.
blink.version = "1.*"
blink.opts = {
	keymap = {
		-- `<CR>` accepts, `<C-n>`/`<C-p>` select, `<C-Space>` opens the menu,
		-- `<Tab>`/`<S-Tab>` jump snippet stops;
		-- each key falls through to its built-in when the menu is closed.
		preset = "enter",
		-- `<C-c>` reverts the auto-inserted preview and closes the menu,
		-- replacing the preset's `<C-e>`, which is now suppressed.
		["<C-c>"] = { "cancel", "fallback" },
		["<C-e>"] = false,
		-- The preset's signature toggle would sit on `<C-k>`,
		-- shadowing digraph entry (`:h i_digraph`) in every insert context,
		-- not just LSP buffers: `show_signature` returns true
		-- whenever the module is enabled and its window is hidden, so
		-- the preset's `fallback` never runs.
		-- The window auto-shows on a trigger character and
		-- auto-hides with the signature context — no toggle is needed, and
		-- `<C-k>` keeps digraph entry by remaining unmapped.
		["<C-k>"] = false,
	},
	completion = {
		-- No preselection: `<CR>` only ever accepts an explicit choice, so
		-- a plain Enter still opens a new line.
		list = { selection = { preselect = false, auto_insert = true } },
	},
	-- Signature help, with no key claimed:
	-- the float auto-shows on a trigger character inside a call —
	-- the situation the insert-mode `<C-S>` default
	-- (`vim.lsp.buf.signature_help()`, shadowed by the save mapping) served —
	-- and hides when the signature context ends.
	signature = { enabled = true },
	-- Cmdline keys default to the `cmdline` preset, not `inherit`:
	-- restate the two deliberate insert-mode choices so both modes agree;
	-- the rest of that preset (native `<CR>`, `<Tab>`) stays untouched.
	cmdline = {
		keymap = {
			["<C-e>"] = false,
			["<C-c>"] = { "cancel", "fallback" },
		},
	},
}

return { blink }
