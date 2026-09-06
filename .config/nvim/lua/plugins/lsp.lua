-- ╭──────────────────────────────────────────────────────────────────────────╮
-- │  #9 -- intellisense for C, C++, JS, TS, Go, Python. No AI anywhere:      │
-- │  every completion below comes from a language server, a snippet, the      │
-- │  current buffer, or the filesystem. Nothing is sent off this machine.     │
-- │                                                                          │
-- │  nvim 0.12 configures servers natively -- vim.lsp.config() defines one    │
-- │  and vim.lsp.enable() attaches it. nvim-lspconfig is here only as the     │
-- │  library of default cmd/root_markers per server.                          │
-- ╰──────────────────────────────────────────────────────────────────────────╯
return {
  -- Mason installs the servers themselves into ~/.local/share/nvim/mason.
  {
    "mason-org/mason.nvim",
    cmd = { "Mason", "MasonInstall", "MasonUpdate" },
    build = ":MasonUpdate",
    opts = {
      ui = { border = "rounded", icons = { package_installed = "", package_pending = "", package_uninstalled = "" } },
    },
  },

  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "mason-org/mason.nvim",
      {
        "mason-org/mason-lspconfig.nvim",
        opts = {
          -- Installed on first launch into ~/.local/share/nvim/mason.
          -- gopls is deliberately absent: it needs the go toolchain, which is
          -- not installed on this machine. Install go, then :MasonInstall gopls
          -- and the config below picks it up with no further edit.
          ensure_installed = {
            "ts_ls", "basedpyright", "ruff", "lua_ls",
            "jsonls", "yamlls", "bashls", "neocmake",
          },
          -- This config calls vim.lsp.enable() itself, per server, from the
          -- `servers` table below. Letting mason-lspconfig also enable every
          -- installed server would start ones that were never configured here.
          automatic_enable = false,
        },
      },
      "saghen/blink.cmp",
    },
    opts = {
      -- ── diagnostics presentation ───────────────────────────────────────────
      diagnostics = {
        underline = true,
        update_in_insert = false,   -- do not shout while you are mid-word
        severity_sort = true,
        virtual_text = false,       -- tiny-inline-diagnostic draws these instead
        float = { border = "rounded", source = true, header = "", prefix = "" },
        signs = {
          text = {
            [vim.diagnostic.severity.ERROR] = " ",
            [vim.diagnostic.severity.WARN] = " ",
            [vim.diagnostic.severity.INFO] = " ",
            [vim.diagnostic.severity.HINT] = " ",
          },
        },
      },

      -- ── servers ────────────────────────────────────────────────────────────
      -- Keys are server names as nvim-lspconfig knows them; values are merged
      -- over that server's shipped defaults.
      servers = {
        -- C and C++.
        clangd = {
          cmd = {
            "clangd",
            "--background-index",
            "--clang-tidy",              -- lint as you type
            "--header-insertion=iwyu",   -- add the #include you actually need
            "--completion-style=detailed",
            "--function-arg-placeholders",
            "--fallback-style=llvm",
          },
          init_options = {
            usePlaceholders = true,
            completeUnimported = true,
            clangdFileStatus = true,
          },
        },

        -- TypeScript and JavaScript, including JSX/TSX.
        ts_ls = {
          settings = {
            typescript = {
              inlayHints = {
                includeInlayParameterNameHints = "literals",
                includeInlayFunctionParameterTypeHints = true,
                includeInlayVariableTypeHints = false,
                includeInlayPropertyDeclarationTypeHints = true,
                includeInlayFunctionLikeReturnTypeHints = true,
              },
            },
            javascript = {
              inlayHints = {
                includeInlayParameterNameHints = "literals",
                includeInlayFunctionParameterTypeHints = true,
                includeInlayFunctionLikeReturnTypeHints = true,
              },
            },
          },
        },

        -- Go. Needs the go toolchain on PATH -- see the note at the bottom.
        gopls = {
          settings = {
            gopls = {
              gofumpt = true,
              staticcheck = true,
              usePlaceholders = true,
              completeUnimported = true,
              analyses = { unusedparams = true, shadow = true, nilness = true, unusedwrite = true },
              hints = {
                assignVariableTypes = true,
                compositeLiteralFields = true,
                constantValues = true,
                functionTypeParameters = true,
                parameterNames = true,
                rangeVariableTypes = true,
              },
            },
          },
        },

        -- Python. basedpyright is pyright's maintained fork: same engine,
        -- more inlay hints, no licence friction.
        basedpyright = {
          settings = {
            basedpyright = {
              analysis = {
                typeCheckingMode = "standard",
                autoImportCompletions = true,
                diagnosticMode = "openFilesOnly",
                inlayHints = { variableTypes = true, callArgumentNames = true, functionReturnTypes = true },
              },
            },
          },
        },
        -- ruff handles the linting and import sorting basedpyright does not.
        ruff = {},

        -- Lua, so editing this config has completion for the vim API.
        lua_ls = {
          settings = {
            Lua = {
              runtime = { version = "LuaJIT" },
              workspace = { checkThirdParty = false },
              diagnostics = { globals = { "vim", "Snacks" } },
              hint = { enable = true, arrayIndex = "Disable" },
              telemetry = { enable = false },
              format = { enable = false },
            },
          },
        },

        jsonls = {},
        yamlls = {},
        bashls = {},
        neocmake = {},
      },
    },

    config = function(_, opts)
      vim.diagnostic.config(opts.diagnostics)

      -- Everything that should happen the moment a server attaches to a buffer.
      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("lsp_attach", { clear = true }),
        callback = function(ev)
          local buf = ev.buf
          local client = vim.lsp.get_client_by_id(ev.data.client_id)
          local function m(mode, lhs, rhs, desc)
            vim.keymap.set(mode, lhs, rhs, { buffer = buf, desc = "LSP: " .. desc, silent = true })
          end

          -- Navigation. The picker versions list every result rather than
          -- jumping blind to the first one.
          m("n", "gd", function() Snacks.picker.lsp_definitions() end, "Definition")
          m("n", "gD", vim.lsp.buf.declaration, "Declaration")
          m("n", "gr", function() Snacks.picker.lsp_references() end, "References")
          m("n", "gI", function() Snacks.picker.lsp_implementations() end, "Implementation")
          m("n", "gy", function() Snacks.picker.lsp_type_definitions() end, "Type definition")
          m("n", "<leader>cs", function() Snacks.picker.lsp_symbols() end, "Document symbols")
          m("n", "<leader>cS", function() Snacks.picker.lsp_workspace_symbols() end, "Workspace symbols")

          -- Reading and changing code.
          m("n", "K", function() vim.lsp.buf.hover({ border = "rounded" }) end, "Hover docs")
          m("n", "gK", function() vim.lsp.buf.signature_help({ border = "rounded" }) end, "Signature help")
          m("i", "<C-k>", function() vim.lsp.buf.signature_help({ border = "rounded" }) end, "Signature help")
          m({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, "Code action")
          -- <leader>cr is CompetiTest's "run testcases" (lua/plugins/competitive.lua)
          -- and that binding has to work in exactly the buffers clangd attaches
          -- to, so rename moves one key over rather than being shadowed here.
          m("n", "<leader>cn", vim.lsp.buf.rename, "Rename symbol")

          -- Inlay hints: parameter names and inferred types drawn inline.
          -- On by default for the languages whose servers provide them.
          if client and client:supports_method("textDocument/inlayHint") then
            vim.lsp.inlay_hint.enable(true, { bufnr = buf })
          end

          -- Highlight the other uses of the symbol under the cursor.
          if client and client:supports_method("textDocument/documentHighlight") then
            local hl_group = vim.api.nvim_create_augroup("lsp_highlight_" .. buf, { clear = true })
            vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
              group = hl_group, buffer = buf, callback = vim.lsp.buf.document_highlight,
            })
            vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
              group = hl_group, buffer = buf, callback = vim.lsp.buf.clear_references,
            })
          end
        end,
      })

      -- Hand blink.cmp's expanded capabilities to every server, so servers
      -- know this client supports snippets, resolve-on-demand documentation
      -- and the rest.
      local capabilities = require("blink.cmp").get_lsp_capabilities()

      for name, cfg in pairs(opts.servers) do
        cfg.capabilities = vim.tbl_deep_extend("force", capabilities, cfg.capabilities or {})
        vim.lsp.config(name, cfg)
        vim.lsp.enable(name)
      end
    end,
  },

  -- Diagnostics rendered as a rounded inline box next to the offending line,
  -- rather than as virtual text that runs off the edge of the screen.
  {
    "rachartier/tiny-inline-diagnostic.nvim",
    event = "LspAttach",
    priority = 800,
    opts = {
      preset = "modern",
      options = {
        show_source = { enabled = true, if_many = true },
        use_icons_from_diagnostic = true,
        multilines = { enabled = true, always_show = false },
        show_all_diags_on_cursorline = false,
        break_line = { enabled = true, after = 90 },
        virt_texts = { priority = 2048 },
      },
    },
  },

  -- Formatting on save, per language, from real formatters rather than the LSP.
  {
    "stevearc/conform.nvim",
    event = "BufWritePre",
    cmd = "ConformInfo",
    keys = {
      { "<leader>cf", function() require("conform").format({ async = true, lsp_format = "fallback" }) end, mode = { "n", "v" }, desc = "Format buffer" },
    },
    opts = {
      formatters_by_ft = {
        c = { "clang-format" },
        cpp = { "clang-format" },
        go = { "goimports", "gofumpt" },
        python = { "ruff_format", "ruff_organize_imports" },
        javascript = { "prettierd", "prettier", stop_after_first = true },
        typescript = { "prettierd", "prettier", stop_after_first = true },
        javascriptreact = { "prettierd", "prettier", stop_after_first = true },
        typescriptreact = { "prettierd", "prettier", stop_after_first = true },
        json = { "prettierd", "prettier", stop_after_first = true },
        jsonc = { "prettierd", "prettier", stop_after_first = true },
        yaml = { "prettierd", "prettier", stop_after_first = true },
        html = { "prettierd", "prettier", stop_after_first = true },
        css = { "prettierd", "prettier", stop_after_first = true },
        markdown = { "prettierd", "prettier", stop_after_first = true },
        lua = { "stylua" },
        sh = { "shfmt" },
        fish = { "fish_indent" },
      },
      format_on_save = function(bufnr)
        -- <leader>uf turns this off per-session or per-buffer, for when you are
        -- editing someone else's differently-formatted file.
        if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
          return
        end
        return { timeout_ms = 1500, lsp_format = "fallback" }
      end,
      default_format_opts = { lsp_format = "fallback" },
    },
    init = function()
      vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
      vim.api.nvim_create_user_command("FormatToggle", function(args)
        if args.bang then
          vim.b.disable_autoformat = not vim.b.disable_autoformat
        else
          vim.g.disable_autoformat = not vim.g.disable_autoformat
        end
        vim.notify("format on save: " .. tostring(not (vim.g.disable_autoformat or vim.b.disable_autoformat)))
      end, { bang = true, desc = "Toggle format on save (! for this buffer only)" })
      vim.keymap.set("n", "<leader>uf", "<cmd>FormatToggle<cr>", { desc = "Toggle format on save" })
    end,
  },

  -- Every diagnostic, reference, quickfix entry and todo in one navigable list.
  {
    "folke/trouble.nvim",
    cmd = "Trouble",
    opts = { focus = true, win = { border = "rounded" } },
    keys = {
      { "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", desc = "Diagnostics (project)" },
      { "<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", desc = "Diagnostics (buffer)" },
      { "<leader>xs", "<cmd>Trouble symbols toggle<cr>", desc = "Symbols outline" },
      { "<leader>xl", "<cmd>Trouble lsp toggle win.position=right<cr>", desc = "LSP references/defs" },
      { "<leader>xL", "<cmd>Trouble loclist toggle<cr>", desc = "Location list" },
      { "<leader>xq", "<cmd>Trouble qflist toggle<cr>", desc = "Quickfix list" },
    },
  },
}
