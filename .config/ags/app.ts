import app from "ags/gtk4/app"
import style from "./style.scss"
import { createControlPanel } from "./widget/Bar"

app.start({
  instanceName: "controlbar",
  css: style,
  requestHandler(argv, respond) {
    const panel = argv.at(0)
    const page = argv.at(1) as "wifi" | "bluetooth" | undefined

    if (!controlPanel || !page) {
      respond("invalid request")
      return
    }

    if (panel === "toggle") {
      controlPanel.toggle(page)
      respond("ok")
      return
    }

    if (panel === "show") {
      controlPanel.show(page)
      respond("ok")
      return
    }

    if (panel === "hide") {
      controlPanel.hide()
      respond("ok")
      return
    }

    respond("unknown request")
  },
  main() {
    const monitor = app.get_monitors()[0]
    if (!monitor) throw new Error("No monitor available for AGS control panels")

    controlPanel = createControlPanel(monitor)
    app.add_window(controlPanel.window)
  },
})

let controlPanel:
  | {
      window: ReturnType<typeof createControlPanel>["window"]
      show: ReturnType<typeof createControlPanel>["show"]
      hide: ReturnType<typeof createControlPanel>["hide"]
      toggle: ReturnType<typeof createControlPanel>["toggle"]
    }
  | undefined
