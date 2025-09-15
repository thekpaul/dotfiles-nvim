--[=[
TeX sources: prose-style wrapping and spell checking;
indentation kept narrow for deeply nested environments.
--]=]

vim.opt_local.wrap = true
vim.opt_local.linebreak = true
vim.opt_local.spell = true
vim.opt_local.expandtab = true
vim.opt_local.shiftwidth = 2
vim.opt_local.softtabstop = 2
vim.opt_local.textwidth = 80

-- TeX control sequences count as keywords: `\` joins `iskeyword` so
-- word motions and keyword lookups treat `\alpha` as one token.
vim.opt_local.iskeyword:append("\\")
