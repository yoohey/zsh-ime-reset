# zsh-ime-reset - switch the input method back to alphanumeric every time you press Enter at the zsh prompt.
#
# In a terminal, alphanumeric is almost always what you want next. Type Japanese (or any IME input) only when
# you need it, and the next Enter puts you back, so the next command never starts as garbled kana.
#
# Supported (used when the command is found):
#   Linux, fcitx5   fcitx5-remote -c
#   macOS           macism com.apple.keylayout.ABC   (brew install laishulu/homebrew/macism)
# Where neither exists (a server, WSL2 without fcitx5), it adds nothing and prints nothing.
#
# It hooks zle-line-finish, which runs when the line is accepted, i.e. only in the terminal that has the focus.
# A precmd hook would also fire when a background command ends, and would switch off the IME of whatever
# window has the focus at that moment.
#
# https://github.com/yoohey/zsh-ime-reset - MIT License

if (( $+commands[fcitx5-remote] )); then
  _ime_reset() { fcitx5-remote -c &> /dev/null }
elif (( $+commands[macism] )); then
  # Skipped when it is already ABC, so an ordinary Enter does no extra work
  _ime_reset() { [[ $(macism) == com.apple.keylayout.ABC ]] || macism com.apple.keylayout.ABC &> /dev/null }
else
  return 0
fi
autoload -Uz add-zle-hook-widget
add-zle-hook-widget zle-line-finish _ime_reset
