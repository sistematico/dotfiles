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
