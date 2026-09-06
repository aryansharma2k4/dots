-- ╭──────────────────────────────────────────────────────────────────────────╮
-- │  Live link to the system theme.                                          │
-- │                                                                          │
-- │  ~/.config/quickshell/theme-mode holds one word, "dark" or "light".      │
-- │  scripts/theme-mode.sh (SUPER+SHIFT+T) rewrites it, and the topbar,      │
-- │  kitty, dunst, fuzzel and mako all follow. This makes nvim follow too,   │
-- │  live, in every running instance -- no restart, no :colorscheme.         │
-- │                                                                          │
-- │  tokyonight is the right theme to bridge them: Theme.qml's accents       │
-- │  (#7AA2F7 accent, #BB9AF7 accentAlt, #9ECE6A success, #E0AF68 warning,   │
-- │  #F7768E danger) *are* Tokyo Night's palette, and kitty's themes were    │
-- │  built from those same five values.                                      │
-- ╰──────────────────────────────────────────────────────────────────────────╯

local M = {}

local mode_file = vim.fs.joinpath(
  vim.env.XDG_CONFIG_HOME or vim.fs.joinpath(vim.env.HOME, ".config"),
  "quickshell",
  "theme-mode"
)

M.current = nil

--- Read the mode file. Returns "dark" or "light"; defaults to dark if the file
--- is missing, which is what every other config in this desktop does.
function M.read()
  local ok, lines = pcall(vim.fn.readfile, mode_file)
  if not ok or not lines or not lines[1] then
    return "dark"
  end
  return vim.trim(lines[1]) == "light" and "light" or "dark"
end

--- Apply a mode. `force` re-applies even if unchanged, which is what the
--- transparency toggle needs after it flips vim.g.tokyonight_transparent.
function M.apply(mode, force)
  mode = mode or M.read()
  if mode == M.current and not force then
    return
  end
  M.current = mode
  vim.o.background = mode
  -- tokyonight ships one colorscheme name per variant rather than reading
  -- &background, so the variant has to be selected by name.
  pcall(vim.cmd.colorscheme, mode == "light" and "tokyonight-day" or "tokyonight-night")
end

--- Watch the file so the switch lands the instant the shell script writes it.
--- fs_event fires on the *directory* rather than the file for an atomic
--- rewrite (write-to-temp + rename), which is how most such scripts save, so
--- the watch is on the directory and filtered by name.
function M.watch()
  local dir = vim.fs.dirname(mode_file)
  local name = vim.fs.basename(mode_file)
  local handle = vim.uv.new_fs_event()
  if not handle then
    return
  end
  handle:start(dir, {}, function(err, fname)
    if err or (fname and fname ~= name) then
      return
    end
    vim.schedule(function()
      M.apply(M.read())
    end)
  end)

  -- A fs watch can be lost if the directory is replaced wholesale, so a cheap
  -- re-check whenever the window regains focus covers that case.
  vim.api.nvim_create_autocmd("FocusGained", {
    group = vim.api.nvim_create_augroup("theme_sync_focus", { clear = true }),
    callback = function()
      M.apply(M.read())
    end,
  })
end

vim.api.nvim_create_user_command("ThemeSync", function()
  M.apply(M.read(), true)
  vim.notify("theme: " .. M.current, vim.log.levels.INFO)
end, { desc = "Re-read ~/.config/quickshell/theme-mode and apply it" })

return M
