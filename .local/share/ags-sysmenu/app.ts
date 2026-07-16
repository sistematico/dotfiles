import app from "ags/gtk4/app"
import { Gtk } from "ags/gtk4"
import style from "./style.css"
import SystemMenu from "./widget/SystemMenu"
import PowerMenu from "./widget/PowerMenu"
import HotZone from "./widget/HotZone"

app.start({
  instanceName: "sysmenu",
  css: style,
  main() {
    const settings = Gtk.Settings.get_default()
    if (settings) settings.gtkIconThemeName = "Newaita-reborn-dark"

    SystemMenu()
    PowerMenu()

    // Zonas de hover sobre a waybar (margin 10, height 38).
    // Ajuste marginRight/width para casar com a posição dos módulos.
    HotZone({ target: "sysmenu", width: 56, height: 38, marginRight: 250, marginTop: 10 })
    HotZone({ target: "powermenu", width: 40, height: 38, marginRight: 6, marginTop: 10 })
  },
})
