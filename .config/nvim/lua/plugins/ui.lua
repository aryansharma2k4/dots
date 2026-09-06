return {
  -- ── icons, shared by everything below ──────────────────────────────────────
  { "nvim-tree/nvim-web-devicons", lazy = true },
  { "MunifTanjim/nui.nvim", lazy = true },
  { "nvim-lua/plenary.nvim", lazy = true },

  -- ╭────────────────────────────────────────────────────────────────────────╮
  -- │  snacks -- the utility layer. Dashboard, picker, zen/zoom, indent       │
  -- │  guides, notifications, statuscolumn, scratch buffers, image preview.   │
  -- ╰────────────────────────────────────────────────────────────────────────╯
  {
    "folke/snacks.nvim",
    priority = 1000,   -- snacks health check requires >= 1000
    lazy = false,
    opts = {
      bigfile = { enabled = true },   -- disables treesitter/lsp past ~1.5MB so
                                      -- opening a huge log does not hang
      quickfile = { enabled = true }, -- render the file before plugins load

      -- Animated indent guides with the enclosing scope highlighted.
      indent = {
        enabled = true,
        indent = { char = "│", hl = "SnacksIndent" },
        scope = { char = "│", hl = "SnacksIndentScope", underline = false },
        animate = { enabled = true, duration = { step = 12, total = 180 } },
      },

      -- Underlines every other occurrence of the symbol under the cursor,
      -- using LSP references where available and treesitter otherwise.
      words = { enabled = true, debounce = 100 },

      -- Number + git sign + fold column, drawn as one unit so they cannot
      -- shift the text as diagnostics appear and disappear.
      statuscolumn = { enabled = true, folds = { open = true, git_hl = true } },

      -- Notifications, routed through noice below.
      notifier = { enabled = true, timeout = 2500, style = "compact" },

      -- Scrollbar-free smooth scrolling for the picker and other floats.
      scroll = { enabled = true },
      input = { enabled = true },     -- vim.ui.input as a float
      image = { enabled = true },     -- inline images -- kitty's graphics protocol

      picker = {
        enabled = true,
        ui_select = true,             -- vim.ui.select goes through the picker too
        layout = { preset = "telescope" },
        win = { input = { keys = { ["<Esc>"] = { "close", mode = { "n", "i" } } } } },
      },

      -- #5: zoom the current file to fill the window, hiding the tree.
      zen = {
        toggles = { dim = true, git_signs = false, diagnostics = false },
        win = { style = "zen", backdrop = { transparent = true, blend = 96 } },
      },

      dashboard = {
        enabled = true,
        preset = {
          header = [[
    ██████   ██████  ██████  ██   ██
   ██    ██ ██    ██ ██   ██ ██  ██
   ██    ██ ██    ██ ██   ██ █████
   ██    ██ ██    ██ ██   ██ ██  ██
    ██████   ██████  ██████  ██   ██
          ]],
          keys = {
            { icon = " ", key = "f", desc = "Find file", action = ":lua Snacks.dashboard.pick('files')" },
            { icon = " ", key = "n", desc = "New file", action = ":ene | startinsert" },
            { icon = " ", key = "g", desc = "Grep text", action = ":lua Snacks.dashboard.pick('live_grep')" },
            { icon = " ", key = "r", desc = "Recent files", action = ":lua Snacks.dashboard.pick('oldfiles')" },
            { icon = " ", key = "e", desc = "File tree", action = ":Neotree filesystem left" },
            { icon = " ", key = "c", desc = "Config", action = ":lua Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')})" },
            { icon = "󰒲 ", key = "l", desc = "Lazy", action = ":Lazy" },
            { icon = " ", key = "m", desc = "Mason", action = ":Mason" },
            { icon = " ", key = "q", desc = "Quit", action = ":qa" },
          },
        },
        sections = {
          { section = "header" },
          { section = "keys", gap = 1, padding = 1 },
          { section = "startup" },
        },
      },
    },
    keys = {
      -- #5 -- the two requested "make it fill the window" bindings.
      { "<leader>z", function() Snacks.zen.zoom() end, desc = "Zoom file to full window" },
      { "<leader>Z", function() Snacks.zen() end, desc = "Zen mode (zoom + dim)" },

      -- Picker: find things.
      { "<leader><space>", function() Snacks.picker.smart() end, desc = "Find file (smart)" },
      { "<leader>ff", function() Snacks.picker.files() end, desc = "Find files" },
      { "<leader>fg", function() Snacks.picker.git_files() end, desc = "Find git files" },
      { "<leader>fr", function() Snacks.picker.recent() end, desc = "Recent files" },
      { "<leader>fb", function() Snacks.picker.buffers() end, desc = "Buffers" },
      { "<leader>fc", function() Snacks.picker.files({ cwd = vim.fn.stdpath("config") }) end, desc = "Find in config" },
      { "<leader>/", function() Snacks.picker.grep() end, desc = "Grep project" },
      { "<leader>fw", function() Snacks.picker.grep_word() end, desc = "Grep word under cursor", mode = { "n", "x" } },
      { "<leader>fl", function() Snacks.picker.lines() end, desc = "Grep this buffer" },
      { "<leader>fh", function() Snacks.picker.help() end, desc = "Help pages" },
      { "<leader>fk", function() Snacks.picker.keymaps() end, desc = "Keymaps" },
      { "<leader>fd", function() Snacks.picker.diagnostics() end, desc = "Diagnostics" },
      { "<leader>fu", function() Snacks.picker.undo() end, desc = "Undo history" },
      { "<leader>fi", function() Snacks.picker.icons() end, desc = "Icons" },
      { "<leader>f:", function() Snacks.picker.command_history() end, desc = "Command history" },
      { "<leader>fR", function() Snacks.picker.resume() end, desc = "Resume last picker" },

      -- Git.
      { "<leader>gg", function() Snacks.lazygit() end, desc = "Lazygit" },
      { "<leader>gb", function() Snacks.picker.git_branches() end, desc = "Git branches" },
      { "<leader>gl", function() Snacks.picker.git_log() end, desc = "Git log" },
      { "<leader>gf", function() Snacks.picker.git_log_file() end, desc = "Git log (this file)" },
      { "<leader>gB", function() Snacks.gitbrowse() end, desc = "Open in browser", mode = { "n", "x" } },

      -- Misc.
      { "<leader>.", function() Snacks.scratch() end, desc = "Scratch buffer" },
      { "<leader>S", function() Snacks.scratch.select() end, desc = "Select scratch buffer" },
      { "<leader>un", function() Snacks.notifier.hide() end, desc = "Dismiss notifications" },
      { "<leader>nh", function() Snacks.notifier.show_history() end, desc = "Notification history" },
      { "<leader>bD", function() Snacks.bufdelete() end, desc = "Delete buffer, keep window" },
      { "<leader>cR", function() Snacks.rename.rename_file() end, desc = "Rename file" },
      { "]]", function() Snacks.words.jump(1, true) end, desc = "Next reference", mode = { "n", "t" } },
      { "[[", function() Snacks.words.jump(-1, true) end, desc = "Prev reference", mode = { "n", "t" } },
    },
    init = function()
      vim.api.nvim_create_autocmd("User", {
        pattern = "VeryLazy",
        callback = function()
          -- Debug helpers on the global, so `:lua dd(x)` pretty-prints anything.
          _G.dd = function(...) Snacks.debug.inspect(...) end
          _G.bt = function() Snacks.debug.backtrace() end

          -- Toggles, all under <leader>u, all shown in which-key.
          Snacks.toggle.option("spell", { name = "spelling" }):map("<leader>us")
          Snacks.toggle.option("wrap", { name = "wrap" }):map("<leader>uw")
          Snacks.toggle.option("relativenumber", { name = "relative numbers" }):map("<leader>uL")
          Snacks.toggle.diagnostics():map("<leader>ud")
          Snacks.toggle.line_number():map("<leader>ul")
          Snacks.toggle.treesitter():map("<leader>uT")
          Snacks.toggle.inlay_hints():map("<leader>uh")
          Snacks.toggle.indent():map("<leader>ug")
          Snacks.toggle.dim():map("<leader>uD")
          Snacks.toggle.zen():map("<leader>uz")
        end,
      })
    end,
  },

  -- ╭────────────────────────────────────────────────────────────────────────╮
  -- │  noice -- #8. The cmdline, messages and popupmenu redrawn as floats.   │
  -- │  `:wq`, `:Ex`, `:s///` are typed into a centred rounded box with the   │
  -- │  command syntax-highlighted, instead of on the bottom row. This is     │
  -- │  what lets options.lua set cmdheight = 0 and reclaim that row.         │
  -- ╰────────────────────────────────────────────────────────────────────────╯
  {
    "folke/noice.nvim",
    event = "VeryLazy",
    dependencies = { "MunifTanjim/nui.nvim" },
    opts = {
      cmdline = {
        view = "cmdline_popup",
        format = {
          cmdline = { pattern = "^:", icon = "", lang = "vim" },
          search_down = { kind = "search", pattern = "^/", icon = " ", lang = "regex" },
          search_up = { kind = "search", pattern = "^%?", icon = " ", lang = "regex" },
          filter = { pattern = "^:%s*!", icon = "", lang = "bash" },
          lua = { pattern = { "^:%s*lua%s+", "^:%s*lua%s*=%s*", "^:%s*=%s*" }, icon = "", lang = "lua" },
          help = { pattern = "^:%s*he?l?p?%s+", icon = "" },
        },
      },
      lsp = {
        -- Route LSP docs and signature help through treesitter-highlighted
        -- markdown, so hover text is syntax-coloured rather than plain.
        override = {
          ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
          ["vim.lsp.util.stylize_markdown"] = true,
          ["cmp.entry.get_documentation"] = true,
        },
        hover = { enabled = true },
        signature = { enabled = false },   -- blink.cmp draws its own
        progress = { enabled = true },     -- "indexing 42%" as a notification
      },
      presets = {
        bottom_search = false,     -- search prompt as a popup too
        command_palette = true,    -- cmdline and its results as one centred box
        long_message_to_split = true,
        inc_rename = true,
        lsp_doc_border = true,
      },
      routes = {
        -- Silence the messages that are pure noise on every save.
        { filter = { event = "msg_show", any = {
            { find = "%d+L, %d+B" },        -- "12L, 345B written"
            { find = "; after #%d+" },
            { find = "; before #%d+" },
            { find = "%d fewer lines" },
            { find = "%d more lines" },
            { find = "search hit BOTTOM" },
          } }, opts = { skip = true } },
      },
      views = {
        cmdline_popup = {
          position = { row = "40%", col = "50%" },
          size = { width = 68, height = "auto" },
          border = { style = "rounded", padding = { 0, 1 } },
          win_options = { winhighlight = { Normal = "NormalFloat", FloatBorder = "FloatBorder" } },
        },
        popupmenu = {
          relative = "editor",
          position = { row = "40%", col = "50%" },
          size = { width = 68, height = 10 },
          border = { style = "rounded", padding = { 0, 1 } },
        },
      },
    },
    keys = {
      { "<leader>nl", function() require("noice").cmd("last") end, desc = "Last message" },
      { "<leader>na", function() require("noice").cmd("all") end, desc = "All messages" },
      { "<leader>nd", function() require("noice").cmd("dismiss") end, desc = "Dismiss messages" },
      { "<S-Enter>", function() require("noice").redirect(vim.fn.getcmdline()) end, mode = "c", desc = "Redirect cmdline output" },
    },
  },

  -- ╭────────────────────────────────────────────────────────────────────────╮
  -- │  bufferline -- #7. Open files as tabs across the top.                  │
  -- ╰────────────────────────────────────────────────────────────────────────╯
  {
    "akinsho/bufferline.nvim",
    event = "VeryLazy",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      options = {
        mode = "buffers",
        themable = true,
        numbers = "ordinal",           -- the number to use with <leader>1..9
        close_command = "bdelete! %d",
        indicator = { style = "underline" },
        diagnostics = "nvim_lsp",
        diagnostics_indicator = function(_, _, diag)
          local s = {}
          if diag.error then table.insert(s, " " .. diag.error) end
          if diag.warning then table.insert(s, " " .. diag.warning) end
          return table.concat(s, " ")
        end,
        -- Leave a gap the width of the tree so the tabs line up with the file
        -- they belong to rather than running under the sidebar.
        offsets = {
          {
            filetype = "neo-tree",
            text = "  EXPLORER",
            text_align = "left",
            separator = true,
            highlight = "Directory",
          },
        },
        separator_style = "slant",
        show_buffer_close_icons = true,
        show_close_icon = false,
        always_show_bufferline = false,   -- hidden until there are 2+ files
        hover = { enabled = true, delay = 120, reveal = { "close" } },
        sort_by = "insert_after_current",
      },
    },
  },

  -- ── statusline ─────────────────────────────────────────────────────────────
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = function()
      return {
        options = {
          theme = "tokyonight",
          globalstatus = true,           -- one bar for all splits (laststatus=3)
          component_separators = { left = "", right = "" },
          section_separators = { left = "", right = "" },
          disabled_filetypes = { statusline = { "dashboard", "snacks_dashboard" } },
        },
        sections = {
          lualine_a = { { "mode", separator = { left = "" }, right_padding = 2 } },
          lualine_b = { { "branch", icon = "" }, { "diff", symbols = { added = " ", modified = " ", removed = " " } } },
          lualine_c = {
            { "filetype", icon_only = true, separator = "", padding = { left = 1, right = 0 } },
            { "filename", path = 1, symbols = { modified = " ●", readonly = " ", unnamed = "[No Name]" } },
          },
          lualine_x = {
            -- What noice is doing right now: a recording macro, a pending
            -- operator, the current search count.
            {
              function() return require("noice").api.status.mode.get() end,
              cond = function() return package.loaded["noice"] and require("noice").api.status.mode.has() end,
            },
            {
              "diagnostics",
              symbols = { error = " ", warn = " ", info = " ", hint = " " },
            },
            -- Which LSP servers are attached to this buffer.
            {
              function()
                local names = {}
                for _, c in pairs(vim.lsp.get_clients({ bufnr = 0 })) do
                  table.insert(names, c.name)
                end
                return #names > 0 and ("  " .. table.concat(names, " ")) or ""
              end,
            },
          },
          lualine_y = { { "progress" }, { "location" } },
          lualine_z = { { "o:encoding" }, { "filesize", separator = { right = "" }, left_padding = 2 } },
        },
        extensions = { "neo-tree", "lazy", "trouble", "toggleterm", "mason", "nvim-dap-ui" },
      }
    end,
  },

  -- ── which-key: the live keymap reference ───────────────────────────────────
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      preset = "modern",
      delay = function(ctx) return ctx.plugin and 0 or 350 end,
      win = { border = "rounded" },
      spec = {
        { "<leader>b", group = "buffer" },
        { "<leader>c", group = "code" },
        { "<leader>d", group = "debug" },
        { "<leader>f", group = "find/file" },
        { "<leader>g", group = "git" },
        { "<leader>L", group = "leetcode" },
        { "<leader>n", group = "notifications" },
        { "<leader>q", group = "quit/session" },
        { "<leader>t", group = "terminal/test" },
        { "<leader>u", group = "ui toggles" },
        { "<leader>w", group = "window" },
        { "<leader>x", group = "diagnostics" },
        { "[", group = "prev" },
        { "]", group = "next" },
      },
    },
    keys = {
      { "<leader>?", function() require("which-key").show({ global = false }) end, desc = "Buffer keymaps" },
    },
  },
}
