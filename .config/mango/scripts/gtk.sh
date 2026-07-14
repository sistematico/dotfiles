#!/usr/bin/env sh

# Aguardar dbus estar pronto
sleep 1

# Re-habilite o colar com o mouse do meio
gsettings set org.gnome.desktop.interface gtk-enable-primary-paste true

# Configurações de tema e ícones
gsettings set org.gnome.desktop.interface color-scheme prefer-dark
gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'
#gsettings set org.gnome.desktop.interface icon-theme 'Newaita-dark'
gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark'

# Configurações de aplicações GTK
gsettings set org.gnome.desktop.interface cursor-theme 'Adwaita'
gsettings set org.gnome.desktop.interface font-name 'Sans 10'
gsettings set org.gnome.desktop.interface document-font-name 'Sans 10'
gsettings set org.gnome.desktop.interface monospace-font-name 'Monospace 10'

# Icons
gsettings set org.gnome.desktop.interface menus-have-icons true
gsettings set org.gnome.desktop.interface buttons-have-icons true

# File chooser preferences
gsettings set org.gnome.nautilus.preferences always-use-location-entry true
gsettings set org.gtk.Settings.FileChooser sort-directories-first true
gsettings set org.gtk.gtk4.Settings.FileChooser sort-directories-first true
gsettings set org.gtk.Settings.FileChooser show-hidden false
gsettings set org.gtk.gtk4.Settings.FileChooser show-hidden false

# Forçar tema escuro via dconf para GTK3 e GTK4
dconf write /org/gnome/desktop/interface/color-scheme "'prefer-dark'"
dconf write /org/gnome/desktop/interface/gtk-theme "'Adwaita-dark'"

# Criar/atualizar arquivo de configuração GTK3
mkdir -p ~/.config/gtk-3.0
cat > ~/.config/gtk-3.0/settings.ini << EOF
[Settings]
gtk-application-prefer-dark-theme=1
gtk-theme-name=Adwaita-dark
gtk-icon-theme-name=Newaita
gtk-cursor-theme-name=Adwaita
gtk-font-name=Sans 10
gtk-enable-mnemonics=1
gtk-menu-images=1
gtk-button-images=1
EOF

# Criar/atualizar arquivo de configuração GTK4
mkdir -p ~/.config/gtk-4.0
cat > ~/.config/gtk-4.0/settings.ini << EOF
[Settings]
gtk-application-prefer-dark-theme=1
gtk-theme-name=Adwaita-dark
gtk-icon-theme-name=Newaita
gtk-cursor-theme-name=Adwaita
gtk-font-name=Sans 10
gtk-enable-mnemonics=1
gtk-menu-images=1
gtk-button-images=1
EOF

