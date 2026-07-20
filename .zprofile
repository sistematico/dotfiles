export LLAMA_BASE_URL=http://127.0.0.1:1080
export LLAMA_API_KEY=key
export EDITOR=vim
export BUN_INSTALL="$HOME/.bun"
export PNPM_HOME="/home/lucas/.local/share/pnpm"
export N_PREFIX="$HOME/.n"
export PATH=$(go env GOPATH)/bin:$HOME/bin:$HOME/.local/bin:$HOME/.npm-global/bin:$PNPM_HOME/bin:$BUN_INSTALL/bin:$N_PREFIX/bin:$HOME/.lmstudio/bin:$PATH
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$UID/bus
export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/podman/podman.sock

if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
  exec dbus-run-session mango
fi
