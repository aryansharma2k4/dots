import { Astal, Gdk, Gtk } from "ags/gtk4"
import { For, createBinding, createState } from "ags"
import GLib from "gi://GLib?version=2.0"
import Network from "gi://AstalNetwork"
import Bluetooth from "gi://AstalBluetooth"

const VERTICAL = Gtk.Orientation.VERTICAL
const PANEL_TIMEOUT_MS = 5000

const network = Network.get_default()
const wifi = network.wifi
const bluetooth = Bluetooth.get_default()

const wifiEnabled = createBinding<boolean>(wifi, "enabled")
const wifiScanning = createBinding<boolean>(wifi, "scanning")
const wifiSsid = createBinding<string>(wifi, "ssid")
const wifiStrength = createBinding<number>(wifi, "strength")
const wifiAccessPoints = createBinding<Network.AccessPoint[]>(wifi, "accessPoints").as((aps) =>
  [...aps]
    .filter((ap) => Boolean(ap.ssid))
    .sort((a, b) => b.strength - a.strength),
)

const bluetoothPowered = createBinding<boolean>(bluetooth, "isPowered")
const bluetoothDevices = createBinding<Bluetooth.Device[]>(bluetooth, "devices").as((devices) =>
  [...devices].sort((a, b) => Number(b.connected) - Number(a.connected)),
)

const [wifiMessage, setWifiMessage] = createState("")
const [bluetoothMessage, setBluetoothMessage] = createState("")

function signalLabel(strength: number) {
  if (strength >= 80) return "Excellent"
  if (strength >= 60) return "Good"
  if (strength >= 40) return "Fair"
  if (strength >= 20) return "Weak"
  return "Very weak"
}

async function connectToAccessPoint(ap: Network.AccessPoint) {
  const savedConnections = ap.get_connections().length
  if (ap.requires_password && savedConnections === 0) {
    setWifiMessage(`Saved password required for ${ap.ssid}`)
    return
  }

  setWifiMessage(`Connecting to ${ap.ssid}...`)

  ap.activate(null, (_source, result) => {
    try {
      ap.activate_finish(result)
      setWifiMessage(`Connected to ${ap.ssid}`)
    } catch (error) {
      console.error(error)
      setWifiMessage(`Could not connect to ${ap.ssid}`)
    }
  })
}

function disconnectWifi() {
  setWifiMessage("Disconnecting...")

  wifi.deactivate_connection((_source, result) => {
    try {
      wifi.deactivate_connection_finish(result)
      setWifiMessage("Disconnected")
    } catch (error) {
      console.error(error)
      setWifiMessage("Could not disconnect")
    }
  })
}

async function toggleBluetoothDevice(device: Bluetooth.Device) {
  const name = device.alias || device.name || device.address
  setBluetoothMessage(device.connected ? `Disconnecting ${name}...` : `Connecting ${name}...`)

  try {
    if (device.connected) {
      await device.disconnect_device()
      setBluetoothMessage(`${name} disconnected`)
    } else {
      await device.connect_device()
      setBluetoothMessage(`${name} connected`)
    }
  } catch (error) {
    console.error(error)
    setBluetoothMessage(`Could not change ${name}`)
  }
}

function SectionTitle({ title, detail }: { title: string; detail?: string | ReturnType<typeof createState<string>>[0] }) {
  return (
    <box class="section-header">
      <label class="section-title" label={title} hexpand halign={Gtk.Align.START} />
      {detail ? <label class="section-detail" label={detail} /> : <box visible={false} />}
    </box>
  )
}

function WifiContent() {
  const wifiSummary = wifiEnabled((enabled) => {
    if (!enabled) return "Wi-Fi is turned off"
    const ssid = wifiSsid()
    if (ssid) return `${ssid} connected`
    if (wifiScanning()) return "Scanning for networks"
    return "Choose a network"
  })

  const wifiSignal = wifiStrength((strength) => `${signalLabel(strength)} • ${strength}%`)

  return (
    <box name="wifi" orientation={VERTICAL} class="popover-body">
      <SectionTitle title="Wi-Fi" detail={wifiEnabled((enabled) => (enabled ? "On" : "Off"))} />

      <box class="switch-row">
        <label label="Enable Wi-Fi" hexpand halign={Gtk.Align.START} />
        <switch
          active={wifiEnabled}
          onNotifyActive={({ active }) => {
            wifi.enabled = active
            setWifiMessage(active ? "Wi-Fi enabled" : "Wi-Fi disabled")
          }}
        />
      </box>

      <box class="status-card" orientation={VERTICAL}>
        <label class="status-title" label={wifiSummary} halign={Gtk.Align.START} />
        <label class="status-subtitle" label={wifiSignal} halign={Gtk.Align.START} visible={wifiEnabled} />
        <levelbar value={wifiStrength((strength) => strength / 100)} maxValue={1} visible={wifiEnabled} />
      </box>

      <box class="actions-row">
        <button
          class="secondary-button"
          sensitive={wifiEnabled}
          onClicked={() => {
            wifi.scan()
            setWifiMessage("Scanning for networks...")
          }}
        >
          <label label={wifiScanning((scanning) => (scanning ? "Scanning..." : "Refresh"))} />
        </button>
        <button
          class="secondary-button"
          sensitive={wifiEnabled(() => Boolean(wifiSsid()))}
          onClicked={disconnectWifi}
        >
          <label label="Disconnect" />
        </button>
      </box>

      <SectionTitle title="Networks" detail={wifiAccessPoints((aps) => `${aps.length}`)} />

      <scrolledwindow class="list-scroll" minContentHeight={240}>
        <box orientation={VERTICAL} class="item-list">
          <For each={wifiAccessPoints}>
            {(ap) => (
              <button class="list-item" onClicked={() => void connectToAccessPoint(ap)}>
                <box hexpand>
                  <box orientation={VERTICAL} hexpand>
                    <label class="item-title" label={ap.ssid} halign={Gtk.Align.START} />
                    <label
                      class="item-subtitle"
                      halign={Gtk.Align.START}
                      label={`${signalLabel(ap.strength)} • ${ap.strength}%${ap.requires_password ? " • Secured" : ""}`}
                    />
                  </box>
                  <label
                    class="item-icon"
                    label={wifiSsid((ssid) => (ssid === ap.ssid ? "󰄬" : "󰤨"))}
                  />
                </box>
              </button>
            )}
          </For>
        </box>
      </scrolledwindow>

      <label class="message" label={wifiMessage} visible={wifiMessage((msg) => msg.length > 0)} halign={Gtk.Align.START} />
    </box>
  )
}

function BluetoothContent() {
  const connectedCount = bluetoothDevices((devices) => `${devices.filter((device) => device.connected).length}`)

  return (
    <box name="bluetooth" orientation={VERTICAL} class="popover-body">
      <SectionTitle title="Bluetooth" detail={bluetoothPowered((powered) => (powered ? "On" : "Off"))} />

      <box class="switch-row">
        <label label="Enable Bluetooth" hexpand halign={Gtk.Align.START} />
        <switch
          active={bluetoothPowered}
          onNotifyActive={({ active }) => {
            bluetooth.isPowered = active
            setBluetoothMessage(active ? "Bluetooth enabled" : "Bluetooth disabled")
          }}
        />
      </box>

      <SectionTitle title="Devices" detail={connectedCount} />

      <scrolledwindow class="list-scroll" minContentHeight={220}>
        <box orientation={VERTICAL} class="item-list">
          <For each={bluetoothDevices}>
            {(device) => (
              <button class="list-item" onClicked={() => void toggleBluetoothDevice(device)}>
                <box hexpand>
                  <box orientation={VERTICAL} hexpand>
                    <label class="item-title" label={device.alias || device.name || device.address} halign={Gtk.Align.START} />
                    <label
                      class="item-subtitle"
                      halign={Gtk.Align.START}
                      label={`${device.connected ? "Connected" : device.paired ? "Paired" : "Available"}${
                        device.batteryPercentage >= 0 ? ` • Battery ${device.batteryPercentage}%` : ""
                      }`}
                    />
                  </box>
                  <label class="item-icon" label={device.connected ? "󰂱" : "󰂯"} />
                </box>
              </button>
            )}
          </For>
        </box>
      </scrolledwindow>

      <label
        class="message"
        label={bluetoothMessage}
        visible={bluetoothMessage((msg) => msg.length > 0)}
        halign={Gtk.Align.START}
      />
    </box>
  )
}

export function createControlPanel(monitor: Gdk.Monitor) {
  let window!: Astal.Window
  let stack!: Gtk.Stack
  let timeoutId = 0
  let activePage = "wifi"

  const resetAutoHide = () => {
    if (timeoutId) {
      GLib.source_remove(timeoutId)
      timeoutId = 0
    }

    if (!window.visible) return

    timeoutId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, PANEL_TIMEOUT_MS, () => {
      window.visible = false
      timeoutId = 0
      return GLib.SOURCE_REMOVE
    })
  }

  const hide = () => {
    if (timeoutId) {
      GLib.source_remove(timeoutId)
      timeoutId = 0
    }
    window.visible = false
  }

  const show = (page: "wifi" | "bluetooth") => {
    activePage = page
    stack.visibleChildName = page
    window.visible = true
    resetAutoHide()
  }

  const toggle = (page: "wifi" | "bluetooth") => {
    if (window.visible && activePage === page) {
      hide()
      return
    }

    show(page)
  }

  const motionController = new Gtk.EventControllerMotion()
  motionController.connect("motion", resetAutoHide)
  motionController.connect("enter", resetAutoHide)

  const clickController = new Gtk.GestureClick()
  clickController.connect("pressed", resetAutoHide)

  const panel = (
    <window
      $={(self) => {
        window = self
        self.add_controller(motionController)
        self.add_controller(clickController)
      }}
      name="control-panel"
      namespace="ags-control-panel"
      gdkmonitor={monitor}
      visible={false}
      anchor={Astal.WindowAnchor.TOP | Astal.WindowAnchor.RIGHT}
      layer={Astal.Layer.OVERLAY}
      keymode={Astal.Keymode.ON_DEMAND}
      marginTop={12}
      marginRight={8}
    >
      <box class="floating-menu">
        <stack
          $={(self) => {
            stack = self
            self.visibleChildName = activePage
          }}
          transitionType={Gtk.StackTransitionType.CROSSFADE}
        >
          <WifiContent $type="named" />
          <BluetoothContent $type="named" />
        </stack>
      </box>
    </window>
  ) as Astal.Window

  return { window: panel, show, hide, toggle }
}
