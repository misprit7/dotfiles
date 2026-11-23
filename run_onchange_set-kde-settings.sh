#!/bin/sh
# KDE apps (Dolphin etc.) outside Plasma: dark theme + drag-and-drop behaviour.
# Set individual keys rather than managing kdeglobals/dolphinrc, which hold runtime state.
command -v kwriteconfig6 >/dev/null || exit 0
kwriteconfig6 --file dolphinrc --group UiSettings --key ColorScheme BreezeDark
# Outside Plasma nothing copies the scheme's colours into kdeglobals, and KDE
# widgets read them from there; with only the name set, Dolphin's file view
# mixes light defaults into the dark palette. Copy every group/key across.
scheme=/usr/share/color-schemes/BreezeDark.colors
if [ -f "$scheme" ]; then
  awk '
    /^\[/ { n = split(substr($0, 2, length($0) - 2), g, "\\]\\["); grp = ""
             for (i = 1; i <= n; i++) grp = grp " --group \"" g[i] "\""; next }
    /=/ && grp != "" { k = substr($0, 1, index($0, "=") - 1); v = substr($0, index($0, "=") + 1)
             gsub(/"/, "\\\"", v)
             print "kwriteconfig6 --file kdeglobals" grp " --key \"" k "\" \"" v "\"" }
  ' "$scheme" | sh
fi
kwriteconfig6 --file kdeglobals --group General --key ColorScheme BreezeDark
kwriteconfig6 --file kdeglobals --group Icons --key Theme breeze-dark
kwriteconfig6 --file kdeglobals --group KDE --key widgetStyle Breeze
# Drop moves files instead of popping up the Copy/Move/Link menu (same drive only;
# cross-drive drops still ask — hold Shift to move, Ctrl to copy)
kwriteconfig6 --file kdeglobals --group KDE --key DndBehavior MoveIfSameDevice
