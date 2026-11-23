#!/bin/sh
# System-wide dark preference: read by xdg-desktop-portal (browsers, Electron,
# libadwaita/GTK4) and by GTK3 apps that ignore settings.ini.
command -v gsettings >/dev/null || exit 0
gsettings set org.gnome.desktop.interface color-scheme prefer-dark
gsettings set org.gnome.desktop.interface gtk-theme Adwaita-dark
