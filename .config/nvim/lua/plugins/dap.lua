-- ╭──────────────────────────────────────────────────────────────────────────╮
-- │  Debugging -- breakpoints, stepping, variable inspection, all inside      │
-- │  nvim. Covers C/C++ (codelldb), Python (debugpy) and Go (delve).         │
-- │  The adapters install through Mason: :MasonInstall codelldb debugpy delve │
-- ╰──────────────────────────────────────────────────────────────────────────╯
return {
  {
    "mfussenegger/nvim-dap",
    keys = {
      { "<leader>db", function() require("dap").toggle_breakpoint() end, desc = "Toggle breakpoint" },
      { "<leader>dB", function() require("dap").set_breakpoint(vim.fn.input("Condition: ")) end, desc = "Conditional breakpoint" },
      { "<leader>dc", function() require("dap").continue() end, desc = "Continue / start" },
      { "<leader>di", function() require("dap").step_into() end, desc = "Step into" },
      { "<leader>do", function() require("dap").step_over() end, desc = "Step over" },
      { "<leader>dO", function() require("dap").step_out() end, desc = "Step out" },
      { "<leader>dr", function() require("dap").repl.toggle() end, desc = "Toggle REPL" },
      { "<leader>dl", function() require("dap").run_last() end, desc = "Run last" },
      { "<leader>dt", function() require("dap").terminate() end, desc = "Terminate" },
      { "<leader>dh", function() require("dap.ui.widgets").hover() end, desc = "Inspect value", mode = { "n", "v" } },
    },
    dependencies = {
      {
        "rcarriga/nvim-dap-ui",
        dependencies = { "nvim-neotest/nvim-nio" },
        keys = {
          { "<leader>du", function() require("dapui").toggle({}) end, desc = "Toggle debugger UI" },
          { "<leader>de", function() require("dapui").eval() end, desc = "Eval expression", mode = { "n", "v" } },
        },
        opts = { floating = { border = "rounded" } },
        config = function(_, opts)
          local dap, dapui = require("dap"), require("dapui")
          dapui.setup(opts)
          -- Open the panels when a session starts, close them when it ends,
          -- so the debugger UI is never sitting there empty.
          dap.listeners.after.event_initialized["dapui"] = function() dapui.open({}) end
          dap.listeners.before.event_terminated["dapui"] = function() dapui.close({}) end
          dap.listeners.before.event_exited["dapui"] = function() dapui.close({}) end
        end,
      },
      -- The current value of every visible variable, drawn inline next to it
      -- while the program is paused.
      { "theHamsta/nvim-dap-virtual-text", opts = { commented = true } },
      { "mason-org/mason.nvim" },
    },
    config = function()
      local dap = require("dap")

      vim.fn.sign_define("DapBreakpoint", { text = "", texthl = "DiagnosticError", numhl = "" })
      vim.fn.sign_define("DapBreakpointCondition", { text = "", texthl = "DiagnosticWarn", numhl = "" })
      vim.fn.sign_define("DapStopped", { text = "", texthl = "DiagnosticInfo", linehl = "Visual", numhl = "" })
      vim.fn.sign_define("DapLogPoint", { text = "", texthl = "DiagnosticInfo", numhl = "" })

      local mason = vim.fn.stdpath("data") .. "/mason/bin/"

      -- ── C and C++ ──
      dap.adapters.codelldb = {
        type = "server",
        port = "${port}",
        executable = { command = mason .. "codelldb", args = { "--port", "${port}" } },
      }
      local cpp_cfg = {
        {
          name = "Launch (prompt for binary)",
          type = "codelldb",
          request = "launch",
          program = function()
            return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
          end,
          cwd = "${workspaceFolder}",
          stopOnEntry = false,
        },
      }
      dap.configurations.c = cpp_cfg
      dap.configurations.cpp = cpp_cfg
      dap.configurations.rust = cpp_cfg

      -- ── Python ──
      dap.adapters.python = {
        type = "executable",
        command = mason .. "debugpy-adapter",
      }
      dap.configurations.python = {
        {
          name = "Launch this file",
          type = "python",
          request = "launch",
          program = "${file}",
          cwd = "${workspaceFolder}",
          console = "integratedTerminal",
        },
      }

      -- ── Go ──
      dap.adapters.delve = {
        type = "server",
        port = "${port}",
        executable = { command = mason .. "dlv", args = { "dap", "-l", "127.0.0.1:${port}" } },
      }
      dap.configurations.go = {
        { name = "Debug this file", type = "delve", request = "launch", program = "${file}" },
        { name = "Debug package", type = "delve", request = "launch", program = "./${relativeFileDirname}" },
        { name = "Debug test", type = "delve", request = "launch", mode = "test", program = "./${relativeFileDirname}" },
      }
    end,
  },
}
