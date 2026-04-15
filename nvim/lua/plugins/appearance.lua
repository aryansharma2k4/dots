return {
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      style = "night",
      transparent = false,
      on_colors = function(colors)
        colors.bg = "#000000"
        colors.bg_dark = "#000000"
        colors.bg_float = "#000000"
        colors.bg_popup = "#000000"
        colors.bg_sidebar = "#000000"
        colors.bg_statusline = "#000000"
      end,
      on_highlights = function(hl, colors)
        local black_groups = {
          "Normal",
          "NormalNC",
          "NormalFloat",
          "FloatBorder",
          "SignColumn",
          "EndOfBuffer",
          "StatusLine",
          "StatusLineNC",
          "TabLineFill",
          "WinSeparator",
        }

        for _, group in ipairs(black_groups) do
          hl[group] = { bg = colors.bg }
        end
      end,
    },
    config = function(_, opts)
      require("tokyonight").setup(opts)
      vim.opt.background = "dark"
      vim.cmd.colorscheme("tokyonight")
    end,
  },
}
