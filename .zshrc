#################################################
################### Options #####################
#################################################
setopt SHARE_HISTORY        # compartilha histórico entre terminais abertos
setopt HIST_IGNORE_ALL_DUPS # não guarda comandos duplicados
setopt autocd

# Histórico
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000

# Alt+Backspace apaga só o último segmento do caminho, como no bash
autoload -Uz select-word-style
select-word-style bash

#################################################
################### Keybindings ################
#################################################
# Keybindings
# create a zkbd compatible hash;
# to add other keys to this hash, see: man 5 terminfo
typeset -g -A key

key[Home]="${terminfo[khome]}"
key[End]="${terminfo[kend]}"
key[Insert]="${terminfo[kich1]}"
key[Backspace]="${terminfo[kbs]}"
key[Delete]="${terminfo[kdch1]}"
key[Up]="${terminfo[kcuu1]}"
key[Down]="${terminfo[kcud1]}"
key[Left]="${terminfo[kcub1]}"
key[Right]="${terminfo[kcuf1]}"
key[PageUp]="${terminfo[kpp]}"
key[PageDown]="${terminfo[knp]}"
key[Shift-Tab]="${terminfo[kcbt]}"
key[Control-Left]="${terminfo[kLFT5]}"
key[Control-Right]="${terminfo[kRIT5]}"

bindkey -e

# setup key accordingly
[[ -n "${key[Control-Left]}"  ]] && bindkey -- "${key[Control-Left]}"  backward-word
[[ -n "${key[Control-Right]}" ]] && bindkey -- "${key[Control-Right]}" forward-word
[[ -n "${key[Home]}"      ]] && bindkey -- "${key[Home]}"       beginning-of-line
[[ -n "${key[End]}"       ]] && bindkey -- "${key[End]}"        end-of-line
[[ -n "${key[Insert]}"    ]] && bindkey -- "${key[Insert]}"     overwrite-mode
[[ -n "${key[Backspace]}" ]] && bindkey -- "${key[Backspace]}"  backward-delete-char
[[ -n "${key[Delete]}"    ]] && bindkey -- "${key[Delete]}"     delete-char
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
[[ -n "${key[Up]}"        ]] && bindkey -- "${key[Up]}"         up-line-or-beginning-search
[[ -n "${key[Down]}"      ]] && bindkey -- "${key[Down]}"       down-line-or-beginning-search
[[ -n "${key[Left]}"      ]] && bindkey -- "${key[Left]}"       backward-char
[[ -n "${key[Right]}"     ]] && bindkey -- "${key[Right]}"      forward-char
[[ -n "${key[PageUp]}"    ]] && bindkey -- "${key[PageUp]}"     beginning-of-buffer-or-history
[[ -n "${key[PageDown]}"  ]] && bindkey -- "${key[PageDown]}"   end-of-buffer-or-history
[[ -n "${key[Shift-Tab]}" ]] && bindkey -- "${key[Shift-Tab]}"  reverse-menu-complete
bindkey -- "\e[H" beginning-of-line
bindkey -- "\e[F" end-of-line
# bindkey -- '^[[H~' beginning-of-line  # Home key
# bindkey -- '^[[4~' end-of-line        # End key
bindkey "\e[1;5C" forward-word
bindkey "\e[1;5D" backward-word

# Finally, make sure the terminal is in application mode, when zle is
# active. Only then are the values from $terminfo valid.
if (( ${+terminfo[smkx]} && ${+terminfo[rmkx]} )); then
	autoload -Uz add-zle-hook-widget
	function zle_application_mode_start { echoti smkx }
	function zle_application_mode_stop { echoti rmkx }
	add-zle-hook-widget zle-line-init zle_application_mode_start
	add-zle-hook-widget zle-line-finish zle_application_mode_stop
fi

#################################################
################### Aliases #####################
#################################################
# Extension aliases
alias -s {md,mdx}=leaf

# Aliases
alias ssh='TERM=xterm ssh'
alias e='exit'
alias s='sudo su'
alias rehash="source $HOME/.zshrc"
alias pacman='sudo pacman --noconfirm'
alias clean-pacman='pacman -Qdttq | pacman -Rs - 2> /dev/null'
alias paru='paru --noconfirm'
alias ls='ls --color=always --group-directories-first' 
alias mkdir='mkdir -p'
alias mconf="nvim ~/.config/mango/config.conf"
alias nconf="nvim ~/.config/nvim/"
alias wconf="nvim -p ~/.config/waybar/config.jsonc ~/.config/waybar/style.css"
alias fconf="nvim ~/.config/foot/foot.ini"
alias mkconf="nvim ~/.config/mako/config"
alias copiar='wl-copy <'
alias mkcert="certbot certonly --dns-cloudflare --dns-cloudflare-credentials /etc/cloudflare.ini"
alias host='getent hosts'
alias update-ollama='curl https://ollama.ai/install.sh | sh'
alias install-webui='docker run -d -p 4000:8080 -e WEBUI_AUTH=False --gpus all --add-host=host.docker.internal:host-gateway -v open-webui:/app/backend/data --name open-webui --restart always ghcr.io/open-webui/open-webui:cuda'
alias script='TERM=dumb script'

#################################################
################### Functions ###################
#################################################
function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	command yazi "$@" --cwd-file="$tmp"
	IFS= read -r -d '' cwd < "$tmp"
	[ "$cwd" != "$PWD" ] && [ -d "$cwd" ] && builtin cd -- "$cwd"
	command rm -f -- "$tmp"
}

# git
function commit() {
  icon=":robot_face:"
  upstream="$(git config --get remote.origin.url)"
  test "${string#*"github"}" != "$upstream" && icon="🤖"

  #[ -f .commit ] && msg="$(cat .commit)" || msg="Commit automático"
  [ -f .commit ] && msg="$icon $(cat .commit)" || msg="$icon Alterações: $(git status -s -z)"
  [ $1 ] && msg="$@"
  git add .
  git commit -m "$msg"
  git push
}

# fonts
function list-fonts() {
  [ ! $1 ] && return
  fc-list | awk -F':' '{print $2}' | grep -i $1 | awk '{$1=$1};1' | sort | uniq
}

# ssh
function fullsync() {
  [ ! -d $STORAGE/vps/$1 ] && mkdir -p $STORAGE/vps/${1}
  local machine="$1"
  shift

  rsync -aAXvzz \
    --exclude-from "$HOME/.config/rsync-excludes.list" \
    root@${machine}:/ $STORAGE/vps/${machine}/ \
    "$@"
}

# Cleanup
# bun
function clean-bun() {
  bun pm cache rm
  rm -rf ~/.bun/install/cache
}

# npm
function clean-npm() {
  npm cache clean --force
}

# pnpm
function clean-pnpm() {
  pnpm store prune
  # Example (replace the path with your actual store path):
  #rm -rf $(pnpm store path)
}

# docker
function clean-docker() {
  docker system prune -a
}

# podman
function clean-podman() {
  podman system prune -a
}

#################################################
################### Prompt ######################
#################################################
autoload -Uz vcs_info
precmd() { 
    vcs_info
}

# Configuração do Git
zstyle ':vcs_info:git:*' check-for-changes true
zstyle ':vcs_info:git:*' check-for-staged-changes true
zstyle ':vcs_info:git:*' unstagedstr ' %F{red}✗%f'
zstyle ':vcs_info:git:*' stagedstr ' %F{yellow}✓%f'
zstyle ':vcs_info:git:*' formats ' on %F{magenta}%b%f%c%u%m'
zstyle ':vcs_info:git:*' actionformats ' on %F{magenta}%b%f|%F{red}%a%f%c%u%m'
zstyle ':vcs_info:*' enable git

# Hook para detectar untracked files
+vi-git-untracked() {
    if [[ $(git rev-parse --is-inside-work-tree 2>/dev/null) == 'true' ]] && \
       git status --porcelain 2>/dev/null | grep -q '^??'; then
        hook_com[misc]=' %F{cyan}+%f'
    fi
}

# Adiciona o hook
zstyle ':vcs_info:git*+set-message:*' hooks git-untracked

# Status de stash
git_stash_count() {
    if git rev-parse --git-dir &>/dev/null; then
        local stashes=$(git stash list 2>/dev/null | wc -l)
        [[ $stashes -gt 0 ]] && echo " %F{blue}≡$stashes%f"
    fi
}

# Status de push/pull
git_push_status() {
    if git rev-parse --abbrev-ref @{upstream} &>/dev/null; then
        local ahead=$(git rev-list --count @{upstream}..HEAD 2>/dev/null)
        local behind=$(git rev-list --count HEAD..@{upstream} 2>/dev/null)
        
        if [[ $ahead -gt 0 && $behind -gt 0 ]]; then
            echo " %F{yellow}⇕%f"
        elif [[ $ahead -gt 0 ]]; then
            echo " %F{green}↑%f"
        elif [[ $behind -gt 0 ]]; then
            echo " %F{red}↓%f"
        fi
    fi
}

setopt PROMPT_SUBST

# Prompt principal (uma linha)
PROMPT='%F{cyan}%n%f in %F{yellow}%~%f${vcs_info_msg_0_}$(git_stash_count)$(git_push_status) %(?.%F{green}.%F{red})❯%f '

# bun completions
[ -s "/home/lucas/.bun/_bun" ] && source "/home/lucas/.bun/_bun"

source /usr/share/doc/pkgfile/command-not-found.zsh
# kimi-code
export PATH="/home/lucas/.kimi-code/bin:$PATH"
