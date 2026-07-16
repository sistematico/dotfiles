#!/bin/bash

MODELS=("google/gemma-4-e4b" "microsoft/phi-4-reasoning-plus" "qwen/qwen3.6-27b" "qwen/qwen3.6-35b-a3b" "google/gemma-4-e4b")
MODEL="${MODELS[0]}"
LMS="$HOME/.lmstudio/bin/lms"
LMSTUDIO_URL="http://localhost:1234/v1"

# Inicia o LM Studio se não estiver acessível
if ! curl -sf --connect-timeout 2 "$LMSTUDIO_URL/models" >/dev/null 2>&1; then
  echo "LM Studio offline. Iniciando servidor..."
  "$LMS" server start &>/dev/null

  for i in $(seq 1 20); do
    sleep 2
    if curl -sf --connect-timeout 2 "$LMSTUDIO_URL/models" >/dev/null 2>&1; then
      echo "LM Studio pronto."
      break
    fi
    if [ "$i" -eq 20 ]; then
      echo "Erro: LM Studio não iniciou após 40s"
      exit 1
    fi
  done
fi

# Carrega o modelo se nenhum estiver ativo
LOADED=$(curl -sf "$LMSTUDIO_URL/models" | jq -r '.data[0].id // empty')
if [ -z "$LOADED" ]; then
  echo "Carregando modelo..."
  "$LMS" load $MODEL &>/dev/null &
  for i in $(seq 1 30); do
    sleep 2
    LOADED=$(curl -sf "$LMSTUDIO_URL/models" | jq -r '.data[0].id // empty')
    if [ -n "$LOADED" ]; then
      echo "Modelo pronto: $LOADED"
      break
    fi
    if [ "$i" -eq 30 ]; then
      echo "Erro: modelo não carregou após 60s"
      exit 1
    fi
  done
fi

# Pega o diff do staged
DIFF=$(git diff --cached)

if [ -z "$DIFF" ]; then
  echo "Nenhuma mudança staged para commit"
  exit 1
fi

PROMPT="Write a single-line git commit message in English for the following diff. Use the Conventional Commits format (e.g. feat:, fix:, refactor:). Output ONLY the commit message — no explanations, no markdown, no extra lines.

$DIFF"

START=$(date +%s.%N)
MSG=$(pi -p --no-tools "$PROMPT" | grep -m1 -E '^(feat|fix|refactor|chore|docs|style|test|perf|ci|build|revert)(\(.+\))?!?:')
END=$(date +%s.%N)
ELAPSED=$(echo "$END - $START" | bc)
echo "Modelo: $MODEL | Tempo: ${ELAPSED}s"

if [ -z "$MSG" ]; then
  echo "Erro: resposta inválida do modelo"
  exit 1
fi

echo "Commit: $MSG"
git commit -m "$MSG"
