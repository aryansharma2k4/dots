# nvim

Built to match the rest of this desktop. Colours come from
`~/.config/quickshell/theme-mode` — the same file the topbar, kitty, dunst and
fuzzel read — so **SUPER+SHIFT+T retints nvim live**, in every running instance,
with no restart. See `lua/config/theme.lua`.

Leader is `<Space>`. Press it and wait: **which-key** shows every binding, so this
file is only for the things worth knowing up front.

## The six you asked for

| Key | Does |
|---|---|
| `<leader>e` or `<C-e>` | Jump between the file tree and the editor, both directions |
| `<C-\>` | Floating terminal, `cd`'d to the current file's directory |
| `<leader>z` | Zoom the file to fill the window (hides the tree) |
| `<leader>Z` | Zen mode — zoom plus dimming |
| `<Tab>` / `<S-Tab>` | Cycle the open files along the top |
| `:` | Cmdline as a centred popup (noice), syntax-highlighted, with completion |

`nvim file` opens tree-left/file-right. `nvim .` opens the tree focused.
Bare `nvim` gives the dashboard.

## Navigation

| Key | Does |
|---|---|
| `<leader><space>` | Smart find file |
| `<leader>/` | Grep the project |
| `<leader>ff` `<leader>fr` `<leader>fb` | Files / recent / buffers |
| `<leader>fk` | Search all keymaps |
| `s` | Flash jump — two chars then a label |
| `<C-h/j/k/l>` | Move between splits |
| `<leader>1`..`9` | Jump to that numbered tab |

## Code

| Key | Does |
|---|---|
| `gd` `gr` `gI` `gy` | Definition / references / implementation / type |
| `K` | Hover docs |
| `<leader>ca` `<leader>cr` | Code action / rename |
| `<leader>cf` | Format now |
| `<leader>xx` | All project diagnostics (trouble) |
| `]d` `[d` `]e` `[e` | Next/prev diagnostic, next/prev error |
| `<C-space>` | Grow selection by syntax node |
| `<leader>db` `<leader>dc` `<leader>du` | Breakpoint / start / debugger UI |

Completion is **LSP + snippets + path + buffer only** — no AI, nothing leaves the
machine. `<Tab>` picks, `<CR>` accepts, `<C-space>` forces the menu.

## Toggles

All under `<leader>u` — `ud` diagnostics, `uh` inlay hints, `uf` format-on-save,
`uw` wrap, `ug` indent guides, `ub` inline git blame, `uz` zen.

## Layout

```
init.lua              entry point
lua/config/
  options.lua         vim settings
  keymaps.lua         non-plugin bindings
  autocmds.lua        behaviour on events
  theme.lua           the live link to the system theme
  lazy.lua            bootstraps lazy.nvim
lua/plugins/          one file per concern; lazy.nvim imports them all
```

## Not installed on this machine

- **`go` / `gopls`** — Go support is configured but inert. `sudo pacman -S go`,
  then `:MasonInstall gopls`; the config picks it up with no edit.
- **`lazygit`** — `<leader>gg` needs it. `sudo pacman -S lazygit`.
  `<leader>gs` (fugitive) and the `<leader>h` gitsigns bindings work without it.
