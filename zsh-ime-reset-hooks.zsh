# zsh-ime-reset-hooks - when to switch the IME back. Read by zsh-ime-reset.plugin.zsh and zsh-ime-reset-wsl.plugin.zsh
# after they have defined _ime_reset (the command that switches to alphanumeric); not meant to be loaded on its own.
#
# 【日本語の要約】英数に戻す「場面」をまとめたファイル。どの場面も、変数を 0 にすると止まる（開いているシェルでも、すぐ効く）。
#   ZSH_IME_RESET_ON_ENTER=0   Enter で行を確定したとき
#   ZSH_IME_RESET_ON_HEAD=0    カーソルが行の先頭に着いたとき（Ctrl+A、Ctrl+U、Backspace で先頭まで消したとき など）
#   ZSH_IME_RESET_ON_FOCUS=0   端末にフォーカスが来たときに、カーソルが先頭なら（次のプロンプトから効く）
#
# A command starts at the head of the line, so alphanumeric is what comes next there. Each moment can be turned off
# by setting its variable to 0, in .zshrc or in a running shell (checked each time):
# - ZSH_IME_RESET_ON_ENTER: when Enter accepts the line (zle-line-finish). Not precmd: precmd also runs when a
#   background job ends, and would switch off the IME of whatever window has the focus then.
# - ZSH_IME_RESET_ON_HEAD: when the cursor moves to the head of the line (Ctrl+A, Ctrl+U, Backspace up to the head
#   ...), only at the moment it gets there, not on every redraw while it stays. A new prompt starts at the head
#   without counting (Enter has switched already), and so does a prompt redrawn when a background job ends. Skipped
#   in the incremental history search, where the cursor jumps with the matches while Japanese may be typed.
# - ZSH_IME_RESET_ON_FOCUS: when the terminal gets the focus while the cursor is at the head. The terminal is asked to
#   report focus as \e[I / \e[O (focus reporting, \e[?1004h) only while the line is edited, and stops before a command
#   runs, so the command gets no reports it did not ask for. Terminals without focus reporting ignore the request.
#   In tmux (focus-events on), only the active pane gets the reports, and selecting a pane or a window sends \e[I to
#   it too. A tmux client that never reports focus (it stays "focused") keeps the pane focused, so the reports stop
#   while one is attached. Takes effect from the next prompt.
#
# https://github.com/yoohey/zsh-ime-reset - MIT License

typeset -gi _ime_reset_last_cursor=0 _ime_reset_focus_on=0
_ime_reset_line_init() {
  _ime_reset_last_cursor=0
  if [[ ${ZSH_IME_RESET_ON_FOCUS:-1} != 0 ]]; then
    print -n '\e[?1004h'
    _ime_reset_focus_on=1
  fi
}
_ime_reset_line_finish() {
  [[ ${ZSH_IME_RESET_ON_ENTER:-1} != 0 ]] && _ime_reset
  if (( _ime_reset_focus_on )); then
    print -n '\e[?1004l'
    _ime_reset_focus_on=0
  fi
  return 0
}
_ime_reset_line_redraw() {
  # ISEARCHMATCH_ACTIVE: the incremental search shows a match ($LASTWIDGET does not tell: in a hook, it is a hook)
  if [[ ${ZSH_IME_RESET_ON_HEAD:-1} != 0 ]] &&
      (( CURSOR == 0 && _ime_reset_last_cursor != 0 && ! ISEARCHMATCH_ACTIVE )); then
    _ime_reset
  fi
  _ime_reset_last_cursor=$CURSOR
}
_ime_reset_focus_in() {
  [[ ${ZSH_IME_RESET_ON_FOCUS:-1} != 0 ]] && (( CURSOR == 0 )) && _ime_reset
  return 0
}
# \e[O needs a binding of its own: unbound, it is read as Esc followed by "[O" (in vi command mode, "O" opens a line)
_ime_reset_focus_out() { }
zle -N _ime_reset_focus_in
zle -N _ime_reset_focus_out
() {
  local keymap
  for keymap in emacs viins vicmd; do
    bindkey -M $keymap '^[[I' _ime_reset_focus_in
    bindkey -M $keymap '^[[O' _ime_reset_focus_out
  done
}

autoload -Uz add-zle-hook-widget
add-zle-hook-widget zle-line-init _ime_reset_line_init
add-zle-hook-widget zle-line-pre-redraw _ime_reset_line_redraw
add-zle-hook-widget zle-line-finish _ime_reset_line_finish
