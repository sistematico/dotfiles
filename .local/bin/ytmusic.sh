#!/usr/bin/env bash
################################################################################
#                                                                              #
# Arquivo: ytmusic.sh                                                          #
# Descrição: Um script para baixar músicas do Youtube e Youtube Music          #
#                                                                              #
# Autor: Lucas Saliés Brum a.k.a. sistematico <lucas@archlinux.com.br>         #
#                                                                              #
# Criado em: 30/04/2019 13:55:09                                               #
# Modificado em: 11/04/2025 13:36:00                                           #
#                                                                              #
# Este trabalho está licenciado com uma Licença Creative Commons               #
# Atribuição 4.0 Internacional                                                 #
# http://creativecommons.org/licenses/by/4.0/                                  #
#                                                                              #
################################################################################

[ ! $1 ] && exit
url="$@"

#COOKIES="--cookies $HOME/.keys/cookies.txt"
#COOKIES="--cookies-from-browser firefox"
#COOKIES=""

yt-dlp -i -c -x \
    $COOKIES \
    -f bestaudio \
    --extract-audio \
    --audio-format mp3 \
    --embed-thumbnail \
    --add-metadata \
    -o "%(artist)s - %(title)s.%(ext)s" \
    "$url"
