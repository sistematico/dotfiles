#!/bin/bash

# --ctx-size 0 --jinja -ub 2048 -b 2048
# llama-server -hf ggml-org/gpt-oss-20b-GGUF  --ctx-size 0 --jinja -ub 2048 -b 2048
llama-server \
  --models-dir ~/models \
  -hf ggml-org/gpt-oss-20b-GGUF \
  --ui-mcp-proxy \
  --no-models-autoload \
  --jinja \
  --host 127.0.0.1 \
  --port 1080 \
  -ngl 999 \
  -c 32768
