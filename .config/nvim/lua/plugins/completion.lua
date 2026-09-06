-- ╭──────────────────────────────────────────────────────────────────────────╮
-- │  Completion. Explicitly non-AI: the four sources are the language        │
-- │  server, snippets, the filesystem, and words already in your open        │
-- │  buffers. No model, no network, nothing leaves the machine.              │
-- │                                                                          │
-- │  blink.cmp rather than nvim-cmp: the matcher is a compiled Rust binary,   │
-- │  so filtering a few thousand LSP candidates stays well under a frame      │
-- │  even on a big C++ translation unit.                                     │
-- ╰──────────────────────────────────────────────────────────────────────────╯
return {
  {
    "saghen/blink.cmp",
    event = { "InsertEnter", "CmdlineEnter" },
    version = "1.*",   -- v2 is still moving; v1 is the stable line
    dependencies = {
      -- The community snippet collection, for every language below.
      { "rafamadriz/friendly-snippets" },
    },
    opts = {
      keymap = {
        preset = "none",
        -- Tab drives the menu when it is open and the snippet when one is
        -- active; otherwise it stays a real Tab, so indenting still works.
        ["<Tab>"] = { "select_next", "snippet_forward", "fallback" },
        ["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" },
        ["<Down>"] = { "select_next", "fallback" },
        ["<Up>"] = { "select_prev", "fallback" },
        ["<C-n>"] = { "select_next", "show" },
        ["<C-p>"] = { "select_prev", "show" },
        ["<CR>"] = { "accept", "fallback" },
        ["<C-y>"] = { "select_and_accept" },
        ["<C-e>"] = { "hide", "fallback" },
        ["<C-space>"] = { "show", "show_documentation", "hide_documentation" },
        ["<C-b>"] = { "scroll_documentation_up", "fallback" },
        ["<C-f>"] = { "scroll_documentation_down", "fallback" },
      },

      appearance = {
        nerd_font_variant = "mono",   -- matches kitty's JetBrainsMono Nerd Font
        use_nvim_cmp_as_default = false,
      },

      completion = {
        -- Nothing is preselected, so <CR> inserts a newline unless you have
        -- deliberately picked an item with Tab or C-n.
        list = { selection = { preselect = false, auto_insert = true } },

        menu = {
          border = "rounded",
          winblend = 0,
          scrollbar = false,
          draw = {
            treesitter = { "lsp" },   -- syntax-highlight the candidate text
            columns = {
              { "kind_icon" },
              { "label", "label_description", gap = 1 },
              { "kind", gap = 1 },
              { "source_name" },
            },
            components = {
              source_name = {
                width = { max = 12 },
                text = function(ctx) return "[" .. ctx.source_name:lower() .. "]" end,
                highlight = "BlinkCmpSource",
              },
            },
          },
        },

        documentation = {
          auto_show = true,
          auto_show_delay_ms = 150,
          window = { border = "rounded", winblend = 0 },
        },

        -- The greyed-out preview of what accepting would insert, inline.
        ghost_text = { enabled = true, show_with_menu = false },

        -- Auto-insert the parens/brackets a function signature implies.
        accept = { auto_brackets = { enabled = true } },
      },

      -- Function signature with the current parameter highlighted, live as you
      -- type the arguments.
      signature = {
        enabled = true,
        window = { border = "rounded", winblend = 0 },
      },

      sources = {
        default = { "lsp", "path", "snippets", "buffer" },
        providers = {
          lsp = { score_offset = 100 },      -- the server always outranks the rest
          snippets = { score_offset = 60 },
          path = { score_offset = 40, opts = { get_cwd = function(ctx)
            -- Complete paths relative to the file being edited, not nvim's cwd.
            return vim.fn.expand(("#%d:p:h"):format(ctx.bufnr))
          end } },
          buffer = { score_offset = 20 },
        },
      },

      fuzzy = {
        implementation = "prefer_rust_with_warning",
        frecency = { enabled = true },   -- what you pick often floats up
        use_proximity = true,            -- what is near the cursor floats up
        sorts = { "exact", "score", "sort_text" },
      },

      -- Completion in the : cmdline too, which pairs with noice's popup.
      cmdline = {
        enabled = true,
        keymap = {
          preset = "none",
          ["<Tab>"] = { "show", "select_next", "fallback" },
          ["<S-Tab>"] = { "show", "select_prev", "fallback" },
          ["<CR>"] = { "accept_and_enter", "fallback" },
          ["<C-e>"] = { "cancel" },
        },
        completion = { menu = { auto_show = true } },
      },
    },
    opts_extend = { "sources.default" },
  },
}
