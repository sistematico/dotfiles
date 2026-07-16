import app from "ags/gtk4/app"
import { Astal, Gtk } from "ags/gtk4"
import { showMenu, scheduleHide, toggleMenu } from "./hover"

interface HotZoneProps {
  target: string // nome da janela a exibir
  width: number
  height: number
  marginRight: number
  marginTop: number
}

// Zona invisível sobre um módulo da waybar: hover abre o menu-alvo,
// sair agenda o fechamento e o clique alterna. O background dela no CSS
// precisa de alfa > 0, senão o compositor ignora o mouse.
export default function HotZone({
  target,
  width,
  height,
  marginRight,
  marginTop,
}: HotZoneProps) {
  const { TOP, RIGHT } = Astal.WindowAnchor

  return (
    <window
      name={`hotzone-${target}`}
      class="HotZone"
      anchor={TOP | RIGHT}
      exclusivity={Astal.Exclusivity.IGNORE}
      layer={Astal.Layer.OVERLAY}
      keymode={Astal.Keymode.NONE}
      marginRight={marginRight}
      marginTop={marginTop}
      visible
      application={app}
      $={(self) => {
        const motion = new Gtk.EventControllerMotion()
        motion.connect("enter", () => showMenu(target))
        motion.connect("leave", () => scheduleHide(target))
        self.add_controller(motion)

        const click = new Gtk.GestureClick()
        click.connect("pressed", () => toggleMenu(target))
        self.add_controller(click)
      }}
    >
      <box widthRequest={width} heightRequest={height} />
    </window>
  )
}
