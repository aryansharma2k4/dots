# dots

Source-of-truth dotfiles for my CachyOS / Hyprland desktop.

## Layout

- `.config/` — the real config files, tracked by git.
- `.zshrc`, `.bashrc`, `.bash_profile`, `.tmux.conf` — home-level shell configs.
- `setup.sh` — symlinks everything into `~/.config` and `~`.
- `sync.sh` — commit + push whatever changed.

## Managed configs

| | |
|---|---|
| **Compositor** | hypr (hyprland, hyprlock) |
| **Shell/bar** | quickshell |
| **Terminal** | kitty |
| **Shells** | fish, zsh, bash, tmux, starship |
| **Editors** | nvim, micro, zed |
| **Launcher** | fuzzel, vicinae |
| **Notifications** | mako, dunst |
| **Misc** | btop, fastfetch, scripts |

`.config/scripts/` holds the helper scripts the Hyprland keybinds call
(screenshots, wallpaper, power menu, theme switching, …).

## Theming

`.config/scripts/theme-mode.sh dark|light` flips every app at once by
re-pointing a symlink at `themes/<mode>.*` for kitty, fuzzel, mako and dunst,
and writing the mode for quickshell. Those generated symlinks are gitignored —
only the `themes/` sources are tracked.

## Apply on a new machine

```bash
git clone https://github.com/aryansharma2k4/dots.git ~/dots
cd ~/dots
./setup.sh
```

Existing configs are moved to `~/.config-backup-<timestamp>/` rather than
overwritten.

## Day-to-day

Because `~/.config/<app>` is a symlink into this repo, editing a config edits
the repo. To publish:

```bash
cd ~/dots && ./sync.sh "what changed"
```

or plain `git add -A && git commit && git push`.
