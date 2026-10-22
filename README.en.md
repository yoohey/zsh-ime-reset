# zsh-ime-reset

Switch the input method (IME) back to alphanumeric every time you press Enter at the zsh prompt. [日本語](README.md)

In a terminal you almost always want alphanumeric next. Turn the IME on by hand when you need to type Japanese (or any IME input); the next Enter puts you back, so the next command never starts as garbled kana.

| Where | Command used | Needs |
|---|---|---|
| Linux with fcitx5 | `fcitx5-remote -c` | fcitx5 |
| macOS | `macism com.apple.keylayout.ABC` | `brew install laishulu/homebrew/macism` |

If neither command exists (a server, WSL2 without fcitx5), the plugin adds nothing and prints nothing, so a shared `.zshrc` is safe.

## Install

### With git

```zsh
git clone https://github.com/yoohey/zsh-ime-reset ~/.zsh/zsh-ime-reset
echo 'source ~/.zsh/zsh-ime-reset/zsh-ime-reset.plugin.zsh' >> ~/.zshrc
```

### Or paste it into your `.zshrc`

It is only a few lines, so you do not need a plugin manager — or even this repository. Paste the block for your OS:

```zsh
# Linux (fcitx5)
_ime_reset() { fcitx5-remote -c &> /dev/null }
autoload -Uz add-zle-hook-widget
add-zle-hook-widget zle-line-finish _ime_reset
```

```zsh
# macOS (macism)
_ime_reset() { [[ $(macism) == com.apple.keylayout.ABC ]] || macism com.apple.keylayout.ABC &> /dev/null }
autoload -Uz add-zle-hook-widget
add-zle-hook-widget zle-line-finish _ime_reset
```

If you share one `.zshrc` between several machines, use `zsh-ime-reset.plugin.zsh` instead: it picks the right command by itself and does nothing where neither exists. Using another IME (ibus, Windows' IME through WSL, ...)? Replace the body of `_ime_reset` with whatever command turns your IME off.

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

## Tests

```zsh
./tests/run.zsh
```

Runs an interactive zsh in a pseudo-terminal with fake `fcitx5-remote` / `macism` commands and checks that Enter calls them. Verified on NixOS 26.05 (zsh 5.9) with fcitx5; the macOS branch is tested only with a fake `macism`.

## License

MIT
