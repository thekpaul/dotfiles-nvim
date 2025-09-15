-- Luacheck profile for a Neovim configuration:
-- LuaJIT standard library plus the editor-provided global.
std = "luajit"
globals = { "vim" }

-- Callback signatures may receive arguments a given handler does not use;
-- that is not a defect worth flagging.
unused_args = false

-- Keep every line, comments included, within the project's 79-character limit
-- (luacheck counts characters, not bytes).
max_line_length = 79
