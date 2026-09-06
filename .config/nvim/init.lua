-- ╭──────────────────────────────────────────────────────────────────────────╮
-- │  nvim                                                                    │
-- │                                                                          │
-- │  Colours come from ~/.config/quickshell/theme-mode, the same file the     │
-- │  topbar, kitty, dunst and fuzzel read, so SUPER+SHIFT+T retints this      │
-- │  editor live along with the rest of the desktop. See lua/config/theme.lua │
-- │                                                                          │
-- │  Layout:                                                                  │
-- │    config/options   vim settings                                          │
-- │    config/keymaps   every non-plugin binding                              │
-- │    config/autocmds  behaviour on events                                   │
-- │    config/theme     the live link to the system theme                     │
-- │    config/lazy      bootstraps lazy.nvim, which loads lua/plugins/*        │
-- ╰──────────────────────────────────────────────────────────────────────────╯

require("config.options")
require("config.lazy")
require("config.keymaps")
require("config.autocmds")
