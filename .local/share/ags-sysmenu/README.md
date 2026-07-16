# ags-sysmenu

Menus para a waybar feitos com AGS v3 (Astal + GTK4), tema Tokyo Night e ícones
Newaita (`Newaita-reborn-dark`, em `~/.local/share/icons`):

- **sysmenu** — estatísticas do sistema, aberto ao pairar sobre o módulo `cpu`.
- **powermenu** — desligar, reiniciar, suspender, bloquear e sair, aberto ao
  pairar sobre o módulo de energia (canto direito). Os comandos são os mesmos
  do waybar: `poweroff`, `reboot`, `systemctl suspend`, `swaylock`,
  `mmsg dispatch quit` — edite em `widget/PowerMenu.tsx` (lista `actions`).

Mostra: uso do processador, memória, disco (/), temperatura da CPU, carga do
sistema (1/5/15 min) e os 6 processos que mais consomem CPU/memória.
Atualiza a cada 2 segundos. `Esc` fecha o menu.

## Uso

```sh
./toggle.sh        # inicia a instância (se preciso) e alterna o menu
ags run .          # rodar em primeiro plano (debug)
ags toggle sysmenu -i sysmenu   # alternar com a instância já rodando
ags quit -i sysmenu             # encerrar
```

## Integração com a waybar

Em `~/.config/waybar/config.jsonc`, adicione o módulo:

```jsonc
"custom/sysmenu": {
    "format": "󰍛",
    "tooltip-format": "Estatísticas do sistema",
    "on-click": "~/.local/share/ags-sysmenu/toggle.sh"
}
```

e inclua `"custom/sysmenu"` em `modules-right`. Opcionalmente, no CSS da waybar:

```css
#custom-sysmenu {
    color: #7aa2f7;
    padding: 0 10px;
}
```

Para o menu abrir instantaneamente no primeiro clique, inicie a instância junto
com a sessão (ex.: `exec-once = ags run ~/.local/share/ags-sysmenu` no Hyprland,
ou o equivalente do seu compositor).

## Abrir ao pairar o mouse (hover)

A waybar não tem ação de hover, então o hover é feito pelo próprio AGS: a janela
invisível `hotzone` (`widget/HotZone.tsx`) fica na camada overlay, sobre o canto
superior direito da barra. Ao passar o mouse ali o menu abre; ao sair do menu
(ou da zona) ele fecha após 300 ms. O clique na zona também alterna o menu.

As zonas são criadas no `app.ts` — uma por menu, com `width`/`height` e
`marginRight`/`marginTop` para alinhar com o módulo correspondente da waybar.
O background delas no CSS usa alfa 0.01: com `transparent` o compositor ignora
o mouse. Importante: a zona fica por cima da waybar, então cliques em módulos
cobertos por ela vão para a zona (que alterna o menu), não para a waybar.

Para o hover funcionar sem clique nenhum, a instância precisa estar rodando —
inicie com a sessão: `ags run ~/.local/share/ags-sysmenu`.

## Arquivos

- `app.ts` — entrada; define a instância `sysmenu` e o tema de ícones Newaita.
- `widget/SystemMenu.tsx` — menu de estatísticas (layer-shell, abaixo da barra).
- `widget/PowerMenu.tsx` — menu de energia (desligar/reiniciar/suspender/bloquear/sair).
- `widget/HotZone.tsx` — zona invisível sobre a barra que abre um menu no hover.
- `widget/hover.ts` — controle compartilhado de mostrar/esconder por hover.
- `scripts/stats.sh` — coleta as estatísticas e imprime JSON (embutido no bundle).
- `style.css` — tema Tokyo Night (CSS puro do GTK4, sem dependência de sass).
