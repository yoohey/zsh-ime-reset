#!/usr/bin/env zsh
# Test for zsh-ime-reset: runs an interactive zsh with the plugin, with fake fcitx5-remote / macism / ibus /
# powershell.exe commands first in PATH that record their calls, presses Enter, and checks that the IME command ran.
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

# case <label> <command to fake> <expected log, '' for none>
# The WSL branch is switched off (ZSH_IME_RESET_WSL=0) unless PRE says otherwise, so this also runs on WSL.
case_() {
  local label=$1 cmd=$2 want=$3 out=
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
  print -r -- "PROMPT='P> '
${PRE:-ZSH_IME_RESET_WSL=0}
source ${(q)PLUGIN}" > $TMP/zdot/.zshrc
  zpty -b t "PATH=$TMP/bin:$TMP/sys ZDOTDIR=$TMP/zdot HOME=$TMP ${commands[zsh]} -i" || return 1
  sleep 1
  zpty -w t $'true\r'
  sleep 1

  zpty -d t
  # the pty can deliver one Enter as two, so only the first call is compared
  local got=; [[ -f $TMP/log ]] && got=$(head -n 1 $TMP/log)
  if [[ $got == $want ]]; then print "OK  $label"; else print "NG  $label: want '$want', got '$got'"; (( ng++ )); fi
}

case_ 'fcitx5-remote -c runs on Enter' fcitx5-remote 'fcitx5-remote -c'
MACISM_NOW=com.apple.keylayout.Kotoeri case_ 'macism switches to ABC when not ABC' macism 'macism com.apple.keylayout.ABC'
MACISM_NOW=com.apple.keylayout.ABC case_ 'macism does nothing when already ABC' macism ''
case_ 'ibus engine switches to the keyboard engine' ibus 'ibus engine xkb:jp::jpn'
case_ 'nothing happens without either command' '' ''
PRE="ZSH_IME_RESET_WSL=1 XDG_RUNTIME_DIR=$TMP ZSH_IME_RESET_WSL_IDLE=3" \
  case_ 'WSL: Enter makes the shared PowerShell close the IME' powershell.exe '[ZshImeReset]::Off()'
exit $ng
