-- ╭──────────────────────────────────────────────────────────────────────────╮
-- │  #6 -- smooth cursor and smooth scrolling.                               │
-- ╰──────────────────────────────────────────────────────────────────────────╯
return {
  -- The cursor leaves a trail as it jumps, drawn with half-block glyphs so it
  -- works in a plain terminal. This is the neovide-style animation without
  -- needing a GUI -- and it stacks with kitty's own cursor_trail, which
  -- animates kitty's cursor between nvim's redraws.
  {
    "sphamba/smear-cursor.nvim",
    event = "VeryLazy",
    opts = {
      -- Speed. Higher stiffness = the head of the smear catches up faster;
      -- lower trailing_stiffness = the tail lingers longer. This pair reads as
      -- quick and liquid rather than laggy.
      stiffness = 0.8,
      trailing_stiffness = 0.5,
      stiffness_insert_mode = 0.7,
      trailing_stiffness_insert_mode = 0.7,
      damping = 0.8,
      damping_insert_mode = 0.8,
      distance_stop_animating = 0.5,

      -- Draw the smear over the line it crosses rather than clearing them.
      transparent_bg_fallback_color = "#000000",
      legacy_computing_symbols_support = false,
      smear_between_buffers = true,
      smear_between_neighbor_lines = true,
      scroll_buffer_space = true,
      smear_insert_mode = true,
      -- Terminal buffers redraw constantly; a smear there is just noise.
      filetypes_disabled = { "TelescopePrompt", "snacks_picker_input" },
    },
  },

  -- Scrolling that interpolates instead of jumping. Applies to <C-d>/<C-u>,
  -- zz/zt/zb and the mouse wheel, so a page-down reads as movement and you do
  -- not lose your place.
  {
    "karb94/neoscroll.nvim",
    event = "VeryLazy",
    opts = {
      mappings = { "<C-u>", "<C-d>", "<C-b>", "<C-f>", "<C-y>", "<C-e>", "zt", "zz", "zb" },
      hide_cursor = false,          -- keep the cursor visible so the smear shows
      stop_eof = true,
      respect_scrolloff = true,
      cursor_scrolls_alone = true,
      duration_multiplier = 0.6,    -- snappier than the default
      easing = "quadratic",
      performance_mode = false,
    },
    config = function(_, opts)
      -- <C-e> is the explorer toggle in this config, so it must not also
      -- scroll. Everything else keeps its animated version.
      opts.mappings = vim.tbl_filter(function(m) return m ~= "<C-e>" end, opts.mappings)
      require("neoscroll").setup(opts)
    end,
  },

  -- Jump anywhere on screen by typing two characters and then a label. Also
  -- upgrades f/t/F/T to work across lines with the same labelling.
  {
    "folke/flash.nvim",
    event = "VeryLazy",
    opts = {
      labels = "asdfghjklqwertyuiopzxcvbnm",
      search = { multi_window = true },
      jump = { autojump = false },
      label = { rainbow = { enabled = true, shade = 5 } },
      modes = {
        char = { jump_labels = true },
        search = { enabled = false },   -- leave / alone; noice owns that popup
      },
    },
    keys = {
      { "s", mode = { "n", "x", "o" }, function() require("flash").jump() end, desc = "Flash jump" },
      { "S", mode = { "n", "x", "o" }, function() require("flash").treesitter() end, desc = "Flash treesitter node" },
      { "r", mode = "o", function() require("flash").remote() end, desc = "Remote flash" },
      { "R", mode = { "o", "x" }, function() require("flash").treesitter_search() end, desc = "Treesitter search" },
      { "<c-s>", mode = { "c" }, function() require("flash").toggle() end, desc = "Toggle flash search" },
    },
  },
}
