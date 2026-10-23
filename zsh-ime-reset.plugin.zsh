# zsh-ime-reset - switch the input method back to alphanumeric every time you press Enter at the zsh prompt.
#
# In a terminal, alphanumeric is almost always what you want next. Type Japanese (or any IME input) only when
# you need it, and the next Enter puts you back, so the next command never starts as garbled kana.
#
# Supported (used when the command is found):
#   WSL2            the Windows IME, through one shared PowerShell (see below)
#   Linux, fcitx5   fcitx5-remote -c
#   Linux, ibus     ibus engine xkb:jp::jpn          (Fedora, Ubuntu, ...; for another layout set
#                                                      ZSH_IME_RESET_IBUS_ENGINE=xkb:us::eng before loading)
#   macOS           macism com.apple.keylayout.ABC   (brew install laishulu/homebrew/macism)
# Where none of them exists (a server), it adds nothing and prints nothing.
#
# It hooks zle-line-finish, which runs when the line is accepted, i.e. only in the terminal that has the focus.
# A precmd hook would also fire when a background command ends, and would switch off the IME of whatever
# window has the focus at that moment.
#
# WSL2: a Linux program cannot touch the Windows IME, so one PowerShell (powershell.exe, part of Windows) is kept
# running for all shells and closes the IME of the foreground window with the Win32 API on request:
#   each zsh --"off"--> FIFO --> relay (a zsh loop) --> powershell.exe -Command -
# - Enter only writes "off" into the FIFO (no waiting). When nobody reads it (not started yet, timed out, crashed),
#   the write fails at once, and the relay and PowerShell are started (about 1.5 s until the first switch).
# - The relay sends the C# definitions below first, then only a fixed line per "off"; it never runs what is
#   written into the FIFO. If PowerShell has died, the relay starts a new one and sends the line again.
#   No .ps1 file is read, so the PowerShell execution policy does not matter.
# - After ZSH_IME_RESET_WSL_IDLE seconds (default 600) without any Enter, the relay ends, and PowerShell ends
#   with it. Set it before loading; it applies to PowerShell started from then on.
# - ZSH_IME_RESET_WSL=0 treats WSL as plain Linux (fcitx5/ibus in WSLg); =1 forces this branch. It is checked
#   before fcitx5, because WSL often has fcitx5-remote too, and that does not reach the Windows IME.
#
# https://github.com/yoohey/zsh-ime-reset - MIT License

if [[ ${ZSH_IME_RESET_WSL:-} == 1 ]] ||
   [[ ${ZSH_IME_RESET_WSL:-} != 0 && -r /proc/version && $(</proc/version) == *[Mm]icrosoft* ]]; then
  typeset -g _ime_reset_wsl_ps=${commands[powershell.exe]}
  [[ -n $_ime_reset_wsl_ps ]] || _ime_reset_wsl_ps=/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe
  [[ -x $_ime_reset_wsl_ps ]] || return 0
  zmodload zsh/system zsh/zselect || return 0
  typeset -g _ime_reset_wsl_fifo=${XDG_RUNTIME_DIR:-/tmp}/zsh-ime-reset-$UID.fifo
  # Sent to PowerShell first: close the IME of the foreground window (WM_IME_CONTROL, IMC_SETOPENSTATUS = 0).
  # A statement over several lines needs an empty line after it in "-Command -", like at an interactive prompt.
  typeset -g _ime_reset_wsl_defs
  read -rd '' _ime_reset_wsl_defs <<'EOF'
Add-Type -TypeDefinition '
using System;
using System.Runtime.InteropServices;
public static class ZshImeReset {
  [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
  [DllImport("imm32.dll")] static extern IntPtr ImmGetDefaultIMEWnd(IntPtr hWnd);
  [DllImport("user32.dll")] static extern IntPtr SendMessage(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam);
  public static void Off() { SendMessage(ImmGetDefaultIMEWnd(GetForegroundWindow()), 0x283, (IntPtr)6, IntPtr.Zero); }
}
'
EOF
  # Opens the FIFO for writing without waiting; fails at once (ENXIO) when no relay reads it
  _ime_reset_wsl_open() {
    [[ -p $_ime_reset_wsl_fifo && -O $_ime_reset_wsl_fifo ]] &&
      sysopen -w -o nonblock -u $1 $_ime_reset_wsl_fifo 2> /dev/null
  }
  _ime_reset_wsl_start() {
    [[ -e $_ime_reset_wsl_fifo ]] || mkfifo -m 600 $_ime_reset_wsl_fifo 2> /dev/null
    [[ -p $_ime_reset_wsl_fifo && -O $_ime_reset_wsl_fifo ]] || return 1
    # One shell at a time (shells opened together, e.g. at login, would each start one). The lock is released
    # when this function returns, or when the shell dies.
    local lock fd
    local lockfile=${_ime_reset_wsl_fifo%.fifo}.lock
    [[ -e $lockfile ]] || : >> $lockfile   # zsystem flock does not create it
    [[ -O $lockfile ]] && zsystem flock -t 2 -f lock $lockfile 2> /dev/null
    if _ime_reset_wsl_open fd; then   # another shell has started it meanwhile
      exec {fd}>&-; [[ -n $lock ]] && zsystem flock -u $lock; return 0
    fi
    # Detached from the terminal: PowerShell in a new session (setsid), the relay without stdin/stdout/stderr on it.
    # Otherwise WSL's /init, which runs powershell.exe, touches the terminal from the background and is stopped
    # (SIGTTOU), and the IME stays on.
    (
      # Also open for writing, so the relay does not see end-of-file each time a shell closes the FIFO
      exec 3<> $_ime_reset_wsl_fifo
      [[ -n $lock ]] && exec {lock}>&-
      local line ps
      ps_start() {   # PowerShell reads from the fd $ps; it ends when $ps is closed (time-out, or the relay ends)
        exec {ps}> >(exec ${commands[setsid]:+setsid} $_ime_reset_wsl_ps -NoProfile -NonInteractive -Command - \
          &> /dev/null 3>&-)
        print -ru $ps -- $_ime_reset_wsl_defs; print -u $ps   # the empty line ends the statement
      }
      ps_start
      trap '' PIPE
      while read -r -t ${ZSH_IME_RESET_WSL_IDLE:-600} -u 3 line; do
        [[ $line == off ]] || continue
        # If PowerShell has died, the write fails: start a new one and send it again, so no Enter is missed
        print -ru $ps -- '[ZshImeReset]::Off()' 2> /dev/null ||
          { exec {ps}>&-; ps_start; print -ru $ps -- '[ZshImeReset]::Off()' 2> /dev/null }
      done
    ) < /dev/null &> /dev/null &!
    # Wait until the relay has opened the FIFO (a few ms; at most 0.5 s)
    local ok=1
    repeat 50 {
      if _ime_reset_wsl_open fd; then exec {fd}>&-; ok=0; break; fi
      zselect -t 1
    }
    [[ -n $lock ]] && zsystem flock -u $lock
    return $ok
  }
  _ime_reset() {
    local fd
    _ime_reset_wsl_open fd || { _ime_reset_wsl_start && _ime_reset_wsl_open fd } || return
    print -ru $fd -- off 2> /dev/null
    exec {fd}>&-
  }
  # Start it now if it is not running, so it is ready by the first Enter (only where Enter can come: line editing
  # on and commands read from a terminal, i.e. not "zsh -i -c ...")
  if [[ -o zle && -t 0 && -z $ZSH_EXECUTION_STRING ]]; then
    () { local fd; if _ime_reset_wsl_open fd; then exec {fd}>&-; else _ime_reset_wsl_start; fi }
  fi
elif (( $+commands[fcitx5-remote] )); then
  _ime_reset() { fcitx5-remote -c &> /dev/null }
elif (( $+commands[macism] )); then
  # Skipped when it is already ABC, so an ordinary Enter does no extra work
  _ime_reset() { [[ $(macism) == com.apple.keylayout.ABC ]] || macism com.apple.keylayout.ABC &> /dev/null }
elif (( $+commands[ibus] )); then
  _ime_reset() { ibus engine ${ZSH_IME_RESET_IBUS_ENGINE:-xkb:jp::jpn} &> /dev/null }
else
  return 0
fi
autoload -Uz add-zle-hook-widget
add-zle-hook-widget zle-line-finish _ime_reset
