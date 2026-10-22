# zsh-ime-reset

zsh のプロンプトで Enter を押すたびに、日本語入力（IME）を英数に戻すプラグインです。[English](README.en.md)

ターミナルでは、次に打つのはたいてい英数です。日本語が要るときだけ手で IME をオンにすれば、次の Enter で英数に戻るので、次のコマンドがかなで化けることがありません。

| 環境 | 使うコマンド | 必要なもの |
|---|---|---|
| Linux（fcitx5） | `fcitx5-remote -c` | fcitx5 |
| Linux（ibus。Fedora・Ubuntu など） | `ibus engine xkb:jp::jpn` | ibus。英語配列なら、読み込む前に `ZSH_IME_RESET_IBUS_ENGINE=xkb:us::eng` |
| macOS | `macism com.apple.keylayout.ABC` | `brew install laishulu/homebrew/macism` |

これらのコマンドが無い環境（サーバー、fcitx5 の無い WSL2）では、何もしません（表示もしません）。`.zshrc` を共有していても大丈夫です。

## 入れ方

### git で入れる

```zsh
git clone https://github.com/yoohey/zsh-ime-reset ~/.zsh/zsh-ime-reset
echo 'source ~/.zsh/zsh-ime-reset/zsh-ime-reset.plugin.zsh' >> ~/.zshrc
```

### `.zshrc` にそのまま貼る

数行だけなので、プラグインの仕組みも、このリポジトリも要りません。使っている OS の分を `.zshrc` に貼ってください。コマンドが無い環境では何もしません。

```zsh
# Linux: fcitx5 があれば fcitx5、なければ ibus（英語配列なら xkb:us::eng）
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
# macOS（macism）
if (( $+commands[macism] )); then
  _ime_reset() { [[ $(macism) == com.apple.keylayout.ABC ]] || macism com.apple.keylayout.ABC &> /dev/null }
  autoload -Uz add-zle-hook-widget
  add-zle-hook-widget zle-line-finish _ime_reset
fi
```

`if` で、コマンドがあるときだけフックを登録します。これが無いと、fcitx5 や macism の無いマシン（たとえば Fedora）で、Enter のたびに「パッケージをインストールしますか？」（command-not-found）が出てしまいます。ibus・fcitx5・macOS 以外の IME を使っているときは、`_ime_reset` の中身を、その IME を切るコマンドに替えてください。プラグイン版（`zsh-ime-reset.plugin.zsh`）は、ほぼ同じ中身で、コメントと、ibus のエンジン名を変える環境変数が付いています。

## しくみ

`zle-line-finish` のフックを使います。入力した行が確定したとき、つまりフォーカスのあるターミナルでだけ動きます。`precmd` だと、裏のコマンドが終わったときにも動いてしまい、そのときフォーカスのある別のウィンドウの IME を切ってしまうので使いません。macOS では、すでに ABC のときは切り替えを省くので、普通の Enter で余計な処理は走りません。

注意: IME の変換を確定する Enter は zsh に届かないので、そのときは戻りません。次の Enter で戻ります。

## おまけ: tmux の prefix でも同じことをする

IME がオンのまま tmux の prefix を打つと、次のキーがかなになって操作が化けます。prefix を押した瞬間に英数へ戻す設定です（ここでは prefix が `C-t`。`C-t C-t` で `C-t` そのものを送ります）。

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

tmux は `prefix` に指定したキーを root の割り当てより先に処理するので、`prefix` は `None` にして、root の `C-t` の割り当てで「英数に戻して prefix テーブルへ入る」形にしています。本物の prefix が無くなるので、ステータスバーで待ち状態を出すときは `client_prefix` ではなく `client_key_table` で判定してください。

## テスト

```zsh
./tests/run.zsh
```

疑似端末で zsh を動かし、偽の `fcitx5-remote`・`macism` を呼ぶかを調べます。確かめた環境は NixOS 26.05（zsh 5.9、fcitx5）と、Fedora（ibus。`ibus engine xkb:jp::jpn` で英数に切り替わること）です。macOS の分岐は、偽の `macism` でしか試していません。

## ライセンス

MIT
