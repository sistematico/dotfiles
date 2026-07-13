# Dotfiles

Meus arquivos de configuração pessoais (dotfiles) — shell, editor, SSH e
afins — versionados em Git para facilitar backup e replicação em novas
máquinas.

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
