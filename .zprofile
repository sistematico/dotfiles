export PATH=$PATH:$HOME/bin:$HOME/.local/bin

if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
  exec dbus-run-session mango
fi
