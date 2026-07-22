#!/usr/bin/env bash
# Varre diretórios em busca de *.AppImage sem entrada .desktop e cria as entradas.
set -euo pipefail

SCAN_DIRS=("$HOME/downloads" "$HOME/Applications")
APPS_DIR="$HOME/.local/share/applications"
ICONS_DIR="$HOME/.local/share/icons/appimages"
STORE_DIR="$HOME/app"   # onde os AppImages "instalados" vivem

mkdir -p "$APPS_DIR" "$ICONS_DIR" "$STORE_DIR"

slugify() {
    # nome_do_arquivo.AppImage -> nome-do-arquivo
    basename "$1" .AppImage | tr -c 'A-Za-z0-9._-' '-' | tr 'A-Z' 'a-z'
}

extract_icon() {
    local appimage="$1" slug="$2"
    local out_png="$ICONS_DIR/$slug.png"
    local out_svg="$ICONS_DIR/$slug.svg"

    [[ -f "$out_png" || -f "$out_svg" ]] && { echo "$out_png"; return; }

    local tmpdir
    tmpdir=$(mktemp -d)
    (
        cd "$tmpdir"
        "$appimage" --appimage-extract >/dev/null 2>&1 || true
    )

    local root="$tmpdir/squashfs-root"
    if [[ -d "$root" ]]; then
        local icon_src=""
        if [[ -e "$root/.DirIcon" ]]; then
            icon_src="$root/.DirIcon"
        else
            icon_src=$(find "$root" -maxdepth 1 \( -iname '*.png' -o -iname '*.svg' \) | head -n1)
        fi
        if [[ -n "$icon_src" ]]; then
            if [[ "$icon_src" == *.svg ]]; then
                cp "$icon_src" "$out_svg"
                echo "$out_svg"
            else
                cp "$icon_src" "$out_png"
                echo "$out_png"
            fi
        fi
    fi
    rm -rf "$tmpdir"
}

echo "Escaneando: ${SCAN_DIRS[*]}"
found=0
created=0

for dir in "${SCAN_DIRS[@]}"; do
    [[ -d "$dir" ]] || continue
    while IFS= read -r -d '' appimage; do
        found=$((found + 1))
        slug=$(slugify "$appimage")
        desktop_file="$APPS_DIR/appimage-$slug.desktop"

        if [[ -f "$desktop_file" ]]; then
            continue
        fi

        chmod +x "$appimage"

        # Move para o diretório de "instalação" se ainda não estiver lá
        target="$appimage"
        if [[ "$dir" != "$STORE_DIR" ]]; then
            target="$STORE_DIR/$(basename "$appimage")"
            if [[ ! -f "$target" ]]; then
                mv "$appimage" "$target"
            fi
        fi

        name=$(basename "$target" .AppImage | sed -E 's/[-_]/ /g; s/[0-9]+\.[0-9.]+.*$//')
        name=${name:-$slug}
        icon=$(extract_icon "$target" "$slug" || true)
        icon=${icon:-application-x-executable}

        cat > "$desktop_file" <<EOF
[Desktop Entry]
Type=Application
Name=${name}
Exec="${target}" %U
Icon=${icon}
Comment=AppImage instalado automaticamente
Categories=Utility;
Terminal=false
EOF
        chmod +x "$desktop_file"
        echo "Criado: $desktop_file -> $target"
        created=$((created + 1))
    done < <(find "$dir" -maxdepth 1 -iname '*.AppImage' -print0)
done

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$APPS_DIR" >/dev/null 2>&1 || true
fi

echo "Encontrados: $found | Novos .desktop criados: $created"
