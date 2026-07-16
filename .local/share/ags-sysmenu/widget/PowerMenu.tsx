import app from "ags/gtk4/app"
import { Astal, Gtk } from "ags/gtk4"
import { execAsync } from "ags/process"
import { cancelHide, scheduleHide, hideMenu } from "./hover"

interface Action {
  icon: string
  label: string
  command: string
  className: string
}

const actions: Action[] = [
  { icon: "system-shutdown", label: "Desligar", command: "poweroff", className: "shutdown" },
  { icon: "system-reboot", label: "Reiniciar", command: "reboot", className: "reboot" },
  { icon: "system-suspend", label: "Suspender", command: "systemctl suspend", className: "suspend" },
  { icon: "system-lock-screen", label: "Bloquear", command: "swaylock", className: "lock" },
  { icon: "system-log-out", label: "Sair", command: "mmsg dispatch quit", className: "logout" },
]

function PowerButton({ icon, label, command, className }: Action) {
  return (
    <button
      class={`power-btn ${className}`}
      onClicked={() => {
        hideMenu("powermenu")
        execAsync(["bash", "-c", command]).catch(console.error)
      }}
    >
      <box spacing={12}>
        <box class="icon-tile">
          <image iconName={icon} pixelSize={22} />
        </box>
        <label label={label} halign={Gtk.Align.START} hexpand />
      </box>
    </button>
  )
}

export default function PowerMenu() {
  const { TOP, RIGHT } = Astal.WindowAnchor

  return (
    <window
      name="powermenu"
      class="PowerMenu"
      anchor={TOP | RIGHT}
      exclusivity={Astal.Exclusivity.NORMAL}
      keymode={Astal.Keymode.ON_DEMAND}
      layer={Astal.Layer.OVERLAY}
      marginTop={8}
      marginRight={8}
      visible={false}
      application={app}
      $={(self) => {
        const key = new Gtk.EventControllerKey()
        key.connect("key-pressed", (_c, keyval) => {
          if (keyval === 65307 /* Escape */) self.visible = false
          return false
        })
        self.add_controller(key)

        const motion = new Gtk.EventControllerMotion()
        motion.connect("enter", () => cancelHide("powermenu"))
        motion.connect("leave", () => scheduleHide("powermenu"))
        self.add_controller(motion)
      }}
    >
      <box class="menu" orientation={Gtk.Orientation.VERTICAL} spacing={6}>
        <box class="header" spacing={10}>
          <image iconName="system-shutdown" pixelSize={22} />
          <label class="title" label="Energia" halign={Gtk.Align.START} hexpand />
        </box>
        {actions.map((a) => (
          <PowerButton {...a} />
        ))}
      </box>
    </window>
  )
}
