return {
  -- ╭────────────────────────────────────────────────────────────────────────╮
  -- │  treesitter -- real syntax trees. Everything from the highlighting to  │
  -- │  the folds to flash's node-jumping to the sticky context header reads  │
  -- │  from these.                                                            │
  -- ╰────────────────────────────────────────────────────────────────────────╯
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "master",
    build = ":TSUpdate",
    event = { "BufReadPost", "BufNewFile" },
    cmd = { "TSUpdate", "TSInstall", "TSInstallInfo" },
    dependencies = { "nvim-treesitter/nvim-treesitter-textobjects" },
    opts = {
      ensure_installed = {
        "c", "cpp", "go", "gomod", "gosum", "python", "javascript", "typescript", "tsx",
        "lua", "luadoc", "vim", "vimdoc", "query", "regex",
        "bash", "fish", "json", "jsonc", "yaml", "toml", "markdown", "markdown_inline",
        "html", "css", "scss", "sql", "dockerfile", "make", "cmake", "diff", "gitcommit", "gitignore",
      },
      auto_install = true,
      highlight = { enable = true, additional_vim_regex_highlighting = false },
      indent = { enable = true },
      incremental_selection = {
        enable = true,
        keymaps = {
          -- Grow the selection one syntax node at a time: expression, then
          -- statement, then block, then function.
          init_selection = "<C-space>",
          node_incremental = "<C-space>",
          scope_incremental = false,
          node_decremental = "<bs>",
        },
      },
      textobjects = {
        select = {
          enable = true,
          lookahead = true,
          keymaps = {
            ["af"] = "@function.outer", ["if"] = "@function.inner",
            ["ac"] = "@class.outer", ["ic"] = "@class.inner",
            ["aa"] = "@parameter.outer", ["ia"] = "@parameter.inner",
            ["al"] = "@loop.outer", ["il"] = "@loop.inner",
            ["ai"] = "@conditional.outer", ["ii"] = "@conditional.inner",
            ["a/"] = "@comment.outer",
          },
        },
        move = {
          enable = true,
          set_jumps = true,
          goto_next_start = { ["]f"] = "@function.outer", ["]c"] = "@class.outer", ["]a"] = "@parameter.inner" },
          goto_previous_start = { ["[f"] = "@function.outer", ["[c"] = "@class.outer", ["[a"] = "@parameter.inner" },
        },
        swap = {
          enable = true,
          -- Reorder function arguments without retyping them.
          swap_next = { ["<leader>cx"] = "@parameter.inner" },
          swap_previous = { ["<leader>cX"] = "@parameter.inner" },
        },
      },
    },
    config = function(_, opts)
      require("nvim-treesitter.configs").setup(opts)
    end,
  },

  -- The enclosing function/class header pinned to the top of the window while
  -- you scroll inside a long body. The single most useful thing for reading
  -- a 200-line C++ method.
  {
    "nvim-treesitter/nvim-treesitter-context",
    event = "BufReadPost",
    opts = { max_lines = 3, multiline_threshold = 1, separator = "─", mode = "cursor" },
    keys = {
      { "<leader>ut", "<cmd>TSContextToggle<cr>", desc = "Toggle sticky context" },
      { "[x", function() require("treesitter-context").go_to_context() end, desc = "Jump to context" },
    },
  },

  -- Matching brackets in matching colours, so a deeply nested C++ template or
  -- a JS callback pyramid is readable at a glance.
  {
    "HiPhish/rainbow-delimiters.nvim",
    event = "BufReadPost",
    config = function()
      local rd = require("rainbow-delimiters")
      vim.g.rainbow_delimiters = {
        strategy = { [""] = rd.strategy["global"] },
        query = { [""] = "rainbow-delimiters", lua = "rainbow-blocks" },
        highlight = {
          "RainbowDelimiterBlue", "RainbowDelimiterYellow", "RainbowDelimiterViolet",
          "RainbowDelimiterGreen", "RainbowDelimiterCyan", "RainbowDelimiterOrange", "RainbowDelimiterRed",
        },
      }
    end,
  },

  -- Colour codes painted in their own colour, inline. Aimed at CSS and at
  -- editing the theme files in this very config.
  {
    "catgoose/nvim-colorizer.lua",
    -- Only the filetypes that actually contain colour literals. Attaching to
    -- every buffer cost ~35ms on a C++ file that can never contain one.
    ft = { "css", "scss", "sass", "html", "javascript", "typescript",
           "javascriptreact", "typescriptreact", "vue", "svelte",
           "lua", "conf", "kitty", "dosini", "yaml", "json", "toml" },
    opts = {
      user_default_options = {
        names = false,        -- do not colour the word "red" in prose
        css = true,
        -- tailwind's palette is a ~57ms table load pulled in at startup. Turn it
        -- back on if you start a tailwind project; nothing here uses one.
        tailwind = false,
        mode = "virtualtext",
        virtualtext = "󱓻",
      },
    },
  },

  -- Close brackets, quotes and tags as you type, treesitter-aware so it does
  -- not double up inside a string.
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    opts = { check_ts = true, fast_wrap = { map = "<M-e>" } },
  },
  {
    "windwp/nvim-ts-autotag",
    ft = { "html", "javascriptreact", "typescriptreact", "vue", "svelte", "xml", "markdown" },
    opts = {},
  },

  -- mini: two small, very high-traffic modules.
  {
    "echasnovski/mini.nvim",
    event = "VeryLazy",
    config = function()
      -- Surround: `gsa iw "` wraps a word in quotes, `gsd "` unwraps it,
      -- `gsr "'` swaps the quote style.
      require("mini.surround").setup({
        mappings = {
          add = "gsa", delete = "gsd", find = "gsf", find_left = "gsF",
          highlight = "gsh", replace = "gsr", update_n_lines = "gsn",
        },
      })
      -- Better a/i textobjects: `ci(` works from anywhere on the line, `cin(`
      -- targets the *next* parens.
      require("mini.ai").setup({ n_lines = 500 })
      -- Alignment: `gaip=` lines up a block of assignments on the equals sign.
      require("mini.align").setup()
    end,
  },

  -- TODO / FIXME / HACK / NOTE highlighted in the buffer and listed on demand.
  {
    "folke/todo-comments.nvim",
    event = "BufReadPost",
    opts = { signs = true },
    keys = {
      -- Telescope is not installed here; this greps the same tags through the
      -- snacks picker instead.
      { "<leader>ft", function()
          Snacks.picker.grep({ search = [[\b(TODO|FIXME|HACK|NOTE|PERF|WARNING)\b]], regex = true, live = false })
        end, desc = "Find TODOs" },
      { "<leader>xt", "<cmd>Trouble todo toggle<cr>", desc = "TODOs (trouble)" },
      { "]t", function() require("todo-comments").jump_next() end, desc = "Next TODO" },
      { "[t", function() require("todo-comments").jump_prev() end, desc = "Prev TODO" },
    },
  },

  -- Persist and restore the session per directory, so reopening a project
  -- brings back the same buffers, splits and folds.
  {
    "folke/persistence.nvim",
    event = "BufReadPre",
    opts = {},
    keys = {
      { "<leader>qs", function() require("persistence").load() end, desc = "Restore session" },
      { "<leader>ql", function() require("persistence").load({ last = true }) end, desc = "Restore last session" },
      { "<leader>qd", function() require("persistence").stop() end, desc = "Do not save session" },
    },
  },

  -- Project-wide find and replace with a live preview, backed by ripgrep.
  {
    "MagicDuck/grug-far.nvim",
    cmd = "GrugFar",
    opts = { headerMaxWidth = 80 },
    keys = {
      { "<leader>sr", function() require("grug-far").open({ transient = true }) end, mode = { "n", "v" }, desc = "Search and replace (project)" },
    },
  },
}
