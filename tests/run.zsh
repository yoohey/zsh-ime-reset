#!/usr/bin/env zsh
# Test for zsh-ime-reset: runs an interactive zsh with the plugin, with fake fcitx5-remote / macism / ibus /
# powershell.exe commands first in PATH that record their calls, presses Enter or other keys (and sends the focus
# reports of a terminal), and checks that the IME command ran, or how many times.
#   ./tests/run.zsh
zmodload zsh/zpty || exit 1
emulate -L zsh
PLUGIN=${PLUGIN:-${0:A:h:h}/zsh-ime-reset.plugin.zsh}   # PLUGIN=file tests another file, e.g. the README block
TMP=$(mktemp -d) || exit 1
trap 'rm -rf -- $TMP' EXIT
# PATH for the test shell: the fakes, plus only the tools they need, so a real fcitx5-remote etc. in /usr/bin
# (WSL often has one) cannot win over a fake
mkdir -p $TMP/sys && ln -s ${commands[sh]} ${commands[mkfifo]} $TMP/sys/ || exit 1
ng=0

# start <command to fake>: makes the fake and .zshrc, and starts the test shell (zpty "t") up to its first prompt.
# PRE: shell lines to run before loading the plugin; PLUGIN: the file to load (default: zsh-ime-reset.plugin.zsh).
start_() {
  local cmd=$1
  rm -rf $TMP/bin $TMP/log $TMP/zdot; mkdir -p $TMP/bin $TMP/zdot
  if [[ $cmd == powershell.exe ]]; then
    # records every line PowerShell would run; the line for the IME is compared below
    print -r -- "#!/bin/sh
while IFS= read -r l; do case \"\$l\" in *ZshImeReset*::*) echo \"\$l\" >> $TMP/log ;; esac; done" > $TMP/bin/$cmd
    chmod +x $TMP/bin/$cmd
  elif [[ -n $cmd ]]; then
    print -r -- "#!/bin/sh
if [ \"\$1\" = \"\" ] && [ \"$cmd\" = macism ]; then echo ${MACISM_NOW:-com.apple.keylayout.Kotoeri}; exit 0; fi
echo \"$cmd \$*\" >> $TMP/log" > $TMP/bin/$cmd
    chmod +x $TMP/bin/$cmd
  fi
  # emacs keys, also where EDITOR is vi (zsh would pick the vi keymap)
  print -r -- "PROMPT='P> '
bindkey -e
$PRE
source ${(q)PLUGIN}" > $TMP/zdot/.zshrc
  zpty -b t "PATH=$TMP/bin:$TMP/sys ZDOTDIR=$TMP/zdot HOME=$TMP ${commands[zsh]} -i" || return 1
  sleep 1
}

# case <label> <command to fake> <expected log, '' for none>: presses Enter
case_() {
  local label=$1 want=$3
  start_ $2 || return 1
  zpty -w t $'true\r'
  sleep 1
  zpty -d t
  sleep 0.5   # until the closed shell has ended, so that nothing it does reaches the next case
  # the pty can deliver one Enter as two, so only the first call is compared
  local got=; [[ -f $TMP/log ]] && got=$(head -n 1 $TMP/log)
  if [[ $got == $want ]]; then print "OK  $label"; else print "NG  $label: want '$want', got '$got'"; (( ng++ )); fi
}

# keys <label> <command to fake> <keys> <expected number of calls>: types the keys (no Enter) and counts the calls
keys_() {
  local label=$1 keys=$3 want=$4
  start_ $2 || return 1
  zpty -w -n t $keys
  sleep 1
  # counted before the shell is closed: closing it ends the line, which may switch once more (and late)
  local -a calls; [[ -s $TMP/log ]] && calls=(${(f)"$(<$TMP/log)"})
  local got=$#calls
  zpty -d t
  sleep 0.5
  if (( got == want )); then print "OK  $label"; else print "NG  $label: want $want calls, got $got"; (( ng++ )); fi
}

case_ 'fcitx5-remote -c runs on Enter' fcitx5-remote 'fcitx5-remote -c'
MACISM_NOW=com.apple.keylayout.Kotoeri case_ 'macism switches to ABC when not ABC' macism 'macism com.apple.keylayout.ABC'
MACISM_NOW=com.apple.keylayout.ABC case_ 'macism does nothing when already ABC' macism ''
case_ 'ibus engine switches to the keyboard engine' ibus 'ibus engine xkb:jp::jpn'
case_ 'nothing happens without either command' '' ''
PLUGIN=${0:A:h:h}/zsh-ime-reset-wsl.plugin.zsh PRE="XDG_RUNTIME_DIR=$TMP ZSH_IME_RESET_WSL_IDLE=3" \
  case_ 'WSL file: Enter makes the shared PowerShell close the IME' powershell.exe '[ZshImeReset]::Off()'
PRE='ZSH_IME_RESET_ON_ENTER=0' case_ 'Enter does nothing with ZSH_IME_RESET_ON_ENTER=0' fcitx5-remote ''

# The head of the line (\x01 Ctrl+A, \x05 Ctrl+E, \x15 Ctrl+U, \x7f Backspace) and focus (\e[I in, \e[O out)
keys_ 'nothing at the first prompt, nor while typing' fcitx5-remote 'abc' 0
keys_ 'Ctrl+A to the head: once' fcitx5-remote $'abc\x01' 1
keys_ 'Ctrl+A again at the head: still once' fcitx5-remote $'abc\x01\x01' 1
keys_ 'Ctrl+U clears the line: once' fcitx5-remote $'abc\x15' 1
keys_ 'Backspace up to the head: once' fcitx5-remote $'a\x7f' 1
keys_ 'back at the head twice: twice' fcitx5-remote $'abc\x01\x05\x01' 2
# "e" matches "true" (the cursor at 3), then "ec" matches "echo hi" (at the head)
PRE='print -s "echo hi"; print -s true' keys_ 'not in Ctrl+R, even when the match moves to the head' fcitx5-remote $'\x12ec' 0
PRE='ZSH_IME_RESET_ON_HEAD=0' keys_ 'Ctrl+A does nothing with ZSH_IME_RESET_ON_HEAD=0' fcitx5-remote $'abc\x01' 0
keys_ 'focus in on an empty line: once' fcitx5-remote $'\e[I' 1
keys_ 'focus in with the cursor in the middle: none' fcitx5-remote $'ab\e[I' 0
keys_ 'focus out keeps the line (Ctrl+A after it still moves to the head)' fcitx5-remote $'ab\e[O\x01' 1
PRE='ZSH_IME_RESET_ON_FOCUS=0' keys_ 'focus in does nothing with ZSH_IME_RESET_ON_FOCUS=0' fcitx5-remote $'\e[I' 0
PLUGIN=${0:A:h:h}/zsh-ime-reset-wsl.plugin.zsh PRE="XDG_RUNTIME_DIR=$TMP ZSH_IME_RESET_WSL_IDLE=3" \
  keys_ 'WSL file: Ctrl+A to the head closes the IME' powershell.exe $'abc\x01' 1
PLUGIN=${0:A:h:h}/zsh-ime-reset-wsl.plugin.zsh PRE="XDG_RUNTIME_DIR=$TMP ZSH_IME_RESET_WSL_IDLE=3" \
  keys_ 'WSL file: focus in on an empty line closes the IME' powershell.exe $'\e[I' 1
exit $ng
