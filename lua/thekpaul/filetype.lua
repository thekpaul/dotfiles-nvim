--[=[
Filetype detection beyond what Neovim ships, via `vim.filetype.add()`.

The main correction here is the shell split:
Bash and POSIX sh are different languages with different linting rules and
different indentation habits in the repositories this configuration serves, so
scripts are classified by their shebang
rather than lumped together under a single shell filetype.

The rest covers formats Neovim misses or misreads:
Bash login-shell dotfiles, Nushell, Verilog sources, and
EDA tool scripts (Cadence SKILL, Synopsys and Innovus Tcl setups).
--]=]

local function shell_by_shebang(path, bufnr)
	-- bufnr is nil when matching against bare contents (no buffer).
	local first = bufnr and vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1]
	if type(first) == "string" and first:find("^#!") then
		if first:find("bash") then
			return "bash"
		end
		return "sh"
	end
	-- No shebang: fall back on the extension alone.
	if path:find("%.bash$") then
		return "bash"
	end
	return "sh"
end

-- Treat `*.h` headers as C instead of the C++ default,
-- through the supported override knob (:h filetype-overrule) so
-- the built-in Objective-C content sniff stays active.
vim.g.c_syntax_for_h = 1

vim.filetype.add({
	extension = {
		nu = "nu",
		bash = "bash",
		sh = shell_by_shebang,
		-- Pin `*.v` as Verilog over the built-in guess (Verilog, Coq or V):
		-- see `M.v()` in `$VIMRUNTIME/lua/vim/filetype/detect.lua`.
		v = "verilog",
	},
	filename = {
		-- Bash login-shell dotfiles carry neither shebang nor extension.
		-- These exact names are load-bearing:
		-- Neovim's own filename entries classify them as `sh`, and
		-- built-in filename matches outrank any user pattern, so
		-- a same-key override is the only correction that works.
		[".bashrc"] = "bash",
		[".bash_profile"] = "bash",
		[".bash_aliases"] = "bash",
		[".bash_history"] = "bash",
		[".bash_logout"] = "bash",
	},
	pattern = {
		-- Suffixed variants of the above, e.g. `.bashrc.local`.
		-- Deliberately not `$`-anchored: a character class before `$`
		-- defeats the literal-suffix fast path for `vim.filetype` and
		-- the pattern never fires.
		[".*/%.bash[%w_%-.]+"] = "bash",
		-- Cadence SKILL init scripts: `.cdsinit` and suffixed variants.
		[".*/.*%.cdsinit.*"] = "skill",
		-- Any ssh client config, not just `~/.ssh/config`.
		[".*ssh/config"] = "sshconfig",
		-- EDA tool setup and command files are Tcl.
		[".*/.*%.synopsys_dc%.setup.*"] = "tcl",
		[".*/innovus%.cmd.*"] = "tcl",
	},
})
