-- ╭──────────────────────────────────────────────────────────────────────────╮
-- │  Competitive programming                                                 │
-- │                                                                          │
-- │    CompetiTest   two keys, and nothing else to remember:                  │
-- │                    <leader>cp  pull the problem + every testcase from     │
-- │                                the browser                                │
-- │                    <leader>cr  compile and run against all of them        │
-- │                                                                          │
-- │    leetcode.nvim LeetCode as a nvim UI. <leader>L…, or `nvim leetcode`.  │
-- │                                                                          │
-- │  Layout of a problem folder — the root stays .cpp files only:             │
-- │                                                                          │
-- │      A.cpp  B.cpp  C.cpp        the solutions you edit                    │
-- │      input/A_1.in   A_2.in      testcase inputs                           │
-- │      output/A_1.out A_2.out     expected outputs                          │
-- │      bin/A  bin/B               compiled binaries, out of the way         │
-- │                                                                          │
-- │  CompetiTest stores both streams in one directory and cannot be           │
-- │  configured out of it, so the two functions that read and write those     │
-- │  files are replaced in `config` below. Everything else is stock.          │
-- ╰──────────────────────────────────────────────────────────────────────────╯

-- Where each kind of file lives, relative to the folder holding the .cpp.
local DIR = { input = "input", output = "output", bin = "bin" }

-- The directory of the file in a buffer. Every path below is built from this,
-- so a problem folder is self-contained and CompetiTest never reaches out of it.
local function problem_root(bufnr)
  return vim.api.nvim_buf_call(bufnr or 0, function()
    return vim.fn.expand("%:p:h")
  end)
end

-- mkdir -p for the three of them. Idempotent, so it is safe to call on every
-- run; the compiler needs bin/ to exist before it is handed `-o bin/A`.
local function ensure_dirs(bufnr)
  local root = problem_root(bufnr)
  for _, d in pairs(DIR) do
    vim.fn.mkdir(root .. "/" .. d, "p")
  end
  return root
end

-- The argument that opens leetcode.nvim's dashboard: `nvim leetcode`. Read
-- before the spec is returned, because whether the plugin is lazy depends on
-- whether it was the argument nvim started with.
local leet_arg = "leetcode"

return {
  -- ╭────────────────────────────────────────────────────────────────────────╮
  -- │  CompetiTest -- testcase runner for Codeforces/AtCoder/etc.            │
  -- │                                                                        │
  -- │  The whole workflow:                                                   │
  -- │    1. install the "Competitive Companion" browser extension            │
  -- │    2. open a problem, press the extension's + button                   │
  -- │    3. <leader>cp  -- writes A.cpp from the template, plus every        │
  -- │                     sample into input/ and output/                     │
  -- │    4. write the solution, <leader>cr to compile and run them all       │
  -- ╰────────────────────────────────────────────────────────────────────────╯
  {
    "xeluxee/competitest.nvim",
    dependencies = { "MunifTanjim/nui.nvim" },
    cmd = "CompetiTest",
    keys = {
      {
        "<leader>cp",
        function()
          ensure_dirs()
          vim.cmd("CompetiTest receive problem")
        end,
        desc = "CP: receive problem + testcases",
      },
      {
        "<leader>cr",
        function()
          -- The compiler is given `-o bin/A`; it will not create bin/ itself.
          ensure_dirs()
          vim.cmd("CompetiTest run")
        end,
        desc = "CP: run all testcases",
      },
    },
    opts = {
      -- ── build and run ──
      -- Binaries go to bin/ so the folder you actually look at is nothing but
      -- .cpp files. -O2 because a solution that TLEs at -O0 tells you nothing,
      -- and the sanitiser because the time to catch UB is while testing
      -- locally, not after a wrong-answer verdict.
      compile_command = {
        cpp = {
          exec = "g++",
          args = { "-std=c++20", "-O2", "-Wall", "-Wextra", "-Wshadow",
                   "-fsanitize=undefined", "-D_GLIBCXX_ASSERTIONS",
                   "$(FNAME)", "-o", "bin/$(FNOEXT)" },
        },
        c = { exec = "gcc", args = { "-std=c17", "-O2", "-Wall", "$(FNAME)", "-o", "bin/$(FNOEXT)" } },
        rust = { exec = "rustc", args = { "-O", "$(FNAME)", "-o", "bin/$(FNOEXT)" } },
      },
      run_command = {
        cpp    = { exec = "./bin/$(FNOEXT)" },
        c      = { exec = "./bin/$(FNOEXT)" },
        rust   = { exec = "./bin/$(FNOEXT)" },
        python = { exec = "python3", args = { "$(FNAME)" } },
      },

      -- Save before running, always. The most annoying possible failure here
      -- is testing the previous version of the file.
      save_current_file = true,
      save_all_files = false,

      -- ── testcase files ──
      -- One naming rule, used in both directories: <solution>_<n>, .in beside
      -- the input and .out beside the expected output. A.cpp's second sample
      -- is input/A_2.in and output/A_2.out, and nothing else in the folder can
      -- collide with it.
      --
      -- `testcases_directory` is left at "." on purpose: the io_files loader
      -- and writer are replaced in `config` below and take their paths from
      -- DIR instead. It still applies to the single-file fallback format.
      testcases_directory = ".",
      testcases_use_single_file = false,
      testcases_input_file_format = "$(FNOEXT)_$(TCNUM).in",
      testcases_output_file_format = "$(FNOEXT)_$(TCNUM).out",

      -- ── verdicts ──
      -- "squish" collapses runs of whitespace and newlines before comparing,
      -- which is what every judge does. The other builtin is "exact", which
      -- fails a correct solution over one stray trailing newline.
      output_compare_method = "squish",
      view_output_diff = true,
      maximum_time = 5000,   -- ms before a testcase is killed as TLE

      -- ── UI ──
      floating_border = "rounded",
      runner_ui = {
        interface = "popup",
        show_nu = true,
        show_rnu = false,
        mappings = {
          run_again = "R",
          run_all_again = "<C-r>",
          kill = "K",
          kill_all = "<C-k>",
          view_input = { "i", "I" },
          view_output = { "a", "A" },
          view_stdout = { "o", "O" },
          view_stderr = { "e", "E" },
          toggle_diff = "d",
          close = { "q", "<Esc>" },
        },
      },
      popup_ui = {
        total_width = 0.85,
        total_height = 0.85,
        -- The five window names are fixed: tc (the testcase list, with the
        -- TOTAL row added below), si/so (this run's stdin and stdout), eo
        -- (expected output), se (stderr — where the dbg() macro's output
        -- lands). Anything else here is a nil index at layout time.
        layout = {
          { 3, "tc" },
          { 4, { { 1, "so" }, { 1, "eo" } } },
          { 4, { { 1, "si" }, { 1, "se" } } },
        },
      },

      -- ── receiving from the browser ──
      -- Port 27121 is what Competitive Companion posts to; it is the
      -- extension's default and there is no reason to move it.
      companion_port = 27121,
      receive_print_message = true,
      -- One key means no prompts: the path is computed below and used, and
      -- new samples replace whatever a previous receive left behind rather
      -- than asking whether to keep both sets.
      received_problems_prompt_path = false,
      open_received_problems = true,
      replace_received_testcases = true,

      -- Problem names arrive as "A. Watermelon" — spaces, dots, and whatever
      -- else the judge felt like. Everything downstream (the binary in bin/,
      -- the testcase stems) is derived from this filename, so it is reduced to
      -- one uniform shape here: word characters and underscores, nothing else.
      received_problems_path = function(task, file_extension)
        local name = task.name
          :gsub("[^%w]+", "_")   -- any run of punctuation/space becomes one _
          :gsub("^_+", "")
          :gsub("_+$", "")
        return string.format("%s/%s.%s", vim.fn.getcwd(), name, file_extension)
      end,

      -- ── templates ──
      -- New problem files start from these instead of an empty buffer. The
      -- $(PROBLEM) modifier in them is filled in at creation time, which is
      -- why evaluate_template_modifiers is on.
      template_file = {
        cpp = vim.fn.stdpath("config") .. "/templates/competitive.cpp",
        py  = vim.fn.stdpath("config") .. "/templates/competitive.py",
      },
      evaluate_template_modifiers = true,
    },

    config = function(_, opts)
      require("competitest").setup(opts)

      local tcs = require("competitest.testcases")

      -- ── patch 1: input/ and output/ as separate directories ───────────────
      -- Stock CompetiTest keeps both streams in one directory, because its
      -- loader scans a single directory and matches on filename — a "/" in the
      -- filename format can never match. So the two functions that actually
      -- touch the disk are wrapped to do the same work twice, once per
      -- directory, and merge the result.
      --
      -- These two are the choke point on purpose: every route into testcase
      -- storage goes through them — the runner, the add/edit/delete UI, and
      -- the receiver, which writes its own way and would bypass a patch
      -- applied at the buffer level instead.
      --
      -- This is also the only reason .in and .out have different extensions:
      -- within a directory the loader tries the input pattern first, so two
      -- identical patterns would make every file in output/ load as an input.
      local load, write = tcs.io_files.load, tcs.io_files.write

      -- Files on disk count samples from 1, the way the judge prints them,
      -- while CompetiTest counts from 0 internally. The offset is applied on
      -- the way out and undone on the way in, so both halves stay consistent
      -- and nothing outside these two functions has to know.
      local FIRST = 1

      tcs.io_files.load = function(directory, input_match, output_match)
        -- The compiler is handed `-o bin/A` and will not create bin/ itself.
        -- Every run loads its testcases before it compiles, so this is the one
        -- place guaranteed to be reached first, whether the run started from
        -- <leader>cr or from :CompetiTest run typed by hand.
        vim.fn.mkdir(directory .. DIR.bin, "p")

        local ins  = load(directory .. DIR.input .. "/",  input_match, output_match)
        local outs = load(directory .. DIR.output .. "/", input_match, output_match)

        local tctbl = {}
        for n, tc in pairs(ins) do
          tctbl[n - FIRST] = { input = tc.input }
        end
        for n, tc in pairs(outs) do
          tctbl[n - FIRST] = tctbl[n - FIRST] or {}
          tctbl[n - FIRST].output = tc.output
        end
        return tctbl
      end

      tcs.io_files.write = function(directory, tctbl, input_format, output_format)
        vim.fn.mkdir(directory .. DIR.input, "p")
        vim.fn.mkdir(directory .. DIR.output, "p")

        -- Split the table in two. The half written into input/ carries no
        -- output field and vice versa, so neither pass can drop a file into
        -- the wrong directory: the writer deletes a file whose content is nil,
        -- and there is never one to delete.
        local ins, outs = {}, {}
        for n, tc in pairs(tctbl) do
          ins[n + FIRST]  = { input = tc.input }
          outs[n + FIRST] = { output = tc.output }
        end

        write(directory .. DIR.input .. "/",  ins,  input_format, output_format)
        write(directory .. DIR.output .. "/", outs, input_format, output_format)
      end

      -- ── patch 2: a total-time line under the testcase list ────────────────
      -- The results window prints one row per testcase and stops there. This
      -- appends a summary row: how many passed, how long every testcase took
      -- added up, and the slowest single one — which is the number that
      -- actually decides whether a solution fits the time limit.
      local RunnerUI = require("competitest.runner_ui")
      local update_ui = RunnerUI.update_ui
      local MARK = "TOTAL"

      RunnerUI.update_ui = function(self)
        update_ui(self)
        -- update_ui schedules its own redraw, so this has to be scheduled too
        -- in order to land after it rather than before.
        vim.schedule(function()
          local win = self.ui_visible and self.windows and self.windows.tc
          if not win or not win.bufnr or not vim.api.nvim_buf_is_valid(win.bufnr) then
            return
          end

          local count, done, correct, total, slowest = 0, 0, 0, 0, 0
          for _, tc in ipairs(self.runner.tcdata or {}) do
            -- The compile step shares the list but is not a testcase.
            if tc.tcnum ~= "Compile" then
              count = count + 1
              if tc.time and tc.time ~= -1 then
                total = total + tc.time
                slowest = math.max(slowest, tc.time)
              end
              if tc.status ~= "" and tc.status ~= "RUNNING" then done = done + 1 end
              if tc.status == "CORRECT" then correct = correct + 1 end
            end
          end
          if count == 0 then return end

          -- Same three columns as the rows above it: label, verdict, time.
          local line = string.format(
            "%-10s%-10s%.3f seconds   slowest %.3f",
            MARK, correct .. "/" .. count, total / 1000, slowest / 1000
          )

          local hl = "CompetiTestRunning"
          if done == count then
            hl = correct == count and "CompetiTestCorrect" or "CompetiTestWrong"
          end

          local bufnr = win.bufnr
          local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
          -- Replace the previous summary rather than stacking a new one under
          -- it: update_ui runs on every process event.
          local last = lines[#lines] or ""
          local from = vim.startswith(last, MARK) and #lines - 1 or #lines

          vim.bo[bufnr].modifiable = true

          -- CompetiTest numbers testcases from 0 internally; the files on disk
          -- are named from 1. Relabel the rows so the window and the folder
          -- agree. The number comes from tcdata, never from the text already
          -- in the buffer -- update_ui runs on every process event, and a
          -- relabel that read back its own output would count upwards forever.
          -- Only the first column is rewritten, and to exactly the same width,
          -- so the verdict highlights the render just placed at column 10 are
          -- left alone.
          for i, tc in ipairs(self.runner.tcdata) do
            if type(tc.tcnum) == "number" and lines[i] then
              vim.api.nvim_buf_set_text(bufnr, i - 1, 0, i - 1, 10,
                { string.format("%-10s", "TC " .. (tc.tcnum + 1)) })
            end
          end

          vim.api.nvim_buf_set_lines(bufnr, from, -1, false, { line })
          vim.api.nvim_buf_add_highlight(bufnr, -1, hl, from, 10, 10 + #(correct .. "/" .. count))
          vim.bo[bufnr].modifiable = false
        end)
      end

      -- The summary occupies a line in a window whose mappings turn the cursor
      -- row into a testcase index, so R/K on that row would index past the end
      -- of the list. Both take the same guard.
      local TCRunner = require("competitest.runner")
      for _, fn in ipairs({ "run_testcase", "kill_process" }) do
        local original = TCRunner[fn]
        TCRunner[fn] = function(self, tcindex, ...)
          if not self.tcdata or not self.tcdata[tcindex] then return end
          return original(self, tcindex, ...)
        end
      end
    end,
  },

  -- ╭────────────────────────────────────────────────────────────────────────╮
  -- │  leetcode.nvim                                                         │
  -- │                                                                        │
  -- │  First run needs a session cookie: `:Leet cookie` opens a prompt, and   │
  -- │  its "Sign in with browser" option walks you through pasting the        │
  -- │  LEETCODE_SESSION cookie from a logged-in browser tab. It is stored     │
  -- │  under ~/.local/share/nvim/leetcode and only needs doing once.          │
  -- ╰────────────────────────────────────────────────────────────────────────╯
  {
    "kawre/leetcode.nvim",
    -- The description pane renders LeetCode's HTML through treesitter.
    build = ":TSUpdate html",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      "folke/snacks.nvim",          -- the picker this config already uses
      "nvim-tree/nvim-web-devicons",
    },
    -- Load eagerly *only* when nvim was started as `nvim leetcode`; otherwise
    -- stay lazy and wait for :Leet or a <leader>L key.
    lazy = leet_arg ~= vim.fn.argv()[1],
    cmd = "Leet",
    keys = {
      { "<leader>Ll", "<cmd>Leet<cr>",             desc = "LeetCode: dashboard" },
      { "<leader>Lm", "<cmd>Leet menu<cr>",        desc = "LeetCode: menu" },
      { "<leader>Lq", "<cmd>Leet list<cr>",        desc = "LeetCode: problem list" },
      { "<leader>Ld", "<cmd>Leet daily<cr>",       desc = "LeetCode: daily question" },
      { "<leader>Lr", "<cmd>Leet run<cr>",         desc = "LeetCode: run testcases" },
      { "<leader>Ls", "<cmd>Leet submit<cr>",      desc = "LeetCode: submit" },
      { "<leader>Lc", "<cmd>Leet console<cr>",     desc = "LeetCode: console" },
      { "<leader>Li", "<cmd>Leet info<cr>",        desc = "LeetCode: question info" },
      { "<leader>LD", "<cmd>Leet desc<cr>",        desc = "LeetCode: toggle description" },
      { "<leader>Lt", "<cmd>Leet tabs<cr>",        desc = "LeetCode: open questions" },
      { "<leader>Lg", "<cmd>Leet lang<cr>",        desc = "LeetCode: change language" },
      { "<leader>LR", "<cmd>Leet random<cr>",      desc = "LeetCode: random question" },
      { "<leader>Ly", "<cmd>Leet yank<cr>",        desc = "LeetCode: yank solution" },
      { "<leader>Lo", "<cmd>Leet open<cr>",        desc = "LeetCode: open in browser" },
    },
    opts = {
      arg = leet_arg,
      -- C++ to match the rest of this setup (clangd, codelldb, the CompetiTest
      -- template above). `:Leet lang` switches it per question, and whatever
      -- you pick there sticks.
      lang = "cpp",

      -- Description on the left, code on the right — the same side the file
      -- tree is on, so the reading pane and the editor keep their positions.
      description = {
        position = "left",
        width = "40%",
        show_stats = true,
      },

      console = {
        open_on_runcode = true,
        dir = "row",
        size = { width = "90%", height = "75%" },
        result = { size = "60%" },
        testcase = { virt_text = true, size = "40%" },
      },

      -- q closes a pane, <CR> confirms. The rest of nvim's motions work
      -- normally inside these windows.
      keys = {
        toggle = { "q" },
        confirm = { "<CR>" },
        reset_testcases = "r",
        use_testcase = "U",
        focus_testcases = "H",
        focus_result = "L",
      },

      -- Pinned rather than left to auto-detection: snacks' picker is the one
      -- this config already loads, and naming it means a future change to the
      -- plugin's detection order cannot quietly move the question list to a
      -- different UI. "telescope" | "fzf-lua" | "mini-picker" are the others.
      picker = { provider = "snacks-picker" },

      -- Refresh the cached problem list once a day rather than on every open.
      cache = { update_interval = 60 * 60 * 24 },

      -- Images in descriptions need image.nvim + a terminal protocol; kitty
      -- can do it, but it is off here so a description never blocks on it.
      image_support = false,
    },
  },
}
