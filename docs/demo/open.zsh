#!/usr/bin/env zsh
# Opens a foot window for recording the demo GIF: a large font, a short prompt, and a zsh that loads only this
# plugin (not your .zshrc, no tmux), in a folder with a few files to list. Record the window with the screen
# recorder of the desktop (GNOME: Print, then the video button, then select the window), close it when done, and
# make the GIF with to-gif.sh next to this file.
#   docs/demo/open.zsh [plugin file]   (default: zsh-ime-reset.plugin.zsh of this repository)
# DEMO_FONT and DEMO_SIZE (columns x lines) change the look.
emulate -L zsh
local root=${0:A:h:h:h}
local plugin=${1:-$root/zsh-ime-reset.plugin.zsh}
[[ -r $plugin ]] || { print -u2 "no such file: $plugin"; exit 1 }
(( $+commands[foot] )) || { print -u2 'foot is not installed'; exit 1 }
local dir
dir=$(mktemp -d) || exit 1
trap 'rm -rf -- $dir' EXIT
mkdir -p $dir/demo/src && : > $dir/demo/README.md && : > $dir/demo/notes.txt && : > $dir/demo/src/main.c
cat > $dir/.zshrc <<EOF
PROMPT='%F{green}%~%f \$ '
bindkey -e
unset HISTFILE   # nothing typed in the demo is kept
source ${(q)plugin}
cd ~/demo
EOF
# HOME only for zsh (the prompt shows ~/demo); foot keeps yours, for its config and fonts
foot -T 'zsh-ime-reset demo' -W ${DEMO_SIZE:-48x8} \
  -o "main.font=${DEMO_FONT:-UDEV Gothic NF:size=22}" -o main.pad=16x16 env HOME=$dir ZDOTDIR=$dir zsh -i
