#!/usr/bin/env zsh
# Test for zsh-ime-reset: runs an interactive zsh with the plugin, with fake fcitx5-remote / macism commands
# first in PATH that record their calls, presses Enter, and checks that the IME command ran.
#   ./tests/run.zsh
zmodload zsh/zpty || exit 1
emulate -L zsh
PLUGIN=${0:A:h:h}/zsh-ime-reset.plugin.zsh
TMP=$(mktemp -d) || exit 1
trap 'rm -rf -- $TMP' EXIT
ng=0

# case <label> <command to fake> <expected log, '' for none>
case_() {
  local label=$1 cmd=$2 want=$3 out=
  rm -rf $TMP/bin $TMP/log $TMP/zdot; mkdir -p $TMP/bin $TMP/zdot
  if [[ -n $cmd ]]; then
    print -r -- "#!/bin/sh
if [ \"\$1\" = \"\" ] && [ \"$cmd\" = macism ]; then echo ${MACISM_NOW:-com.apple.keylayout.Kotoeri}; exit 0; fi
echo \"$cmd \$*\" >> $TMP/log" > $TMP/bin/$cmd
    chmod +x $TMP/bin/$cmd
  fi
  print -r -- "PROMPT='P> '
source ${(q)PLUGIN}" > $TMP/zdot/.zshrc
  zpty -b t "PATH=$TMP/bin:/usr/bin:/bin ZDOTDIR=$TMP/zdot HOME=$TMP ${commands[zsh]} -i" || return 1
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
exit $ng
