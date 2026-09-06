-- Backdrop blur for the Quickshell shell surfaces.
--
-- QML cannot blur what is behind it, so the shell only paints a low-alpha tint;
-- the actual frost comes from the compositor, via these rules. Without them the
-- islands and popups read as flat translucent rectangles.
--
-- The namespace strings must stay in sync with WlrLayershell.namespace in
-- ~/.config/quickshell:
--   quickshell-bar   -> the three islands (islands/*.qml)
--   quickshell-popup -> every popup, including the control centre (components/HoverPopup.qml)
--
-- ignore_alpha is set below the shell's own fill alphas (0.42 bar / 0.55 popup)
-- so the blur is applied under the tint rather than skipped as "too transparent".
for _, layer in ipairs({ "quickshell-bar", "quickshell-popup" }) do
    hl.layer_rule({
        name = layer .. "-blur",
        match = { namespace = layer },
        blur = true,
        blur_popups = true,
        ignore_alpha = 0.1,
    })
end
