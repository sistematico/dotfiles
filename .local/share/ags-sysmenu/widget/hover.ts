import app from "ags/gtk4/app"

// Controle de exibição por hover, compartilhado entre os menus.
// Cada janela é identificada pelo seu `name`.
const timers = new Map<string, ReturnType<typeof setTimeout>>()

export function cancelHide(name: string) {
  const timer = timers.get(name)
  if (timer !== undefined) {
    clearTimeout(timer)
    timers.delete(name)
  }
}

export function showMenu(name: string) {
  cancelHide(name)
  const win = app.get_window(name)
  if (win) win.visible = true
}

export function hideMenu(name: string) {
  cancelHide(name)
  const win = app.get_window(name)
  if (win) win.visible = false
}

export function toggleMenu(name: string) {
  cancelHide(name)
  const win = app.get_window(name)
  if (win) win.visible = !win.visible
}

export function scheduleHide(name: string, delay = 300) {
  cancelHide(name)
  timers.set(
    name,
    setTimeout(() => {
      timers.delete(name)
      const win = app.get_window(name)
      if (win) win.visible = false
    }, delay),
  )
}
