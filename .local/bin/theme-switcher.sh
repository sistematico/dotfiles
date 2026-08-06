#!/usr/bin/env bash
# Alterna o tema (Gruvbox Dark <-> Tokyo Night) do foot, rofi, mango, gtk,
# waybar, mako, nvim, vim e tmux ao mesmo tempo.
#
# Uso:
#   theme-switcher.sh set <gruvbox-dark|tokyonight>
#   theme-switcher.sh toggle
#   theme-switcher.sh menu      # menu rofi pra escolher o tema
#   theme-switcher.sh current   # imprime o id do tema ativo
#   theme-switcher.sh status    # JSON pro custom module da waybar
set -euo pipefail

STATE_DIR="$HOME/.config/theme-switcher"
STATE_FILE="$STATE_DIR/current"

FOOT_INI="$HOME/.config/foot/foot.ini"
ROFI_CONF="$HOME/.config/rofi/config.rasi"
MANGO_CONF="$HOME/.config/mango/config.conf"
WAYBAR_STYLE="$HOME/.config/waybar/style.css"
MAKO_DIR="$HOME/.config/mako"
MAKO_LINK="$MAKO_DIR/config"
NVIM_GRUVBOX="$HOME/.config/nvim/lua/plugins/gruvbox.lua"
NVIM_TOKYONIGHT="$HOME/.config/nvim/lua/plugins/tokyo-night.lua"
VIMRC="$HOME/.vimrc"
TMUX_THEME_FILE="$HOME/.tmux/theme"
TMUX_CONF="$HOME/.tmux.conf"

THEME_IDS=(gruvbox-dark tokyonight)

notify() {
  notify-send -i /home/lucas/.local/share/icons/Newaita-reborn/apps/48/preferences-desktop-color.svg -u "${1:-normal}" "Tema" "$2" 2>/dev/null || true
}

fail() {
  echo "theme-switcher: $1" >&2
  notify critical "$1"
  exit 1
}

display_name() {
  case "$1" in
    gruvbox-dark) echo "Gruvbox Dark" ;;
    tokyonight) echo "Tokyo Night" ;;
    *) echo "$1" ;;
  esac
}

# id "sem sufixo", usado pelos apps que não distinguem "-dark" no nome
# (waybar, tmux, nvim, vim): gruvbox-dark -> gruvbox
short_id() {
  case "$1" in
    gruvbox-dark) echo "gruvbox" ;;
    *) echo "$1" ;;
  esac
}

validate_id() {
  local id="$1" ok=0
  for t in "${THEME_IDS[@]}"; do
    [ "$t" = "$id" ] && ok=1
  done
  [ "$ok" -eq 1 ] || fail "tema desconhecido: $id (opções: ${THEME_IDS[*]})"
}

current_theme() {
  if [ -f "$STATE_FILE" ]; then
    cat "$STATE_FILE"
  else
    echo "gruvbox-dark"
  fi
}

# Força uma linha de config pra um estado comentado/descomentado, não
# importa em qual dos dois estava antes (idempotente).
#   set_theme_line file conteudo comment_prefix comment_suffix want_commented
set_theme_line() {
  local file="$1" content="$2" prefix="$3" suffix="$4" want_commented="$5"
  local content_esc prefix_esc suffix_esc replacement
  content_esc=$(printf '%s' "$content" | sed -e 's/[.[\*^$()+{}|]/\\&/g')
  prefix_esc=$(printf '%s' "$prefix" | sed -e 's/[.[\*^$()+{}|]/\\&/g')
  suffix_esc=$(printf '%s' "$suffix" | sed -e 's/[.[\*^$()+{}|]/\\&/g')

  if [ "$want_commented" = true ]; then
    replacement="${prefix}${content}${suffix}"
  else
    replacement="${content}"
  fi

  sed -i -E \
    "s|^[[:space:]]*(${prefix_esc}[[:space:]]*)?${content_esc}([[:space:]]*${suffix_esc})?[[:space:]]*\$|${replacement}|" \
    "$file"
}

apply_foot() {
  local id="$1"
  [ -f "$FOOT_INI" ] || return 0
  local t
  for t in "${THEME_IDS[@]}"; do
    set_theme_line "$FOOT_INI" "include=~/.config/foot/themes/${t}.ini" "# " "" "$([ "$t" != "$id" ] && echo true || echo false)"
  done
}

apply_rofi() {
  local id="$1"
  [ -f "$ROFI_CONF" ] || return 0
  local t
  for t in "${THEME_IDS[@]}"; do
    set_theme_line "$ROFI_CONF" "@theme \"~/.config/rofi/${t}.rasi\"" "/* " " */" "$([ "$t" != "$id" ] && echo true || echo false)"
  done
}

apply_mango() {
  local id="$1"
  [ -f "$MANGO_CONF" ] || return 0
  local t
  for t in "${THEME_IDS[@]}"; do
    set_theme_line "$MANGO_CONF" "source=./themes/${t}.conf" "# " "" "$([ "$t" != "$id" ] && echo true || echo false)"
  done
}

apply_waybar() {
  local id short t
  id="$1"
  [ -f "$WAYBAR_STYLE" ] || return 0
  for t in "${THEME_IDS[@]}"; do
    short=$(short_id "$t")
    set_theme_line "$WAYBAR_STYLE" "@import url(\"style-${short}.css\");" "/* " " */" "$([ "$t" != "$id" ] && echo true || echo false)"
  done
}

apply_mako() {
  local id short
  id="$1"
  short=$(short_id "$id")
  [ -d "$MAKO_DIR" ] || return 0
  [ -f "$MAKO_DIR/config-${short}" ] || return 0
  ln -sf "config-${short}" "$MAKO_LINK"
}

apply_gtk() {
  local id="$1"
  if [ "$id" != "gruvbox-dark" ]; then
    echo "gtk: sem tema Tokyo Night instalado (só Colloid-*-Gruvbox via AUR), mantendo Colloid-Dark-Gruvbox" >&2
    return 0
  fi
  for f in "$HOME/.config/gtk-3.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"; do
    [ -f "$f" ] || continue
    sed -i -E 's/^gtk-theme-name[[:space:]]*=.*/gtk-theme-name = Colloid-Dark-Gruvbox/' "$f"
  done
  gsettings set org.gnome.desktop.interface gtk-theme 'Colloid-Dark-Gruvbox' 2>/dev/null || true
}

apply_nvim() {
  local id short
  id="$1"
  short=$(short_id "$id")
  [ -f "$NVIM_GRUVBOX" ] && [ -f "$NVIM_TOKYONIGHT" ] || return 0

  if [ "$short" = "gruvbox" ]; then
    cat >"$NVIM_GRUVBOX" <<'EOF'
-- Tema padrão atual. Pra voltar pro Tokyo Night, veja tokyo-night.lua.
return {
  "ellisonleao/gruvbox.nvim",
  lazy = false,
  priority = 1000,
  opts = {
    contrast = "hard",
    transparent_mode = true,
  },
  config = function(_, opts)
    require("gruvbox").setup(opts)
    vim.cmd.colorscheme "gruvbox"
  end,
}
EOF
    cat >"$NVIM_TOKYONIGHT" <<'EOF'
-- Instalado mas inativo. Pra voltar a usar: mude lazy=false e priority=1000
-- aqui, e desative o vim.cmd.colorscheme "gruvbox" em gruvbox.lua.
return {
  "folke/tokyonight.nvim",
  lazy = true,
  opts = {
    -- "night" matches the background kitty currently uses (#1a1b26)
    style = "night",
    transparent = true,
    styles = {
      sidebars = "transparent",
      floats = "transparent",
    },
  },
  config = function(_, opts)
    require("tokyonight").setup(opts)
  end,
}
EOF
  else
    cat >"$NVIM_TOKYONIGHT" <<'EOF'
-- Tema padrão atual. Pra voltar pro Gruvbox, veja gruvbox.lua.
return {
  "folke/tokyonight.nvim",
  lazy = false,
  priority = 1000,
  opts = {
    -- "night" matches the background kitty currently uses (#1a1b26)
    style = "night",
    transparent = true,
    styles = {
      sidebars = "transparent",
      floats = "transparent",
    },
  },
  config = function(_, opts)
    require("tokyonight").setup(opts)
    vim.cmd.colorscheme "tokyonight"
  end,
}
EOF
    cat >"$NVIM_GRUVBOX" <<'EOF'
-- Instalado mas inativo. Pra voltar a usar: mude lazy=false e priority=1000
-- aqui, e desative o vim.cmd.colorscheme "tokyonight" em tokyo-night.lua.
return {
  "ellisonleao/gruvbox.nvim",
  lazy = true,
  opts = {
    contrast = "hard",
    transparent_mode = true,
  },
  config = function(_, opts)
    require("gruvbox").setup(opts)
  end,
}
EOF
  fi
}

apply_vim() {
  local id short
  id="$1"
  short=$(short_id "$id")
  [ -f "$VIMRC" ] || return 0

  set_theme_line "$VIMRC" "let g:airline_theme = \"gruvbox\"" "\" " "" "$([ "$short" != "gruvbox" ] && echo true || echo false)"
  set_theme_line "$VIMRC" "let g:airline_theme = \"tokyonight\"" "\" " "" "$([ "$short" != "tokyonight" ] && echo true || echo false)"
  set_theme_line "$VIMRC" "let g:tokyonight_style = 'night'" "\" " " \" available: night, storm" "$([ "$short" != "tokyonight" ] && echo true || echo false)"
  set_theme_line "$VIMRC" "let g:tokyonight_enable_italic = 1" "\" " "" "$([ "$short" != "tokyonight" ] && echo true || echo false)"
  set_theme_line "$VIMRC" "colorscheme gruvbox" "\" " "" "$([ "$short" != "gruvbox" ] && echo true || echo false)"
  set_theme_line "$VIMRC" "colorscheme tokyonight" "\" " "" "$([ "$short" != "tokyonight" ] && echo true || echo false)"
}

apply_tmux() {
  local id short
  id="$1"
  short=$(short_id "$id")
  mkdir -p "$(dirname "$TMUX_THEME_FILE")"
  echo "$short" >"$TMUX_THEME_FILE"
  if [ -n "${TMUX:-}" ] && [ -f "$TMUX_CONF" ]; then
    tmux source-file "$TMUX_CONF" 2>/dev/null || true
  fi
}

reload_mango() {
  command -v mmsg >/dev/null 2>&1 || return 0
  [ -n "${MANGO_INSTANCE_SIGNATURE:-}" ] || return 0
  mmsg dispatch reload_config >/dev/null 2>&1 || true
}

reload_mako() {
  command -v makoctl >/dev/null 2>&1 || return 0
  pgrep -x mako >/dev/null 2>&1 || return 0
  makoctl reload >/dev/null 2>&1 || true
}

set_theme() {
  local id="$1"
  validate_id "$id"

  apply_foot "$id"
  apply_rofi "$id"
  apply_mango "$id"
  apply_waybar "$id"
  apply_mako "$id"
  apply_gtk "$id"
  apply_nvim "$id"
  apply_vim "$id"
  apply_tmux "$id"

  mkdir -p "$STATE_DIR"
  echo "$id" >"$STATE_FILE"

  # waybar já se recarrega sozinho (reload_style_on_change no config.jsonc);
  # mango e mako precisam de um dispatch/reload explícito.
  reload_mango
  reload_mako

  notify normal "Tema alterado para $(display_name "$id")"
}

toggle_theme() {
  local cur next
  cur="$(current_theme)"
  if [ "$cur" = "gruvbox-dark" ]; then
    next="tokyonight"
  else
    next="gruvbox-dark"
  fi
  set_theme "$next"
}

menu() {
  local cur choice id t
  cur="$(current_theme)"
  choice=$(
    for t in "${THEME_IDS[@]}"; do
      if [ "$t" = "$cur" ]; then
        printf '● %s\n' "$(display_name "$t")"
      else
        printf '  %s\n' "$(display_name "$t")"
      fi
    done | rofi -dmenu -p "Tema" -theme-str 'window { width: 10%; } element { padding: 8px 0; }  mainbox { children: [listview]; }'  -l "${#THEME_IDS[@]}" -no-custom
  ) || exit 0

  [ -n "$choice" ] || exit 0

  for t in "${THEME_IDS[@]}"; do
    case "$choice" in
      *"$(display_name "$t")") id="$t" ;;
    esac
  done

  [ -n "${id:-}" ] || exit 0
  set_theme "$id"
}

status() {
  local cur name
  cur="$(current_theme)"
  name="$(display_name "$cur")"
  printf '{"text": " ", "tooltip": "Tema: %s", "alt": "%s"}\n' "$name" "$cur"
}

cmd="${1:-}"
case "$cmd" in
  set)
    [ "$#" -eq 2 ] || fail "uso: theme-switcher.sh set <${THEME_IDS[*]}>"
    set_theme "$2"
    ;;
  toggle) toggle_theme ;;
  menu) menu ;;
  current) current_theme ;;
  status) status ;;
  *)
    echo "Uso: theme-switcher.sh {set <tema>|toggle|menu|current|status}" >&2
    echo "Temas disponíveis: ${THEME_IDS[*]}" >&2
    exit 1
    ;;
esac
