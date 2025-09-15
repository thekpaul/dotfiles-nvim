--[=[
Small utilities that earn their keep without a category of their own.
--]=]

-- Case-preserving substitution (:S) and case-coercion operators.
local abolish = { "tpope/vim-abolish" }

abolish.event = "VeryLazy"

-- Time tracking, loaded only when a UI attaches:
-- a fresh installation gets its API-key prompt in a real session, while
-- headless runs (CI, scripts) never load the plugin at all.
local wakatime = { "wakatime/vim-wakatime" }

wakatime.event = "UIEnter"

return { abolish, wakatime }
