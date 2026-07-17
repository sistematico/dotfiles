# Dotfiles

Meus arquivos de configuração pessoais (dotfiles) — shell, editor, SSH e
afins — versionados em Git para facilitar backup e replicação em novas
máquinas.

## Symlinks

Tabela de todos os arquivos/pastas do `$HOME` que são symlinks apontando para dentro deste repositório, e o que já está "trackeado" aqui. Mantida automaticamente pelo script `dotfile-track.sh` (Thunar Custom Action) sempre que um novo item é movido para cá.

| Origem | Aponta para |
| --- | --- |
| `~/.config/mako` | `~/dotfiles/.config/mako` |
| `~/.config/swaylock` | `~/dotfiles/.config/swaylock` |
| `~/.config/rofi` | `~/dotfiles/.config/rofi` |
| `~/.local/share/ags-sysmenu` | `~/dotfiles/.local/share/ags-sysmenu` |
| `~/.config/Thunar/uca.xml` | `~/dotfiles/.config/Thunar/uca.xml` |
| `~/bin/rofi-app-toggle` | `~/dotfiles/bin/rofi-app-toggle` |
| `~/bin/luks.sh` | `~/dotfiles/bin/luks.sh` |
| `~/.config/foot/foot.ini` | `~/dotfiles/.config/foot/foot.ini` |
| `~/.config/gtk-3.0/settings.ini` | `~/dotfiles/.config/gtk-3.0/settings.ini` |
| `~/.config/gtk-4.0/settings.ini` | `~/dotfiles/.config/gtk-4.0/settings.ini` |
| `~/.config/mango` | `~/dotfiles/.config/mango` |
| `~/.config/mpd/mpd.conf` | `~/dotfiles/.config/mpd/mpd.conf` |
| `~/.config/mpv/input.conf` | `~/dotfiles/.config/mpv/input.conf` |
| `~/.config/mpv/mpv.conf` | `~/dotfiles/.config/mpv/mpv.conf` |
| `~/.config/ncmpcpp/bindings` | `~/dotfiles/.config/ncmpcpp/bindings` |
| `~/.config/ncmpcpp/config` | `~/dotfiles/.config/ncmpcpp/config` |
| `~/.config/nvim/init.lua` | `~/dotfiles/.config/nvim/init.lua` |
| `~/.config/nvim/lua` | `~/dotfiles/.config/nvim/lua` |
| `~/.config/senpai/senpai.scfg` | `~/dotfiles/.config/senpai/senpai.scfg` |
| `~/.config/waybar` | `~/dotfiles/.config/waybar` |
| `~/.config/wlogout` | `~/dotfiles/.config/wlogout` |
| `~/.local/bin/aicommit.sh` | `~/dotfiles/.local/bin/aicommit.sh` |
| `~/.local/bin/dotfile-track.sh` | `~/dotfiles/.local/bin/dotfile-track.sh` |
| `~/.local/bin/rofi-pass.sh` | `~/dotfiles/.local/bin/rofi-pass.sh` |
| `~/.local/bin/screen-recorder.sh` | `~/dotfiles/.local/bin/screen-recorder.sh` |
| `~/.local/bin/screenshot-area.sh` | `~/dotfiles/.local/bin/screenshot-area.sh` |
| `~/.local/bin/screenshot-full.sh` | `~/dotfiles/.local/bin/screenshot-full.sh` |
| `~/.local/bin/video-down.sh` | `~/dotfiles/.local/bin/video-down.sh` |
| `~/.local/bin/video-shrink.sh` | `~/dotfiles/.local/bin/video-shrink.sh` |
| `~/.local/bin/ytmusic.sh` | `~/dotfiles/.local/bin/ytmusic.sh` |
| `~/.npmrc` | `~/dotfiles/.npmrc` |
| `~/.pi/agent/models.json` | `~/dotfiles/.pi/agent/models.json` |
| `~/.ssh/config` | `~/dotfiles/.ssh/config` |
| `~/.tmux.conf` | `~/dotfiles/.tmux.conf` |
| `~/.vimrc` | `~/dotfiles/.vimrc` |
| `~/.zprofile` | `~/dotfiles/.zprofile` |
| `~/.zshrc` | `~/dotfiles/.zshrc` |

Este repositório é hospedado em dois lugares ao mesmo tempo:

- **Fonte principal:** [git.paxa.dev](https://git.paxa.dev/lucas/Dotfiles) — servidor Git próprio (repositórios bare)
- **Espelho:** [GitHub](https://github.com/sistematico/dotfiles)

## Configurando o push duplo

Um único `git push` envia para os dois servidores usando um remote com
múltiplas URLs de push. A URL de fetch aponta apenas para o `git.paxa.dev`,
que é a fonte de verdade; o GitHub funciona como espelho.

```sh
# 1. Crie o remote apontando para o servidor próprio (URL usada para fetch)
git remote add origin git@git.paxa.dev:lucas/Dotfiles.git

# 2. Adicione as duas URLs de push
git remote set-url --add --push origin git@git.paxa.dev:lucas/Dotfiles.git
git remote set-url --add --push origin git@github.com:sistematico/dotfiles.git
```

> O primeiro `set-url --add --push` é necessário mesmo para a URL original:
> assim que qualquer push URL explícita é definida, a URL de fetch deixa de
> ser usada para push, então ela precisa ser re-adicionada.

Verifique a configuração:

```sh
git remote -v
# origin  git@git.paxa.dev:lucas/Dotfiles.git (fetch)
# origin  git@git.paxa.dev:lucas/Dotfiles.git (push)
# origin  git@github.com:sistematico/dotfiles.git (push)
```

## Preparando os servidores

### git.paxa.dev

Se o repositório bare ainda não existir no servidor:

```sh
ssh git@git.paxa.dev "mkdir -p lucas && git init --bare lucas/Dotfiles.git"
```

Convém ter um host configurado no `~/.ssh/config`:

```
Host git.paxa.dev
  HostName git.paxa.dev
  User git
  IdentityFile ~/.ssh/git_paxa
```

### GitHub

Crie o repositório vazio (sem README inicial) em
<https://github.com/new> para o primeiro push não conflitar.

## Uso diário

```sh
git push -u origin main   # primeiro push; envia para os dois servidores
git push                  # pushes seguintes
git pull                  # busca apenas do git.paxa.dev (fonte de verdade)
```

## Gerenciando senhas com `pass`

O [`pass`](https://www.passwordstore.org/) é o "standard unix password
manager": guarda cada senha em um arquivo `.gpg` individual, criptografado
com sua chave GPG, dentro de `~/.password-store`. Como é só um diretório
de arquivos texto criptografados, o cofre inteiro pode ser versionado em
Git — inclusive neste repositório de dotfiles, se preferir manter tudo
junto.

### Instalação

```sh
# Arch
sudo pacman -S pass

# Debian/Ubuntu
sudo apt install pass

# macOS
brew install pass
```

### Configuração inicial

`pass` precisa de uma chave GPG existente. Se ainda não tiver uma:

```sh
gpg --full-generate-key
```

Depois, inicialize o cofre apontando para o ID (ou e-mail) da chave:

```sh
pass init "seu-email@exemplo.com"
```

Isso cria `~/.password-store` com um arquivo `.gpg-id` guardando qual
chave usar para criptografar as entradas.

### Uso básico

```sh
# Adicionar/gerar uma senha
pass insert github/usuario          # digita a senha manualmente
pass generate github/usuario 20     # gera uma senha aleatória de 20 caracteres

# Ver uma senha
pass github/usuario                 # mostra na tela
pass -c github/usuario              # copia para a área de transferência (some em 45s)

# Listar entradas
pass                                # mostra a árvore inteira
pass ls github                      # lista só um subdiretório

# Editar (abre o arquivo descriptografado no $EDITOR)
pass edit github/usuario

# Buscar
pass grep "algum-termo"

# Remover
pass rm github/usuario
```

Convenção de nomenclatura: organize por serviço/site e, quando fizer
sentido, por usuário — ex. `email/gmail.com`, `banco/nubank`,
`servidores/git.paxa.dev`.

### Versionando o cofre com Git

O `pass` tem integração nativa com Git:

```sh
pass git init
pass git remote add origin git@git.paxa.dev:lucas/password-store.git
pass git push -u origin main
```

A partir daí, todo `pass insert`, `pass edit`, `pass rm` etc. gera um
commit automático no cofre. Use `pass git log` e `pass git push`/`pull`
normalmente.

> Mantenha o cofre de senhas em um repositório **separado** deste
> (dotfiles), já que o conteúdo é sensível mesmo criptografado — evita
> misturar histórico e facilita restringir quem tem acesso ao remoto.

### Sincronizando entre máquinas

Em uma máquina nova, com a chave GPG privada já importada:

```sh
git clone git@git.paxa.dev:lucas/password-store.git ~/.password-store
gpg --import chave-privada.asc   # se ainda não tiver a chave nesta máquina
```

### Integração com o shell

Para copiar senhas rápido, vale um alias:

```sh
alias p='pass -c'
```

E o pacote `pass-otp` adiciona suporte a códigos TOTP (`pass otp`), útil
para 2FA.

### Menu no rofi

O script [`rofi-pass.sh`](.local/bin/rofi-pass.sh) lista as entradas do
cofre num menu do rofi e copia a senha escolhida para a área de
transferência (via `pass show -c`, que some em 45s), com notificação de
sucesso/erro via `notify-send`. A primeira opção do menu, "» Gerar nova
senha", pede o nome da entrada e o tamanho (padrão 20) e chama `pass
generate -c`, pedindo confirmação antes de sobrescrever uma entrada
existente.

```sh
rofi-pass.sh
```

Para abrir com um atalho de teclado, associe o comando `rofi-pass.sh` no
seu compositor (sway/hyprland/mango/etc).
