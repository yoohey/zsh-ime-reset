# zsh-ime-reset

Switch the input method (IME) back to alphanumeric every time you press Enter at the zsh prompt. [日本語](README.md)

In a terminal you almost always want alphanumeric next. Turn the IME on by hand when you need to type Japanese (or any IME input); the next Enter puts you back, so the next command never starts as garbled kana.

| Where | Command used | Needs |
|---|---|---|
| Linux with fcitx5 | `fcitx5-remote -c` | fcitx5 |
| Linux with ibus (Fedora, Ubuntu, ...) | `ibus engine xkb:jp::jpn` | ibus; for another layout set `ZSH_IME_RESET_IBUS_ENGINE=xkb:us::eng` before loading |
| macOS | `macism com.apple.keylayout.ABC` | `brew install laishulu/homebrew/macism` |
| WSL2 (the Windows IME) | a resident PowerShell closes the IME of the foreground window with the Win32 API | nothing (uses `powershell.exe`, part of Windows); see [WSL2 notes](#wsl2-notes) |

If none of these applies (a server, for one), the plugin adds nothing and prints nothing, so a shared `.zshrc` is safe.

## Install

### With git

```zsh
git clone https://github.com/yoohey/zsh-ime-reset ~/.zsh/zsh-ime-reset
echo 'source ~/.zsh/zsh-ime-reset/zsh-ime-reset.plugin.zsh' >> ~/.zshrc
```

### Or paste it into your `.zshrc`

It is only a few lines, so you do not need a plugin manager — or even this repository. Paste the block for your OS into your `.zshrc`. It does nothing where the command is missing. The WSL2 part is longer; install it with git.

```zsh
# Linux: fcitx5 if present, otherwise ibus (use xkb:us::eng for a US layout)
if (( $+commands[fcitx5-remote] )); then
  _ime_reset() { fcitx5-remote -c &> /dev/null }
elif (( $+commands[ibus] )); then
  _ime_reset() { ibus engine xkb:jp::jpn &> /dev/null }
fi
if (( $+functions[_ime_reset] )); then
  autoload -Uz add-zle-hook-widget
  add-zle-hook-widget zle-line-finish _ime_reset
fi
```

```zsh
# macOS (macism)
if (( $+commands[macism] )); then
  _ime_reset() { [[ $(macism) == com.apple.keylayout.ABC ]] || macism com.apple.keylayout.ABC &> /dev/null }
  autoload -Uz add-zle-hook-widget
  add-zle-hook-widget zle-line-finish _ime_reset
fi
```

The `if` registers the hook only when the command exists. Without it, a machine lacking fcitx5 / macism (Fedora, for one) shows its "install package?" command-not-found prompt on every Enter. Using an IME other than fcitx5, ibus or macOS's? Replace the body of `_ime_reset` with whatever command turns your IME off. The plugin file (`zsh-ime-reset.plugin.zsh`) is nearly the same code, with comments and a variable for the ibus engine name.

## Notes (ibus / GNOME)

- **The top bar indicator can stay out of date.** After `ibus engine` switches from outside, the input is alphanumeric again, but GNOME's top bar may keep showing "あ" (seen on Fedora: the input-source menu still has the Japanese source selected, and picking a source again changes it to "en"). Typing is alphanumeric, so it works; only the display lags.
- **Match the engine name to your keyboard layout.** The default is the Japanese layout, `xkb:jp::jpn`. On a US-layout keyboard use `xkb:us::eng`, or keys such as `@` and `"` may move to their Japanese-layout positions (a caution from a Fedora setup whose input source was "English (US)"; whether the keys actually shift was not checked). Edit that line in the pasted block; with the git install, add one line before the `source` line:

  ```zsh
  ZSH_IME_RESET_IBUS_ENGINE=xkb:us::eng
  source ~/.zsh/zsh-ime-reset/zsh-ime-reset.plugin.zsh
  ```

## WSL2 notes

A Linux program inside WSL cannot touch the Windows IME. So one PowerShell (part of Windows) is kept running, and on every Enter it closes the IME of the foreground window — the terminal where you pressed Enter.

```
each zsh --"off"--> named pipe (FIFO) --> relay (zsh) --> powershell.exe
```

- **Enter only writes one line into the pipe** (no waiting). There is one PowerShell for the whole PC (about 80 MB), however many shells are open.
- **It ends by itself when unused.** 10 minutes after the last Enter, the relay and PowerShell end; the next Enter starts them again. Change the time, in seconds, before loading (it applies to PowerShell started from then on):

  ```zsh
  ZSH_IME_RESET_WSL_IDLE=1800   # 30 minutes
  source ~/.zsh/zsh-ime-reset/zsh-ime-reset.plugin.zsh
  ```
- **Starting takes about 1.5 s.** Right after opening a shell, or on the first Enter after the time-out, the switch comes a little late; if you move to another window in that moment, that window's IME is closed instead.
- PowerShell is started detached from the terminal (`setsid`, present on Debian, Ubuntu and the like). Left on the terminal in the background, it is stopped when WSL touches the terminal, so the IME stays on and the terminal seems to hang.
- If PowerShell crashes, Enter never hangs. One Enter right after the crash may be missed; the next one starts it again.
- No `.ps1` file is read, so the PowerShell execution policy does not matter. The relay sends PowerShell only one fixed line that closes the IME; it never runs what is written into the pipe. The pipe is created in `$XDG_RUNTIME_DIR` (or `/tmp`), readable and writable only by you.
- WSL is checked before fcitx5 (a `fcitx5-remote` installed for WSLg does not reach the Windows IME). To use fcitx5 or ibus inside WSL instead, put `ZSH_IME_RESET_WSL=0` before loading.
- Verified on WSL2 (Ubuntu 24.04, and a fresh Debian 13) on Windows 11, with Windows Terminal and Google Japanese Input. Microsoft IME and other terminals are not tried yet.

## How it works

It registers a `zle-line-finish` hook, which runs when the line is accepted — that is, only in the terminal that has the focus. A `precmd` hook is a bad fit: it also fires when a background command ends, and would switch off the IME of whatever window has the focus at that moment. On macOS the switch is skipped when the source is already ABC, so an ordinary Enter does no extra work.

Note: the Enter that confirms an IME conversion does not reach zsh, so it does not switch; the next Enter does.

## Bonus: the same for tmux's prefix key

Typing the tmux prefix while the IME is on turns the following key into kana. This makes the prefix switch the IME to alphanumeric first (`C-t` as the prefix here; `C-t C-t` sends a literal `C-t`):

```tmux
set -g prefix C-t
unbind C-b
bind C-t send-prefix
# Linux (fcitx5)
if-shell 'command -v fcitx5-remote' \
  'set -g prefix None ; bind -n C-t switch-client -T prefix \; run-shell -b "fcitx5-remote -c" ; bind C-t send-keys C-t'
# macOS (macism)
if-shell 'command -v macism' \
  'set -g prefix None ; bind -n C-t switch-client -T prefix \; run-shell -b "macism com.apple.keylayout.ABC" ; bind C-t send-keys C-t'
```

tmux treats the `prefix` key before root bindings, so `prefix` is set to `None` and `C-t` is bound in the root table instead. Because there is no real prefix any more, a status bar that tests `client_prefix` will not light up; test `client_key_table` instead.

With ibus, replace `fcitx5-remote -c` with `ibus engine xkb:jp::jpn` (`xkb:us::eng` for a US layout) and `command -v fcitx5-remote` with `command -v ibus`. (Calling it from inside tmux has not been tried yet.)

## Tests

```zsh
./tests/run.zsh
```

Runs an interactive zsh in a pseudo-terminal with fake `fcitx5-remote` / `macism` / `ibus` / `powershell.exe` commands and checks that Enter calls them. Verified on NixOS 26.05 (zsh 5.9) with fcitx5, on Fedora with ibus (the pasted block switches back on every Enter), and on WSL2 with Ubuntu 24.04 and Debian 13 (real use with Windows Terminal and Google Japanese Input; the tests on Ubuntu); the macOS branch is tested only with a fake `macism`.

## Article (Japanese)

The background, the tmux prefix setup, and the migemo completion ([zsh-migemo-fallback](https://github.com/yoohey/zsh-migemo-fallback)) are written up in a Zenn article: https://zenn.dev/yoohey/articles/ime-terminal-stress

## License

MIT
