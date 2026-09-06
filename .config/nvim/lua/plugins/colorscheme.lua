-- The bridge between nvim and the rest of the desktop. See lua/config/theme.lua
-- for why tokyonight specifically, and for the live switching.
return {
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1001,      -- must load before anything that sets a highlight
    opts = {
      style = "night",    -- the darkest variant; matches kitty's #000000 ground
      light_style = "day",
      -- Transparent so hyprland's blur and kitty's 0.90 background show through
      -- the editor the same way they show through the islands. <leader>ub
      -- toggles it if you ever want a solid ground.
      transparent = true,
      terminal_colors = true,
      styles = {
        comments = { italic = true },
        keywords = { italic = true },
        functions = { bold = true },
        variables = {},
        sidebars = "transparent",
        floats = "transparent",
      },
      sidebars = { "qf", "help", "neo-tree", "trouble", "dap-repl", "toggleterm" },
      dim_inactive = true,   -- the split you are not in recedes
      lualine_bold = true,

      on_colors = function(colors)
        -- Pull the four accents back to the exact values in Theme.qml, so a
        -- diagnostic underline in nvim is the same red as the topbar's danger
        -- tint and kitty's color1.
        colors.blue = "#7AA2F7"      -- Theme.accent
        colors.purple = "#BB9AF7"    -- Theme.accentAlt
        colors.green = "#9ECE6A"     -- Theme.success
        colors.yellow = "#E0AF68"    -- Theme.warning
        colors.red = "#F7768E"       -- Theme.danger
        colors.border = colors.blue
      end,

      on_highlights = function(hl, c)
        -- The window separator is the one line between splits. Dim enough to
        -- read as a seam rather than a border -- the hyprland window has no
        -- border any more, and this should not reintroduce one.
        hl.WinSeparator = { fg = c.bg_highlight, bold = false }
        -- Floating windows get a hairline in the accent, matching the islands'
        -- rim rather than a heavy frame.
        hl.FloatBorder = { fg = c.blue, bg = "NONE" }
        hl.NormalFloat = { bg = "NONE" }
        -- Line numbers: the current one in the accent, the rest well back, so
        -- the relative counts read as a ruler and not as content.
        hl.CursorLineNr = { fg = c.blue, bold = true }
        hl.LineNr = { fg = c.fg_gutter }
        hl.CursorLine = { bg = c.bg_highlight }
        -- Treesitter context (the sticky function header) should not look like
        -- a selected line.
        hl.TreesitterContext = { bg = c.bg_highlight }
        hl.TreesitterContextLineNumber = { fg = c.fg_gutter }
      end,
    },
    config = function(_, opts)
      require("tokyonight").setup(opts)
      local theme = require("config.theme")
      theme.apply(theme.read(), true)
      theme.watch()
    end,
  },
}
