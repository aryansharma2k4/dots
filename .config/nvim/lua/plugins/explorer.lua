-- ╭──────────────────────────────────────────────────────────────────────────╮
-- │  #2 -- the folder tree on the left, the file on the right.               │
-- │                                                                          │
-- │  neo-tree opens automatically whenever nvim starts with a path (a file    │
-- │  or a directory), so `nvim .` and `nvim src/main.c` both land in the      │
-- │  two-pane layout. Bare `nvim` gets the dashboard instead.                 │
-- │                                                                          │
-- │  <leader>e / <C-e> jumps between the two panes -- see config/keymaps.lua. │
-- ╰──────────────────────────────────────────────────────────────────────────╯
return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    cmd = "Neotree",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",
    },
    init = function()
      -- Opening nvim on a directory should show the tree, not netrw's listing.
      vim.api.nvim_create_autocmd("BufEnter", {
        group = vim.api.nvim_create_augroup("neotree_dir", { clear = true }),
        callback = function(ev)
          if vim.fn.isdirectory(ev.match) == 1 then
            require("neo-tree")
          end
        end,
      })

      -- Auto-open beside the file you launched with.
      vim.api.nvim_create_autocmd("VimEnter", {
        group = vim.api.nvim_create_augroup("neotree_autoopen", { clear = true }),
        callback = function()
          local argc = vim.fn.argc()
          if argc == 0 then
            return -- no path given: the dashboard owns this screen
          end
          local target = vim.fn.argv(0)
          vim.schedule(function()
            if vim.fn.isdirectory(target) == 1 then
              -- `nvim .` -- tree only, focused, so you can pick a file.
              vim.cmd("Neotree filesystem left")
            else
              -- `nvim file` -- tree on the left, cursor stays in the file.
              vim.cmd("Neotree show filesystem left")
            end
          end)
        end,
      })
    end,
    opts = {
      close_if_last_window = true,   -- do not leave a lone sidebar behind
      popup_border_style = "rounded",
      enable_git_status = true,
      enable_diagnostics = true,
      sort_case_insensitive = true,

      default_component_configs = {
        indent = {
          with_markers = true,
          indent_marker = "│",
          last_indent_marker = "└",
          with_expanders = true,
          expander_collapsed = "",
          expander_expanded = "",
        },
        icon = { folder_closed = "", folder_open = "", folder_empty = "󰉖" },
        modified = { symbol = "●" },
        git_status = {
          symbols = {
            added = "", modified = "", deleted = "✖", renamed = "󰁕",
            untracked = "", ignored = "", unstaged = "󰄱", staged = "", conflict = "",
          },
        },
        -- Diagnostics counts on the folder that contains them, so an error
        -- three directories down is visible without expanding.
        diagnostics = {
          symbols = { hint = "󰌵", info = "", warn = "", error = "" },
        },
      },

      window = {
        position = "left",
        width = 32,
        mappings = {
          ["<space>"] = "none",        -- leader must reach the tree too
          ["l"] = "open",
          ["h"] = "close_node",
          ["<cr>"] = "open",
          ["o"] = "open",
          -- Open the file into a split on the right.
          ["s"] = "open_vsplit",
          ["S"] = "open_split",
          ["t"] = "open_tabnew",
          ["P"] = { "toggle_preview", config = { use_float = true } },
          ["a"] = { "add", config = { show_path = "relative" } },
          ["A"] = "add_directory",
          ["d"] = "delete",
          ["r"] = "rename",
          ["y"] = "copy_to_clipboard",
          ["x"] = "cut_to_clipboard",
          ["p"] = "paste_from_clipboard",
          ["c"] = "copy",
          ["m"] = "move",
          ["q"] = "close_window",
          ["R"] = "refresh",
          ["?"] = "show_help",
          ["<"] = "prev_source",
          [">"] = "next_source",
          ["H"] = "toggle_hidden",
          ["/"] = "fuzzy_finder",
          ["D"] = "fuzzy_finder_directory",
          ["#"] = "fuzzy_sorter",
          ["f"] = "filter_on_submit",
          ["<C-x>"] = "clear_filter",
          ["[g"] = "prev_git_modified",
          ["]g"] = "next_git_modified",
          -- Copy the path of the node under the cursor.
          ["Y"] = function(state)
            local node = state.tree:get_node()
            vim.fn.setreg("+", node.path)
            vim.notify(node.path, vim.log.levels.INFO, { title = "copied" })
          end,
        },
      },

      filesystem = {
        bind_to_cwd = false,
        cwd_target = { sidebar = "tab", current = "window" },
        -- Highlight the file you are editing as you move between buffers, so
        -- the tree always shows where you are in the project.
        follow_current_file = { enabled = true, leave_dirs_open = true },
        use_libuv_file_watcher = true,   -- pick up changes made outside nvim
        group_empty_dirs = true,
        filtered_items = {
          visible = false,
          hide_dotfiles = false,        -- dotfiles matter in a config repo
          hide_gitignored = true,
          hide_by_name = { "node_modules", ".git", "__pycache__", ".DS_Store" },
          never_show = { ".DS_Store", "thumbs.db" },
        },
      },

      buffers = {
        follow_current_file = { enabled = true },
        group_empty_dirs = true,
        show_unloaded = true,
      },

      git_status = {
        window = { position = "float" },
      },

      event_handlers = {
        -- Opening a file from the tree should hand focus to the file. Without
        -- this the cursor stays in the sidebar and every open needs a second
        -- keypress.
        {
          event = "file_opened",
          handler = function()
            require("neo-tree.command").execute({ action = "show" })
          end,
        },
      },
    },
  },
}
