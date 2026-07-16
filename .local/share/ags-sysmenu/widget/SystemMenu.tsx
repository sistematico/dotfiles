import app from "ags/gtk4/app"
import { Astal, Gtk } from "ags/gtk4"
import { Accessor } from "ags"
import { createPoll } from "ags/time"
import { execAsync } from "ags/process"
import statsScript from "inline:../scripts/stats.sh"
import { cancelHide, scheduleHide } from "./hover"

interface Proc {
  name: string
  cpu: number
  mem: number
}

interface Stats {
  cpu: number
  mem_pct: number
  mem_used: string
  mem_total: string
  disk_pct: number
  disk_used: string
  disk_size: string
  temp: number
  load1: string
  load5: string
  load15: string
  cores: number
  uptime: string
  procs: Proc[]
}

const initial: Stats = {
  cpu: 0,
  mem_pct: 0,
  mem_used: "0",
  mem_total: "0",
  disk_pct: 0,
  disk_used: "-",
  disk_size: "-",
  temp: 0,
  load1: "0",
  load5: "0",
  load15: "0",
  cores: 1,
  uptime: "-",
  procs: [],
}

const stats = createPoll<Stats>(initial, 2000, (prev) =>
  execAsync(["bash", "-c", statsScript])
    .then((out) => JSON.parse(out) as Stats)
    .catch(() => prev),
)

function severity(pct: number) {
  if (pct >= 90) return "crit"
  if (pct >= 70) return "warn"
  return "ok"
}

function StatRow({
  icon,
  title,
  value,
  fraction,
  level,
}: {
  icon: string
  title: string
  value: Accessor<string>
  fraction: Accessor<number>
  level: Accessor<string>
}) {
  return (
    <box class={level.as((l) => `stat-row ${l}`)} orientation={Gtk.Orientation.VERTICAL}>
      <box class="stat-header" spacing={10}>
        <box class="icon-tile">
          <image iconName={icon} pixelSize={22} />
        </box>
        <label class="stat-title" label={title} halign={Gtk.Align.START} hexpand />
        <label class="stat-value" label={value} halign={Gtk.Align.END} />
      </box>
      <levelbar
        class="stat-bar"
        minValue={0}
        maxValue={1}
        value={fraction}
        mode={Gtk.LevelBarMode.CONTINUOUS}
      />
    </box>
  )
}

function ProcRow({ index }: { index: number }) {
  const proc = stats.as((s) => s.procs[index])
  return (
    <box class="proc-row" spacing={8} visible={proc.as((p) => p !== undefined)}>
      <label
        class="proc-name"
        label={proc.as((p) => p?.name ?? "")}
        halign={Gtk.Align.START}
        ellipsize={3 /* Pango.EllipsizeMode.END */}
        maxWidthChars={18}
        hexpand
      />
      <label class="proc-cpu" label={proc.as((p) => (p ? `${p.cpu.toFixed(1)}%` : ""))} />
      <label class="proc-mem" label={proc.as((p) => (p ? `${p.mem.toFixed(1)}%` : ""))} />
    </box>
  )
}

export default function SystemMenu() {
  const { TOP, RIGHT } = Astal.WindowAnchor

  return (
    <window
      name="sysmenu"
      class="SysMenu"
      anchor={TOP | RIGHT}
      exclusivity={Astal.Exclusivity.NORMAL}
      keymode={Astal.Keymode.ON_DEMAND}
      layer={Astal.Layer.OVERLAY}
      marginTop={8}
      marginRight={285} // centralizado abaixo do módulo de cpu; use 8 para o canto
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
        motion.connect("enter", () => cancelHide("sysmenu"))
        motion.connect("leave", () => scheduleHide("sysmenu"))
        self.add_controller(motion)
      }}
    >
      <box class="menu" orientation={Gtk.Orientation.VERTICAL} spacing={14}>
        <box class="header" spacing={10}>
          <image iconName="utilities-system-monitor" pixelSize={26} />
          <label class="title" label="Sistema" halign={Gtk.Align.START} hexpand />
          <label class="uptime" label={stats.as((s) => `↑ ${s.uptime}`)} />
        </box>

        <StatRow
          icon="cpu"
          title="Processador"
          value={stats.as((s) => `${s.cpu}%`)}
          fraction={stats.as((s) => s.cpu / 100)}
          level={stats.as((s) => severity(s.cpu))}
        />

        <StatRow
          icon="dialog-memory"
          title="Memória"
          value={stats.as((s) => `${s.mem_used} / ${s.mem_total} GiB  ·  ${s.mem_pct}%`)}
          fraction={stats.as((s) => s.mem_pct / 100)}
          level={stats.as((s) => severity(s.mem_pct))}
        />

        <StatRow
          icon="drive-harddisk-solidstate"
          title="Disco  /"
          value={stats.as((s) => `${s.disk_used} / ${s.disk_size}  ·  ${s.disk_pct}%`)}
          fraction={stats.as((s) => s.disk_pct / 100)}
          level={stats.as((s) => severity(s.disk_pct))}
        />

        <StatRow
          icon="thermal-monitor"
          title="Temperatura"
          value={stats.as((s) => `${s.temp}°C`)}
          fraction={stats.as((s) => Math.min(s.temp / 100, 1))}
          level={stats.as((s) => severity(s.temp))}
        />

        <StatRow
          icon="utilities-system-monitor"
          title="Carga do sistema"
          value={stats.as((s) => `${s.load1}  ${s.load5}  ${s.load15}`)}
          fraction={stats.as((s) => Math.min(parseFloat(s.load1) / s.cores, 1))}
          level={stats.as((s) => severity((parseFloat(s.load1) / s.cores) * 100))}
        />

        <box class="procs" orientation={Gtk.Orientation.VERTICAL} spacing={6}>
          <box class="procs-header" spacing={10}>
            <box class="icon-tile">
              <image iconName="htop" pixelSize={22} />
            </box>
            <label class="stat-title" label="Processos" halign={Gtk.Align.START} hexpand />
            <label class="proc-col" label="CPU" />
            <label class="proc-col" label="MEM" />
          </box>
          {[0, 1, 2, 3, 4, 5].map((i) => (
            <ProcRow index={i} />
          ))}
        </box>
      </box>
    </window>
  )
}
