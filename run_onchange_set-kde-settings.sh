#!/bin/sh
# KDE apps (Dolphin etc.) outside Plasma: dark theme + drag-and-drop behaviour.
# Set individual keys rather than managing kdeglobals/dolphinrc, which hold runtime state.
command -v kwriteconfig6 >/dev/null || exit 0
kwriteconfig6 --file dolphinrc --group UiSettings --key ColorScheme BreezeDark
kwriteconfig6 --file kdeglobals --group General --key ColorScheme BreezeDark
kwriteconfig6 --file kdeglobals --group Icons --key Theme breeze-dark
kwriteconfig6 --file kdeglobals --group KDE --key widgetStyle Breeze
# Drop moves files instead of popping up the Copy/Move/Link menu (same drive only;
# cross-drive drops still ask — hold Shift to move, Ctrl to copy)
kwriteconfig6 --file kdeglobals --group KDE --key DndBehavior MoveIfSameDevice
