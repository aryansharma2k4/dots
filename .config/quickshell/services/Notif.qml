pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import ".."

/*
 * The shell IS the notification daemon.
 *
 * Owning org.freedesktop.Notifications is what makes the island able to react
 * to a notification at all — there is no way to observe another daemon's
 * traffic, so swaync/dunst/mako have to be off for this to bind. See
 * ~/.config/hypr/config/autostart.lua.
 *
 * ── WHAT LIVES WHERE ───────────────────────────────────────────────────────
 *
 *   popups   the ones on screen right now, newest FIRST. popups[0] is what the
 *            island expands to show; popups[1..] are the cards stacked under it.
 *   history  a flat snapshot of everything that has arrived, newest first,
 *            capped at historyLimit. Snapshots, not Notification objects: the
 *            server destroys those on close, so anything the control centre
 *            still wants to draw afterwards has to have been copied out first.
 *
 * ── LIFETIME ───────────────────────────────────────────────────────────────
 *
 * A Notification arrives untracked and is destroyed the moment this handler
 * returns unless `tracked` is set, so that is the first thing done to it.
 * Removal is driven from the object's own `closed` signal rather than from the
 * call sites, so a notification the *app* withdraws (a music player replacing
 * its own popup, a build finishing) leaves the island exactly the same way one
 * the user dismissed does.
 */
Item {
    id: root

    // ---------------------------------------------------------------- state --
    property var popups: []
    property var history: []
    readonly property int historyLimit: 50

    readonly property int pending: popups.length
    // Not `top`: Item already has a FINAL property by that name.
    readonly property var current: popups.length > 0 ? popups[0] : null
    readonly property var overflow: popups.length > 1 ? popups.slice(1) : []

    // Do Not Disturb. Notifications still arrive and still land in history —
    // they just never take the island. Critical ones ignore it, which is the
    // whole point of the urgency flag.
    property bool dnd: false

    signal dismissedAll()

    // --------------------------------------------------------------- server --
    NotificationServer {
        id: server

        // Survive `qs ipc call shell reload` with the popups still on screen,
        // rather than dropping every in-flight notification on a config edit.
        keepOnReload: true

        actionsSupported: true
        actionIconsSupported: false
        bodySupported: true
        bodyMarkupSupported: true
        bodyImagesSupported: false
        bodyHyperlinksSupported: false
        imageSupported: true
        inlineReplySupported: true
        persistenceSupported: true

        onNotification: notification => root.receive(notification)
    }

    // -------------------------------------------------------------- intake --
    function receive(n) {
        // Must come first: an untracked notification is freed as soon as this
        // returns, and everything below holds on to it.
        n.tracked = true

        root.remember(n)

        // Removal has exactly one path in, whoever triggers it.
        n.closed.connect(function() { root.forget(n) })

        const critical = n.urgency === NotificationUrgency.Critical
        if (root.dnd && !critical) {
            // Silently filed. It is in history; it never takes the island.
            n.tracked = false
            return
        }

        const next = root.popups.slice()
        next.unshift(n)
        root.popups = next

        root.arm(n)
    }

    function forget(n) {
        const next = root.popups.filter(function(x) { return x !== n })
        if (next.length !== root.popups.length)
            root.popups = next
        delete root.deadlines[root.key(n)]
    }

    // ------------------------------------------------------------- expiry --
    // One sweep for every notification rather than a Timer each: the deadlines
    // are only ever compared, never counted down, so a single ticker is both
    // cheaper and immune to drift across suspend.
    property var deadlines: ({})

    function key(n) { return String(n.id) }

    function arm(n) {
        const critical = n.urgency === NotificationUrgency.Critical
        // Spec: -1 means "server decides", 0 means "never expire". Critical
        // notifications are never dismissed on a timer either — that is the
        // one class the user has to actually see.
        let ms = n.expireTimeout
        if (ms < 0)
            ms = critical ? 0 : Theme.notifTimeout
        if (ms <= 0 || critical)
            return
        root.deadlines[root.key(n)] = Date.now() + ms
    }

    // Hovering the island holds every countdown, so a notification cannot
    // expire out from under the pointer while it is being read or replied to.
    property bool held: false

    onHeldChanged: {
        if (held)
            return
        // Coming off a hold, everything gets its full time again rather than
        // the remainder it had when the pointer arrived.
        for (let i = 0; i < root.popups.length; i++)
            root.arm(root.popups[i])
    }

    Timer {
        interval: 250
        running: root.popups.length > 0
        repeat: true
        onTriggered: {
            if (root.held)
                return
            const now = Date.now()
            for (let i = 0; i < root.popups.length; i++) {
                const n = root.popups[i]
                const due = root.deadlines[root.key(n)]
                if (due !== undefined && now >= due) {
                    // expire() closes it, which comes back through `closed`.
                    n.expire()
                    return      // one per tick; the list just changed under us
                }
            }
        }
    }

    // ------------------------------------------------------------- history --
    function remember(n) {
        const next = root.history.slice()
        next.unshift({
            id: n.id,
            appName: n.appName || "Notification",
            summary: n.summary || "",
            body: n.body || "",
            image: n.image || "",
            appIcon: n.appIcon || "",
            desktopEntry: n.desktopEntry || "",
            urgency: n.urgency,
            time: new Date()
        })
        if (next.length > root.historyLimit)
            next.length = root.historyLimit
        root.history = next
    }

    function clearHistory() { root.history = [] }

    // -------------------------------------------------------------- actions --
    function dismiss(n) { if (n) n.dismiss() }

    function dismissAll() {
        // Copy first: dismiss() mutates `popups` through the closed handler.
        const all = root.popups.slice()
        for (let i = 0; i < all.length; i++)
            all[i].dismiss()
        root.dismissedAll()
    }

    // Bring a waiting notification to the front. The one it displaces is not
    // dismissed — it falls back into the queue, so promoting is a reorder and
    // never loses anything.
    function promote(n) {
        if (!n || root.popups.length === 0 || root.popups[0] === n)
            return
        const next = root.popups.filter(function(x) { return x !== n })
        next.unshift(n)
        root.popups = next
    }

    function invoke(n, action) {
        if (!action)
            return
        action.invoke()
        // `resident` is the app saying "keep me up after an action" — a media
        // player's next/previous buttons, say. Everything else goes away.
        if (n && !n.resident)
            n.dismiss()
    }

    function reply(n, text) {
        if (!n || !n.hasInlineReply || String(text).trim() === "")
            return
        n.sendInlineReply(text)
        n.dismiss()
    }

    function toggleDnd() { root.dnd = !root.dnd }

    // Icon for a notification with no image of its own, keyed off the app.
    function fallbackGlyph(appName) {
        const a = String(appName).toLowerCase()
        if (a.includes("discord") || a.includes("slack") || a.includes("telegram")
            || a.includes("signal") || a.includes("message")) return "󰭹"
        if (a.includes("mail") || a.includes("thunderbird")) return "󰇮"
        if (a.includes("spotify") || a.includes("music") || a.includes("player")) return "󰝚"
        if (a.includes("firefox") || a.includes("chrom") || a.includes("browser")) return "󰖟"
        if (a.includes("volume") || a.includes("audio")) return "󰕾"
        if (a.includes("battery") || a.includes("power")) return "󰁹"
        if (a.includes("screenshot") || a.includes("shot")) return "󰄀"
        return "󰂚"
    }
}
