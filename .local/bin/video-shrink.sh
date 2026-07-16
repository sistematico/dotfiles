#!/usr/bin/env bash
# video-shrink.sh - Compacta os vídeos do diretório atual (e subdiretórios)
# perdendo o mínimo de qualidade possível, usando o GPU (NVENC) quando
# disponível para manter o uso de CPU/IO baixo. Processa do maior para o
# menor arquivo, pedindo confirmação a cada vídeo (continuar / apagar
# original).

set -euo pipefail

# ============================================================================
# PRESETS DE PROCESSAMENTO — altere PRESET para controlar o comportamento.
# ============================================================================
#
# CRF / CQ  Fator de qualidade constante (Constant Rate Factor / Constant Quality):
#   Valor MENOR  →  qualidade MELHOR  →  arquivo MAIOR
#   Valor MAIOR  →  qualidade PIOR   →  arquivo MENOR
#   Faixa útil: 18 (quase sem perdas visíveis) a 28 (compressão agressiva).
#   Referência: ~23 é visualmente transparente para a maioria dos conteúdos.
#
# SPEED  Preset de velocidade do encoder:
#   CPU (libx265): ultrafast → superfast → veryfast → faster → fast →
#                  medium → slow → slower → veryslow
#     Presets mais LENTOS  = arquivo menor para a mesma qualidade (mais cálculo).
#     Presets mais RÁPIDOS = arquivo levemente maior, menos calor gerado.
#   GPU (hevc_nvenc): p1 (mais rápido/quente) → p7 (mais compactado/lento)
#     Ponto ideal de custo-benefício: p3–p5.
#
# THREADS  Núcleos da CPU cedidos ao ffmpeg:
#   0  = todos os núcleos disponíveis.
#   Reduzir threads → menos calor → conversão mais lenta.
#   Referência: nproc/4 (conservador) · nproc/2 (moderado) · nproc (máximo).
#
# AUDIO_BITRATE  Bitrate do áudio recodificado em AAC:
#   96k  → voz / podcasts       128k → consumo casual
#   160k → boa qualidade geral  192k → alta qualidade / música
#   256k → transparente para a maioria dos ouvidos
#
# CPU_QUOTA  Teto de uso de CPU via cgroup (systemd-run), em %:
#   Limita o consumo real mesmo sem concorrência, reduzindo calor e energia.
#   "100" = sem limite efetivo   "50" = metade da CPU total do sistema.

# Preset ativo — altere aqui: SPEED | BALANCED | QUALITY | ARCHIVE
PRESET="BALANCED"

# ── SPEED ────────────────────────────────────────────────────────────────────
# Conversão rápida; arquivo levemente maior. Ideal para lotes grandes onde
# tempo importa mais que espaço em disco.
PRESET_SPEED_CRF=26
PRESET_SPEED_X265="faster"
PRESET_SPEED_NVENC="p3"
PRESET_SPEED_THREADS="$(( $(nproc) / 2 > 0 ? $(nproc) / 2 : 1 ))"
PRESET_SPEED_AUDIO="128k"
PRESET_SPEED_CPU_QUOTA="90"

# ── BALANCED (padrão) ────────────────────────────────────────────────────────
# Equilíbrio entre velocidade, qualidade e tamanho. Bom para uso geral:
# filmes, séries, gravações casuais.
PRESET_BALANCED_CRF=23
PRESET_BALANCED_X265="faster"
PRESET_BALANCED_NVENC="p5"
PRESET_BALANCED_THREADS="$(( $(nproc) / 4 > 0 ? $(nproc) / 4 : 1 ))"
PRESET_BALANCED_AUDIO="160k"
PRESET_BALANCED_CPU_QUOTA="85"

# ── QUALITY ──────────────────────────────────────────────────────────────────
# Qualidade visual alta; compressão mais eficiente, processo mais lento.
# Ideal para filmes 4K ou conteúdo exibido em tela grande.
PRESET_QUALITY_CRF=20
PRESET_QUALITY_X265="slow"
PRESET_QUALITY_NVENC="p6"
PRESET_QUALITY_THREADS="$(( $(nproc) / 4 > 0 ? $(nproc) / 4 : 1 ))"
PRESET_QUALITY_AUDIO="192k"
PRESET_QUALITY_CPU_QUOTA="80"

# ── ARCHIVE ──────────────────────────────────────────────────────────────────
# Máxima compressão sem perdas visíveis; muito lento. Para armazenamento de
# longo prazo onde espaço em disco é crítico.
PRESET_ARCHIVE_CRF=18
PRESET_ARCHIVE_X265="veryslow"
PRESET_ARCHIVE_NVENC="p7"
PRESET_ARCHIVE_THREADS="$(( $(nproc) / 4 > 0 ? $(nproc) / 4 : 1 ))"
PRESET_ARCHIVE_AUDIO="256k"
PRESET_ARCHIVE_CPU_QUOTA="75"

# --- aplica o preset escolhido -----------------------------------------------
case "$PRESET" in
  SPEED)
    CRF=$PRESET_SPEED_CRF;    CPU_PRESET_X265="$PRESET_SPEED_X265"
    CPU_PRESET_NVENC="$PRESET_SPEED_NVENC"; THREAD_COUNT="$PRESET_SPEED_THREADS"
    AUDIO_BITRATE="$PRESET_SPEED_AUDIO";   CPU_QUOTA="$PRESET_SPEED_CPU_QUOTA" ;;
  BALANCED)
    CRF=$PRESET_BALANCED_CRF; CPU_PRESET_X265="$PRESET_BALANCED_X265"
    CPU_PRESET_NVENC="$PRESET_BALANCED_NVENC"; THREAD_COUNT="$PRESET_BALANCED_THREADS"
    AUDIO_BITRATE="$PRESET_BALANCED_AUDIO"; CPU_QUOTA="$PRESET_BALANCED_CPU_QUOTA" ;;
  QUALITY)
    CRF=$PRESET_QUALITY_CRF;  CPU_PRESET_X265="$PRESET_QUALITY_X265"
    CPU_PRESET_NVENC="$PRESET_QUALITY_NVENC"; THREAD_COUNT="$PRESET_QUALITY_THREADS"
    AUDIO_BITRATE="$PRESET_QUALITY_AUDIO";  CPU_QUOTA="$PRESET_QUALITY_CPU_QUOTA" ;;
  ARCHIVE)
    CRF=$PRESET_ARCHIVE_CRF;  CPU_PRESET_X265="$PRESET_ARCHIVE_X265"
    CPU_PRESET_NVENC="$PRESET_ARCHIVE_NVENC"; THREAD_COUNT="$PRESET_ARCHIVE_THREADS"
    AUDIO_BITRATE="$PRESET_ARCHIVE_AUDIO";  CPU_QUOTA="$PRESET_ARCHIVE_CPU_QUOTA" ;;
  *)
    echo "Erro: preset desconhecido '$PRESET'. Use: SPEED | BALANCED | QUALITY | ARCHIVE" >&2
    exit 1 ;;
esac

for cmd in gum ffmpeg ffprobe numfmt; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "Erro: '$cmd' não encontrado. Instale com: sudo pacman -S $cmd" >&2
    exit 1
  }
done

# --- estilo ---------------------------------------------------------------
sep()  { gum style --foreground 240 -- "──────────────────────────────────────────"; }
log()  { gum style --foreground 212 "$*"; }
warn() { gum style --foreground 214 "$*"; }
ok()   { gum style --foreground 120 "$*"; }
err()  { gum style --foreground 196 "$*"; }

card() {
  local title="$1"
  shift
  gum style --border rounded --border-foreground 99 \
    --padding "1 2" --margin "1 0" \
    "$title" "" "$@"
}

human() { numfmt --to=iec-i --suffix=B --padding=7 "$1" 2>/dev/null || echo "${1}B"; }

# Trunca nomes/caminhos longos no meio, preservando início e extensão.
truncate_name() {
  local s="$1" max="${2:-60}"
  ((${#s} <= max)) && { printf '%s' "$s"; return; }
  local head_len=$(((max - 1) / 2))
  local tail_len=$((max - 1 - head_len))
  printf '%s…%s' "${s:0:head_len}" "${s: -tail_len}"
}

fmt_dur() {
  local s=${1%.*}
  [[ -z "$s" || "$s" == "N/A" ]] && s=0
  printf '%02d:%02d:%02d' $((s / 3600)) $(((s % 3600) / 60)) $((s % 60))
}

to_seconds() {
  local t="$1" h m s
  IFS=: read -r h m s <<<"$t"
  awk -v h="${h:-0}" -v m="${m:-0}" -v s="${s:-0}" 'BEGIN{print int(h*3600+m*60+s)}'
}

# --- prioridade baixa, para não pesar na máquina ---------------------------
NICE_CMD=()
command -v nice >/dev/null 2>&1 && NICE_CMD+=(nice -n 19)
command -v ionice >/dev/null 2>&1 && NICE_CMD+=(ionice -c3)

# nice/ionice só importam quando há disputa por CPU; se o ffmpeg estiver
# sozinho ele ainda usa todos os núcleos que quiser. Para limitar o uso
# real (e assim o calor gerado) mesmo sem concorrência, aplicamos um teto
# rígido de CPU via cgroup (systemd-run), quando disponível.
WRAP_CMD=()
if command -v systemd-run >/dev/null 2>&1 &&
  systemd-run --user --scope --quiet -p "CPUQuota=${CPU_QUOTA}%" -- true >/dev/null 2>&1; then
  WRAP_CMD=(systemd-run --user --scope --quiet -p "CPUQuota=${CPU_QUOTA}%" --)
fi

# --- cleanup se o script for interrompido no meio de uma conversão -----------
CURRENT_PID=""
CURRENT_OUT=""
cleanup() {
  if [[ -n "$CURRENT_PID" ]]; then
    kill "$CURRENT_PID" 2>/dev/null
    wait "$CURRENT_PID" 2>/dev/null || true
  fi
  if [[ -n "$CURRENT_OUT" && -f "$CURRENT_OUT" ]]; then
    warn "Interrompido: removendo arquivo parcial '$(truncate_name "$CURRENT_OUT" 60)'."
    rm -f "$CURRENT_OUT"
  fi
}
trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

# --- escolhe o encoder com menor impacto na máquina -------------------------
ENCODER="libx265"
ENCODER_LABEL="libx265 (CPU)"
PRESET_OPTS=(-preset "$CPU_PRESET_X265" -crf "$CRF" -threads "$THREAD_COUNT")
HWACCEL_OPTS=()

if command -v nvidia-smi >/dev/null 2>&1 && ffmpeg -hide_banner -encoders 2>/dev/null | grep -q hevc_nvenc; then
  ENCODER="hevc_nvenc"
  ENCODER_LABEL="hevc_nvenc (GPU)"
  PRESET_OPTS=(-preset "$CPU_PRESET_NVENC" -rc vbr -cq "$CRF" -b:v 0)
  # decodifica também na GPU, evitando que a CPU vire o gargalo/fonte de calor
  HWACCEL_OPTS=(-hwaccel cuda -hwaccel_output_format cuda)
fi

# --- escaneia o diretório atual e subdiretórios -----------------------------
EXTS=(mp4 mkv avi mov webm flv wmv m4v ts)
declare -a FIND_EXPR=()
for ext in "${EXTS[@]}"; do
  FIND_EXPR+=(-iname "*.${ext}" -o)
done
unset 'FIND_EXPR[${#FIND_EXPR[@]}-1]' # remove o "-o" final

declare -a FILES=()
while IFS= read -r -d '' f; do
  f="${f#./}"
  [[ "$f" == *.shrunk.* ]] && continue
  FILES+=("$f")
done < <(find . -type f \( "${FIND_EXPR[@]}" \) -print0)

if [[ ${#FILES[@]} -eq 0 ]]; then
  warn "Nenhum vídeo encontrado no diretório atual ou em subdiretórios."
  exit 0
fi

# --- lista de vídeos sem ganho de compressão (evita reprocessar) -----------
# Chave = caminho:tamanho, assim se o arquivo for trocado/editado ele volta
# a ser tentado normalmente.
SKIP_FILE="${VIDEO_SHRINK_SKIP_FILE:-.video-shrink-skip}"
declare -A NO_GAIN=()
if [[ -f "$SKIP_FILE" ]]; then
  while IFS= read -r line; do
    [[ -n "$line" ]] && NO_GAIN["$line"]=1
  done <"$SKIP_FILE"
fi

mark_no_gain() {
  local key="$1:$2"
  NO_GAIN["$key"]=1
  printf '%s\n' "$key" >>"$SKIP_FILE"
}

# ordena do maior para o menor arquivo
declare -a SORTED=()
while IFS= read -r line; do
  SORTED+=("${line#* }")
done < <(for f in "${FILES[@]}"; do printf '%s %s\n' "$(stat -c%s "$f")" "$f"; done | sort -rn)
FILES=("${SORTED[@]}")

card "🎬 Video Shrink" \
  "Vídeos encontrados: ${#FILES[@]} (do maior para o menor)" \
  "Encoder: ${ENCODER_LABEL}   Preset: ${PRESET} (CRF/CQ ${CRF}, áudio ${AUDIO_BITRATE})" \
  "Prioridade: reduzida (nice/ionice)$([[ ${#WRAP_CMD[@]} -gt 0 ]] && echo ", teto de CPU em ${CPU_QUOTA}%")"

# --- barra de progresso ------------------------------------------------------
draw_bar() {
  local pct=$1
  local cols width=40
  cols=$(tput cols 2>/dev/null || echo 80)
  ((cols - 10 < width)) && width=$((cols - 10))
  ((width < 10)) && width=10
  ((pct > 100)) && pct=100
  ((pct < 0)) && pct=0
  local filled=$((pct * width / 100))
  local empty=$((width - filled))
  local bar
  bar="$(printf '━%.0s' $(seq 1 "$filled" 2>/dev/null))$(printf '─%.0s' $(seq 1 "$empty" 2>/dev/null))"
  printf '\r\033[2K  \033[38;5;212m%s\033[0m %3d%%' "$bar" "$pct"
}

run_with_progress() {
  local infile="$1" outfile="$2" duration="$3"
  local progress_file
  progress_file=$(mktemp)

  "${WRAP_CMD[@]}" "${NICE_CMD[@]}" ffmpeg -y -nostdin "${HWACCEL_OPTS[@]}" -i "$infile" \
    -map "0:v:0" -map "0:a:0?" \
    -c:v "$ENCODER" "${PRESET_OPTS[@]}" \
    -c:a aac -b:a "$AUDIO_BITRATE" \
    -movflags +faststart \
    -progress "$progress_file" -nostats -loglevel error \
    "$outfile" </dev/null &
  CURRENT_PID=$!

  draw_bar 0
  while kill -0 "$CURRENT_PID" 2>/dev/null; do
    if [[ -s "$progress_file" ]]; then
      local out_time cur_s pct
      out_time=$(grep -a '^out_time=' "$progress_file" | tail -1 | cut -d= -f2)
      if [[ -n "$out_time" && "$duration" -gt 0 ]]; then
        cur_s=$(to_seconds "$out_time")
        pct=$((cur_s * 100 / duration))
        draw_bar "$pct"
      fi
    fi
    sleep 0.5
  done
  draw_bar 100
  printf '\n\n'

  wait "$CURRENT_PID"
  local status=$?
  CURRENT_PID=""
  rm -f "$progress_file"
  return $status
}

# --- loop principal -----------------------------------------------------------
TOTAL=${#FILES[@]}
i=0
for file in "${FILES[@]}"; do
  i=$((i + 1))
  [[ -f "$file" ]] || continue

  orig_size=$(stat -c%s "$file")

  if [[ -n "${NO_GAIN["$file:$orig_size"]:-}" ]]; then
    warn "Sem ganho de compressão já testado anteriormente: $(truncate_name "$file" 60), pulando."
    continue
  fi

  duration_raw=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$file" 2>/dev/null || echo 0)
  duration=${duration_raw%.*}
  [[ -z "$duration" || "$duration" == "N/A" ]] && duration=0
  codec=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of csv=p=0 "$file" 2>/dev/null || echo "?")
  res=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0:s=x "$file" 2>/dev/null || echo "?")

  display_name=$(truncate_name "$file" 60)

  case "$codec" in
  hevc | h265 | av1)
    warn "Já está em ${codec} (provavelmente já compactado): $display_name, pulando."
    continue
    ;;
  esac

  sep
  card "🎬 [$i/$TOTAL] $display_name" \
    "Tamanho original: $(human "$orig_size")" \
    "Resolução: ${res:-?}   Codec atual: ${codec:-?}" \
    "Duração: $(fmt_dur "$duration_raw")" \
    "Encoder de saída: ${ENCODER_LABEL}"

  out="${file%.*}.shrunk.mp4"
  if [[ -e "$out" ]]; then
    warn "Já existe $(truncate_name "$out" 60), pulando."
    continue
  fi

  CURRENT_OUT="$out"
  start_ts=$(date +%s)
  if run_with_progress "$file" "$out" "$duration"; then
    end_ts=$(date +%s)
    new_size=$(stat -c%s "$out")
    reduction=$(awk -v o="$orig_size" -v n="$new_size" 'BEGIN{ if (o>0) printf "%.1f", (o-n)*100/o; else print "0" }')
    elapsed=$((end_ts - start_ts))

    if ((new_size >= orig_size)); then
      rm -f "$out"
      mark_no_gain "$file" "$orig_size"
      card "⚠️ Sem ganho: $display_name" \
        "Original:    $(human "$orig_size")" \
        "Compactado:  $(human "$new_size") (maior ou igual)" \
        "Tempo:        ${elapsed}s"
      warn "Resultado ficou maior que o original, descartado. Original mantido."
      warn "Marcado em ${SKIP_FILE} para não reprocessar."
    else
      card "✅ Concluído: $display_name" \
        "Original:   $(human "$orig_size")" \
        "Compactado:  $(human "$new_size")" \
        "Redução:     ${reduction}%" \
        "Tempo:       ${elapsed}s"

      if gum confirm "Apagar o arquivo original ($display_name)?"; then
        rm -f "$file"
        ok "Original removido."
      fi
    fi
  else
    err "Falha ao compactar: $display_name"
    rm -f "$out"
  fi
  CURRENT_OUT=""

  if [[ $i -lt $TOTAL ]]; then
    if ! gum confirm "Continuar para o próximo vídeo?"; then
      warn "Interrompido pelo usuário."
      break
    fi
  fi
done

ok "Concluído."
