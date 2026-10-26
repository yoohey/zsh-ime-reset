# zsh-ime-reset - switch the input method back to alphanumeric every time you press Enter at the zsh prompt, and when
# the cursor is at the head of the line (it gets there, or the terminal gets the focus with it there).
#
# In a terminal, alphanumeric is almost always what you want next. Type Japanese (or any IME input) only when
# you need it, and the next Enter puts you back, so the next command never starts as garbled kana.
#
# Supported (used when the command is found):
#   Linux, fcitx5   fcitx5-remote -c
#   Linux, ibus     ibus engine xkb:jp::jpn          (Fedora, Ubuntu, ...; for another layout set
#                                                      ZSH_IME_RESET_IBUS_ENGINE=xkb:us::eng before loading)
#   macOS           macism com.apple.keylayout.ABC   (brew install laishulu/homebrew/macism)
# Where none of them exists (a server, WSL2 without fcitx5), it adds nothing and prints nothing.
#
# When it switches, and how to turn each moment off (ZSH_IME_RESET_ON_ENTER / _ON_HEAD / _ON_FOCUS=0), is in
# zsh-ime-reset-hooks.zsh next to this file.
#
# WSL2 is a separate file, zsh-ime-reset-wsl.plugin.zsh (the Windows IME needs a resident PowerShell, which is
# too much to carry into other systems). On WSL2 load that file instead of this one.
#
# https://github.com/yoohey/zsh-ime-reset - MIT License

if (( $+commands[fcitx5-remote] )); then
  _ime_reset() { fcitx5-remote -c &> /dev/null }
elif (( $+commands[macism] )); then
  # Skipped when it is already ABC, so an ordinary Enter does no extra work
  _ime_reset() { [[ $(macism) == com.apple.keylayout.ABC ]] || macism com.apple.keylayout.ABC &> /dev/null }
elif (( $+commands[ibus] )); then
  _ime_reset() { ibus engine ${ZSH_IME_RESET_IBUS_ENGINE:-xkb:jp::jpn} &> /dev/null }
else
  return 0
fi
# When to switch (Enter, the head of the line, focus; each can be turned off): zsh-ime-reset-hooks.zsh next to this
# file. Without it (only this file copied), on Enter only, as before.
if [[ -r ${${(%):-%x}:A:h}/zsh-ime-reset-hooks.zsh ]]; then
  source ${${(%):-%x}:A:h}/zsh-ime-reset-hooks.zsh
else
  autoload -Uz add-zle-hook-widget
  add-zle-hook-widget zle-line-finish _ime_reset
fi
