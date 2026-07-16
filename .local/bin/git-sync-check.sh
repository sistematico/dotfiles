#!/usr/bin/env bash

set -euo pipefail

SCAN_DIR="${1:-$(pwd)}"

# Colors / styles via gum
TITLE_STYLE="--foreground=212 --bold"
AHEAD_COLOR="220"    # yellow
BEHIND_COLOR="39"    # blue
DIVERGED_COLOR="196" # red
CLEAN_COLOR="82"     # green
NO_REMOTE_COLOR="245" # gray
DIRTY_COLOR="201"    # magenta

status_icon() {
  case "$1" in
    ahead)    echo "↑" ;;
    behind)   echo "↓" ;;
    diverged) echo "⇕" ;;
    clean)    echo "✓" ;;
    no_remote)echo "~" ;;
    *)        echo "?" ;;
  esac
}

status_color() {
  case "$1" in
    ahead)    echo "$AHEAD_COLOR" ;;
    behind)   echo "$BEHIND_COLOR" ;;
    diverged) echo "$DIVERGED_COLOR" ;;
    clean)    echo "$CLEAN_COLOR" ;;
    no_remote)echo "$NO_REMOTE_COLOR" ;;
    *)        echo "255" ;;
  esac
}

action_label() {
  case "$1" in
    ahead)    echo "git push" ;;
    behind)   echo "git pull" ;;
    diverged) echo "git pull --rebase  (ou merge manual)" ;;
    clean)    echo "nenhuma ação necessária" ;;
    no_remote)echo "sem remote configurado" ;;
    *)        echo "verificar manualmente" ;;
  esac
}

get_repo_status() {
  local dir="$1"
  local result

  # Check if it's a git repo
  if ! git -C "$dir" rev-parse --git-dir &>/dev/null 2>&1; then
    echo "not_git"
    return
  fi

  # Check for remote
  local remote
  remote=$(git -C "$dir" remote 2>/dev/null | head -1)
  if [[ -z "$remote" ]]; then
    echo "no_remote"
    return
  fi

  # Try to fetch (silent, timeout-ish via background)
  git -C "$dir" fetch "$remote" --quiet 2>/dev/null || true

  # Get current branch
  local branch
  branch=$(git -C "$dir" symbolic-ref --short HEAD 2>/dev/null || echo "")
  if [[ -z "$branch" ]]; then
    echo "no_remote"  # detached HEAD
    return
  fi

  # Check if upstream tracking branch exists
  local upstream
  upstream=$(git -C "$dir" for-each-ref --format='%(upstream:short)' "refs/heads/$branch" 2>/dev/null)
  if [[ -z "$upstream" ]]; then
    echo "no_remote"
    return
  fi

  local ahead behind
  ahead=$(git -C "$dir" rev-list --count "${upstream}..HEAD" 2>/dev/null || echo 0)
  behind=$(git -C "$dir" rev-list --count "HEAD..${upstream}" 2>/dev/null || echo 0)

  if [[ "$ahead" -gt 0 && "$behind" -gt 0 ]]; then
    echo "diverged:${ahead}:${behind}"
  elif [[ "$ahead" -gt 0 ]]; then
    echo "ahead:${ahead}"
  elif [[ "$behind" -gt 0 ]]; then
    echo "behind:${behind}"
  else
    echo "clean"
  fi
}

is_dirty() {
  local dir="$1"
  [[ -n "$(git -C "$dir" status --porcelain 2>/dev/null)" ]]
}

# ── Header ──────────────────────────────────────────────────────────────────
gum style \
  --border rounded \
  --border-foreground 212 \
  --padding "0 2" \
  --margin "1 0" \
  $TITLE_STYLE \
  "  Git Sync Check" \
  "$(gum style --faint "Diretório: $SCAN_DIR")"

# Collect git repos (depth 1)
mapfile -t repos < <(
  find "$SCAN_DIR" -maxdepth 1 -mindepth 1 -type d -not -name '.*' \
    -not -name 'old*' -not -name '*old' \
  | sort
)

# Filter actual git repos
git_repos=()
for d in "${repos[@]}"; do
  if git -C "$d" rev-parse --git-dir &>/dev/null 2>&1; then
    git_repos+=("$d")
  fi
done

if [[ ${#git_repos[@]} -eq 0 ]]; then
  gum style --foreground 196 "Nenhum repositório git encontrado em $SCAN_DIR"
  exit 0
fi

gum style --faint "Verificando ${#git_repos[@]} repositório(s)…"
echo

# ── Process each repo ────────────────────────────────────────────────────────
declare -A results
declare -A dirty
declare -a order

for dir in "${git_repos[@]}"; do
  name=$(basename "$dir")
  order+=("$name")

  printf "%s" "$(gum style --faint "  Buscando $name…")"$'\r'

  raw=$(get_repo_status "$dir")
  results["$name"]="$raw"

  if is_dirty "$dir"; then
    dirty["$name"]=1
  else
    dirty["$name"]=0
  fi
done

# Clear the "fetching…" line
printf '%*s\r' "$(tput cols)" ""

# ── Summary table ────────────────────────────────────────────────────────────
needs_action=()
clean_list=()
no_remote_list=()
dirty_list=()

for name in "${order[@]}"; do
  raw="${results[$name]}"
  state="${raw%%:*}"

  if [[ "${dirty[$name]}" -eq 1 ]]; then
    dirty_list+=("$name")
  fi

  case "$state" in
    clean)     [[ "${dirty[$name]}" -eq 0 ]] && clean_list+=("$name") ;;
    no_remote) no_remote_list+=("$name") ;;
    *)         needs_action+=("$name") ;;
  esac
done

print_repo_line() {
  local name="$1" raw="$2"
  local state="${raw%%:*}"
  local rest="${raw#*:}"

  local icon color label extra=""

  icon=$(status_icon "$state")
  color=$(status_color "$state")
  label=$(action_label "$state")

  case "$state" in
    ahead)
      local n="${rest%%:*}"
      extra=" (+${n} commit(s))"
      ;;
    behind)
      local n="${rest%%:*}"
      extra=" (-${n} commit(s))"
      ;;
    diverged)
      local a="${rest%%:*}" b="${rest##*:}"
      extra=" (+${a}/-${b} commits)"
      ;;
  esac

  printf "  %s  %-30s  %s\n" \
    "$(gum style --foreground "$color" "$icon")" \
    "$(gum style --foreground "$color" --bold "$name")" \
    "$(gum style --foreground "$color" "${label}${extra}")"
}

print_dirty_line() {
  local name="$1" raw="$2"
  local state="${raw%%:*}"
  local label="alterações não commitadas"

  if [[ "$state" != "clean" ]]; then
    label+=" (também: $(action_label "$state"))"
  fi

  printf "  %s  %-30s  %s\n" \
    "$(gum style --foreground "$DIRTY_COLOR" "✎")" \
    "$(gum style --foreground "$DIRTY_COLOR" --bold "$name")" \
    "$(gum style --foreground "$DIRTY_COLOR" "$label")"
}

# ── Repos needing action ─────────────────────────────────────────────────────
if [[ ${#needs_action[@]} -gt 0 ]]; then
  gum style --foreground 212 --bold --underline "Repositórios desincronizados (${#needs_action[@]})"
  echo
  for name in "${needs_action[@]}"; do
    print_repo_line "$name" "${results[$name]}"
  done
  echo
fi

# ── Alterações não commitadas ────────────────────────────────────────────────
if [[ ${#dirty_list[@]} -gt 0 ]]; then
  gum style --foreground "$DIRTY_COLOR" --bold --underline "Alterações não commitadas (${#dirty_list[@]})"
  echo
  for name in "${dirty_list[@]}"; do
    print_dirty_line "$name" "${results[$name]}"
  done
  echo
fi

# ── Up to date ───────────────────────────────────────────────────────────────
if [[ ${#clean_list[@]} -gt 0 ]]; then
  gum style --foreground 82 --bold --underline "Sincronizados (${#clean_list[@]})"
  echo
  for name in "${clean_list[@]}"; do
    print_repo_line "$name" "clean"
  done
  echo
fi

# ── No remote ────────────────────────────────────────────────────────────────
if [[ ${#no_remote_list[@]} -gt 0 ]]; then
  gum style --foreground 245 --bold --underline "Sem remote (${#no_remote_list[@]})"
  echo
  for name in "${no_remote_list[@]}"; do
    print_repo_line "$name" "no_remote"
  done
  echo
fi

# ── Legend ───────────────────────────────────────────────────────────────────
gum style \
  --border normal \
  --border-foreground 240 \
  --padding "0 1" \
  --faint \
  "$(gum style --foreground "$AHEAD_COLOR"    "↑ ahead")    commits locais não enviados  →  git push
$(gum style --foreground "$BEHIND_COLOR"   "↓ behind")   commits remotos não puxados  →  git pull
$(gum style --foreground "$DIVERGED_COLOR" "⇕ diverged") históricos divergentes       →  rebase/merge
$(gum style --foreground "$CLEAN_COLOR"    "✓ clean")    sincronizado com o remote
$(gum style --foreground "$NO_REMOTE_COLOR" "~ no remote") sem branch de tracking
$(gum style --foreground "$DIRTY_COLOR"    "✎ dirty")    alterações não commitadas →  git add / commit"
