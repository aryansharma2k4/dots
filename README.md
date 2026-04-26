# dots

Source-of-truth dotfiles repo for my desktop setup.

## Layout

- `.config/` contains the real config files tracked by git.
- `.local/bin/` is for user scripts and executables.
- `setup.sh` symlinks the tracked configs into `~/.config` and `~/.local/bin`.

## Managed configs

- ags
- btop
- cava
- fastfetch
- fish
- hypr
- hyprpaper
- kitty
- nvim
- quickshell
- rofi
- swaync
- waybar
- waypaper
- yazi

## Apply on a new machine

```bash
git clone <your-repo-url> ~/dots
cd ~/dots
./setup.sh
```
