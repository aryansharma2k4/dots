hl.window_rule({ name = "suppress-maximize", match = { class = ".*" }, suppress_event = "maximize" })
hl.window_rule({ name = "fix-xwayland-drags", match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false }, no_focus = true })

for _, rule in ipairs({
    { name = "float-pip", match = { title = "^(Picture-in-Picture)$" }, float = true, size = "960 540", move = "25%- 0" },
    { name = "float-media", match = { title = "^(imv|mpv|danmufloat|termfloat|nemo|ncmpcpp)$" }, float = true, size = "960 540", move = "25%- 0" },
    { name = "float-waydroid", match = { class = "^(Waydroid)$" }, float = true, size = "1280 720", center = true },
    { name = "float-pavucontrol", match = { class = "^(org.pulseaudio.pavucontrol|pavucontrol-qt)$" }, float = true },
    { name = "float-serashell-settings", match = { title = "^Serashell$" }, float = true, center = true },
    { name = "float-picture-in-picture", match = { class = "^()$", title = "^(Picture in picture)$" }, float = true },
    { name = "float-save-file", match = { class = "^()$", title = "^(Save File)$" }, float = true },
    { name = "float-open-file", match = { class = "^()$", title = "^(Open File)$" }, float = true },
    { name = "float-zen-pip", match = { class = "^(ZenBrowser)$", title = "^(Picture-in-Picture)$" }, float = true },
    { name = "float-blueman", match = { class = "^(blueman-manager)$" }, float = true },
    { name = "float-bitwarden", match = { class = "^(chrome-nngceckbapebfimnlniiiahkandclblb-Default)$" }, float = true },
    { name = "float-xdg-portal", match = { class = "^(xdg-desktop-portal-gtk|xdg-desktop-portal-kde|xdg-desktop-portal-hyprland)(.*)$" }, float = true },
    { name = "float-polkit", match = { class = "^(polkit-gnome-authentication-agent-1|hyprpolkitagent|org.org.kde.polkit-kde-authentication-agent-1)(.*)$" }, float = true },
    { name = "float-zenity", match = { class = "^(zenity)$" }, float = true },
    { name = "float-steam-updater", match = { class = "^()$", title = "^(Steam - Self Updater)$" }, float = true },
    { name = "float-dell-controller", match = { class = "^(python3)$", title = "^(Dell G Series Controller)$" }, float = true },
    { name = "float-thunar-rename", match = { class = "^(thunar)$", title = "^(Rename.*)$" }, float = true, size = "500 200" },
    { name = "float-thunar-progress", match = { class = "^(thunar)$", title = "^(File Operation Progress)$" }, float = true },
    { name = "float-thunar-confirm", match = { class = "^(thunar)$", title = "^(Confirm.*)$" }, float = true },
    { name = "float-thunar-question", match = { class = "^(thunar)$", title = "^(Question)$" }, float = true },
    { name = "float-thunar-create", match = { class = "^(thunar)$", title = "^(Create.*)$" }, float = true },
    { name = "float-thunar-properties", match = { class = "^(thunar)$", title = "^(Properties)$" }, float = true, size = "600 500" },
    { name = "center-thunar-dialogs", match = { class = "^(thunar)$", title = "^(Rename.*|File Operation Progress|Confirm.*|Question|Create.*|Properties)$" }, center = true },
}) do
    hl.window_rule(rule)
end

-- ---------------------------------------------------------------------------
-- Vicinae launcher
--
-- Vicinae normally puts itself on screen with the wlr-layer-shell protocol. A
-- layer surface positions itself, and `hl.layer_rule` has no `move`, so while
-- layer shell is on the launcher cannot be relocated from here at all. It is
-- therefore turned OFF in ~/.config/vicinae/settings.json
-- ("launcher_window": { "layer_shell": { "enabled": false } }), which makes it
-- an ordinary floating window that the rules below can place.
--
-- NOTE: the USE_LAYER_SHELL=0 environment variable does nothing on this build
-- (vicinae-bin 0.20.9) — the binary carries no such string; the config key
-- above is the switch that actually works.
--
-- Measured from a live window (`hyprctl clients`) rather than guessed:
--   class = "vicinae"   title = "Vicinae Launcher"   size = 770x480
--
-- `move` is a muParser expression: Hyprland exposes monitor_w/monitor_h and
-- window_w/window_h, so the window is centred exactly rather than by the
-- `50%-` shorthand, which subtracts the *whole* window width and lands left of
-- centre. 12px from the top puts it over where the Quickshell bar sits (the bar
-- starts at y=8 and is 46 tall); the bar retracts to make room — see
-- Theme.launcherHideEnabled in ~/.config/quickshell/Theme.qml.
--
-- Blur: there is no positive `blur` window rule, only `no_blur`. Window blur
-- comes from the global `decoration.blur.enabled = true` in decorations.lua and
-- applies to this window automatically now that it is a normal window, so the
-- quickshell-* layerrules in layers.lua are untouched and still only cover the
-- bar and its popups.
hl.window_rule({
    name = "vicinae-launcher",
    match = { class = "^(vicinae)$" },
    float = true,
    size = "770 480",
    move = "(monitor_w-window_w)/2 12",
    -- Compensation, NOT an equivalent: as a layer surface Vicinae held an
    -- exclusive keyboard grab, so it got every keystroke no matter what the
    -- compositor thought was focused. A regular window cannot take that grab.
    -- `stay_focused` keeps Hyprland from moving focus elsewhere while it is
    -- open, which covers the common case, but it is a focus policy rather than
    -- a grab: a global keybind still fires, and anything that force-activates
    -- another window can still steal input.
    stay_focused = true,
    border_size = 0,
    no_anim = true,
})

-- FALLBACK — layer shell ON.
-- To revert: set "layer_shell": { "enabled": true } in
-- ~/.config/vicinae/settings.json and swap which block below is commented.
-- With layer shell on, Vicinae centres itself and takes a real exclusive
-- keyboard grab, so there is nothing to position and nothing to compensate
-- for; the rule above must be commented out because `float`/`move` on a layer
-- surface simply never match. The only thing worth keeping is the blur, which
-- then has to come from a layerrule again rather than the global window blur:
--
-- hl.layer_rule({
--     name = "vicinae-blur",
--     match = { namespace = "vicinae" },
--     blur = true,
--     blur_popups = true,
--     ignore_alpha = 0.1,
-- })
