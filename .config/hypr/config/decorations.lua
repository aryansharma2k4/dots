local config_dir = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
local mode_file = io.open(config_dir .. "/quickshell/theme-mode", "r")
local mode = mode_file and mode_file:read("*l") or "dark"

if mode_file then
    mode_file:close()
end

local colors = {}
local palette = io.open((os.getenv("HOME") .. "/.wall/wp_rice_") .. (mode == "light" and "light" or "dark") .. ".txt", "r")

if palette then
    for line in palette:lines() do
        local key, value = line:match("^([%w_]+)=(#%x%x%x%x%x%x)$")
        if key then
            colors[key] = value:sub(2)
        end
    end
    palette:close()
end

local active_border = colors.dark_accent or "4B3D43"
local inactive_border = colors.highlight or "CCB7A0"

hl.config({
    general = {
        gaps_in = 5,
        gaps_out = 8,
        -- No window border. The accent-coloured outline came from wp_rice's
        -- `dark_accent` (#89B4FA), which is why every window was ringed in
        -- blue. The two colours below are kept so restoring it is one number:
        -- set border_size back to 2.
        border_size = 0,
        resize_on_border = false,
        allow_tearing = false,
        layout = "dwindle",
        col = {
            active_border = "rgba(" .. active_border .. "ee)",
            inactive_border = "rgba(" .. inactive_border .. "aa)",
        },
    },
    decoration = {
        -- Matched to the dynamic island. Theme.qml sets radiusIsland = 12 on a
        -- plain QML Rectangle, whose corners are true quarter-circles, so the
        -- window corner has to match on both numbers: 12 for the radius, and
        -- rounding_power 2 for the curve. The previous 14/5 was a wider
        -- squircle -- flatter through the middle of the corner and turning
        -- harder at the ends -- which read as a different shape next to the
        -- island however close the radius got.
        rounding = 12,
        rounding_power = 2,
        active_opacity = 1,
        shadow = { enabled = false },
        blur = { enabled = true },
    },
    dwindle = { preserve_split = true },
    master = { new_status = "master", mfact = 0.7 },
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo = true,
        middle_click_paste = false,
    },
})
