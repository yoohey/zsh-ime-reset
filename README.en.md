# zsh-ime-reset

You start typing a command with the Japanese input method still on, and `ls` comes out as "ｌｓ". This zsh plugin puts an end to that. [日本語](README.md)

![With the IME on, echo a Japanese word: Enter puts the IME back to alphanumeric, so the next ls is typed as it is. Clearing a Japanese line with Ctrl+U does the same](docs/demo.gif)

- **After Enter runs a command, the IME is back to alphanumeric.** The next command can be typed as it is.
- **When the cursor gets back to the head of the line, too.** For example, when `Ctrl+U` clears the line or `Ctrl+A` moves to the head.
- **When you come back to the terminal with the cursor at the head of the line.** For example, after typing Japanese in another app and returning with Alt+Tab.

Turn the IME on with your usual key only when you type Japanese (or any IME input). Works on Linux (fcitx5, ibus), macOS and WSL2 (the Windows IME).

## Install

```zsh
git clone https://github.com/yoohey/zsh-ime-reset ~/.zsh/zsh-ime-reset
echo 'source ~/.zsh/zsh-ime-reset/zsh-ime-reset.plugin.zsh' >> ~/.zshrc
```

- **macOS** switches with [macism](https://github.com/laishulu/macism): `brew install laishulu/homebrew/macism`
- **WSL2** loads a different file (`zsh-ime-reset-wsl.plugin.zsh`; see [WSL2 notes](#wsl2-notes)).
- Where there is no command to switch the IME (a server, for one), it does nothing, so a `.zshrc` shared between machines is safe.

## Turning it off

Set a variable to `0` to turn off its moment. Put it in `.zshrc` before the `source` line (typed in a running shell, it works at once, too).

| Variable | Turns off |
|---|---|
| `ZSH_IME_RESET_ON_ENTER=0` | when Enter accepts the line |
| `ZSH_IME_RESET_ON_HEAD=0` | when the cursor gets to the head of the line |
| `ZSH_IME_RESET_ON_FOCUS=0` | when the terminal gets the focus |

```zsh
ZSH_IME_RESET_ON_FOCUS=0
source ~/.zsh/zsh-ime-reset/zsh-ime-reset.plugin.zsh
```

## Where it works

| Where | Command used | Needs |
|---|---|---|
| Linux with fcitx5 | `fcitx5-remote -c` | fcitx5 |
| Linux with ibus (Fedora, Ubuntu, ...) | `ibus engine xkb:jp::jpn` | ibus; for another layout set `ZSH_IME_RESET_IBUS_ENGINE=xkb:us::eng` before loading |
| macOS | `macism com.apple.keylayout.ABC` | `brew install laishulu/homebrew/macism` |
| WSL2 (the Windows IME) | a resident PowerShell closes the IME of the foreground window with the Win32 API | a separate file, `zsh-ime-reset-wsl.plugin.zsh` (uses `powershell.exe`, part of Windows); see [WSL2 notes](#wsl2-notes) |

## Or paste it into your `.zshrc` (Enter only)

It is only a few lines, so you do not need a plugin manager — or even this repository. Paste the block for your OS into your `.zshrc`. It does nothing where the command is missing. The WSL2 part is longer, so it is a separate file (see "WSL2 notes" below).

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

## When it switches, in detail

The variables are checked at each moment, so setting one in a running shell works at once (`ZSH_IME_RESET_ON_FOCUS` from the next prompt). The head and focus moments were added in 2026-10; for Enter only, as before, set `ZSH_IME_RESET_ON_HEAD=0` and `ZSH_IME_RESET_ON_FOCUS=0`. The pasted blocks above are Enter only.

- **Head of the line**: only at the moment the cursor gets there (once, however often the line is redrawn while it stays). A new prompt does not count (Enter has switched already, and a prompt redrawn when a background command ends must not switch off another window's IME). Not during the incremental history search (`Ctrl+R`), where the cursor jumps with the matches.
- **Focus**: while the line is edited, the terminal is asked to report focus (`\e[?1004h`; `\e[I` in, `\e[O` out), and asked to stop before a command runs, so the command gets no reports it did not ask for. A terminal without focus reporting ignores the request (and only this moment does not work there).
- **In tmux**: needs `set -g focus-events on`. Only the active pane gets the reports, and selecting a pane or a window sends one too, so moving to a pane with an empty prompt switches back. If **another client on the same window** never reports focus (it stays "focused": a terminal built into an app, for example), tmux keeps the pane focused and the reports stop. Look for clients you do not use that are `focused` with `tmux list-clients -F '#{client_tty} #{client_flags}'`, and detach them (`tmux detach-client -t <tty>`).
- When the focus goes out or in while the completion menu (`zstyle ':completion:*' menu select`) is open, the menu selection ends.

## Notes (ibus / GNOME)

- **The top bar indicator can stay out of date.** After `ibus engine` switches from outside, the input is alphanumeric again, but GNOME's top bar may keep showing "あ" (seen on Fedora: the input-source menu still has the Japanese source selected, and picking a source again changes it to "en"). Typing is alphanumeric, so it works; only the display lags.
- **Match the engine name to your keyboard layout.** The default is the Japanese layout, `xkb:jp::jpn`. On a US-layout keyboard use `xkb:us::eng`, or keys such as `@` and `"` may move to their Japanese-layout positions (a caution from a Fedora setup whose input source was "English (US)"; whether the keys actually shift was not checked). Edit that line in the pasted block; with the git install, add one line before the `source` line:

  ```zsh
  ZSH_IME_RESET_IBUS_ENGINE=xkb:us::eng
  source ~/.zsh/zsh-ime-reset/zsh-ime-reset.plugin.zsh
  ```

## WSL2 notes

**WSL2 is a separate file, `zsh-ime-reset-wsl.plugin.zsh`.** Closing the Windows IME needs a resident PowerShell, which is too much to carry into other systems. It feels the same (Enter and the head of the line put you back to alphanumeric; the [same moments](#when-it-switches-in-detail)), but **on WSL2 load this file instead of `zsh-ime-reset.plugin.zsh`** (not both). It does nothing where `powershell.exe` is not found.

```zsh
git clone https://github.com/yoohey/zsh-ime-reset ~/.zsh/zsh-ime-reset
echo 'source ~/.zsh/zsh-ime-reset/zsh-ime-reset-wsl.plugin.zsh' >> ~/.zshrc
```

A Linux program inside WSL cannot touch the Windows IME. So one PowerShell (part of Windows) is kept running, and on every Enter it closes the IME of the foreground window — the terminal where you pressed Enter.

```
each zsh --"off"--> named pipe (FIFO) --> relay (zsh) --> powershell.exe
```

- **It closes the IME of the window in front.** When the terminal you pressed Enter in has the focus, that is the terminal. When an Enter comes from a terminal without the focus (tmux `send-keys`, an AI tool running a command in a background pane), the IME of whatever window is in front then is closed — even while you type Japanese in another app.
- **Enter only writes one line into the pipe** (no waiting). There is one PowerShell for the whole PC (about 80 MB), however many shells are open.
- **It ends by itself when unused.** 10 minutes after the last Enter, the relay and PowerShell end; the next Enter starts them again. Change the time, in seconds, before loading (it applies to PowerShell started from then on):

  ```zsh
  ZSH_IME_RESET_WSL_IDLE=1800   # 30 minutes
  source ~/.zsh/zsh-ime-reset/zsh-ime-reset-wsl.plugin.zsh
  ```
- **Starting takes about 1.5 s** — and noticeably longer for the first start after rebooting the PC (PowerShell and .NET loading, the first run of the C# compiler). Right after opening a shell, or on the first Enter after the time-out, the switch comes a little late (Enters pressed meanwhile take effect once it is ready); if you move to another window in that moment, that window's IME is closed instead.
- PowerShell is started detached from the terminal (`setsid`, present on Debian, Ubuntu and the like). Left on the terminal in the background, it is stopped when WSL touches the terminal, so the IME stays on and the terminal seems to hang.
- If PowerShell crashes, Enter never hangs: on the next Enter the relay starts a new one and sends it again (about 1.5 s late then). If the relay itself is gone, the next Enter starts both again.
- No `.ps1` file is read, so the PowerShell execution policy does not matter. The relay sends PowerShell only one fixed line that closes the IME; it never runs what is written into the pipe. The pipe is created in `$XDG_RUNTIME_DIR` (or `/tmp`), readable and writable only by you.
- Verified on WSL2 (Ubuntu 24.04, and a fresh Debian 13) on Windows 11, with Windows Terminal. Enter switches back with Google Japanese Input, Microsoft IME and Copilot IME alike (switching at the head of the line and on focus is not tried on WSL2 yet).

## How it works

For Enter it registers a `zle-line-finish` hook, which runs when the line is accepted — that is, only when Enter is pressed in that terminal. A `precmd` hook is a bad fit: it also fires when a background command ends, and would switch off the IME of whatever window has the focus at that moment. On macOS the switch is skipped when the source is already ABC, so an ordinary Enter does no extra work.

Note: the Enter that confirms an IME conversion does not reach zsh, so it does not switch; the next Enter does.

The head of the line is watched with a `zle-line-pre-redraw` hook on `$CURSOR`, and focus with a widget bound to `\e[I` that checks the cursor is at 0. `\e[O` is bound to a widget that does nothing (unbound, it would be read as Esc and `[O`; in vi command mode, `O` opens a line). The moments live in `zsh-ime-reset-hooks.zsh`, read by both `zsh-ime-reset.plugin.zsh` and the WSL2 file; with the plugin file alone, it switches on Enter only, as before.

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

Runs an interactive zsh in a pseudo-terminal with fake `fcitx5-remote` / `macism` / `ibus` / `powershell.exe` commands and checks that Enter, the head of the line and focus reports call them (and that each variable turns its moment off). The head and focus moments were also checked for real with foot and tmux on NixOS (not yet on WSL2 or macOS). Verified on NixOS 26.05 (zsh 5.9) with fcitx5, on Fedora with ibus (the pasted block switches back on every Enter), and on WSL2 with Ubuntu 24.04 and Debian 13 (real use with Windows Terminal, with Google Japanese Input, Microsoft IME and Copilot IME; the tests on Ubuntu); the macOS branch is tested only with a fake `macism`.

## Article (Japanese)

The background, the tmux prefix setup, and the migemo completion ([zsh-migemo-fallback](https://github.com/yoohey/zsh-migemo-fallback)) are written up in a Zenn article: https://zenn.dev/yoohey/articles/ime-terminal-stress

## License

MIT
