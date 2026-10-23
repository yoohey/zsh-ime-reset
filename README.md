# zsh-ime-reset

zsh のプロンプトで Enter を押すたびに、日本語入力（IME）を英数に戻すプラグインです。[English](README.en.md)

ターミナルでは、次に打つのはたいてい英数です。日本語が要るときだけ手で IME をオンにすれば、次の Enter で英数に戻るので、次のコマンドがかなで化けることがありません。

| 環境 | 使うコマンド | 必要なもの |
|---|---|---|
| Linux（fcitx5） | `fcitx5-remote -c` | fcitx5 |
| Linux（ibus。Fedora・Ubuntu など） | `ibus engine xkb:jp::jpn` | ibus。英語配列なら、読み込む前に `ZSH_IME_RESET_IBUS_ENGINE=xkb:us::eng` |
| macOS | `macism com.apple.keylayout.ABC` | `brew install laishulu/homebrew/macism` |
| WSL2（Windows の IME） | 常駐させた PowerShell が、Win32 API で前面のウィンドウの IME を閉じる | なし（Windows 付属の `powershell.exe` を使う）。別ファイル `zsh-ime-reset-wsl.plugin.zsh`。[WSL2 の注意](#wsl2-の注意) |

これらのコマンドが無い環境（サーバーなど）では、何もしません（表示もしません）。`.zshrc` を共有していても大丈夫です。

## 入れ方

### git で入れる

```zsh
git clone https://github.com/yoohey/zsh-ime-reset ~/.zsh/zsh-ime-reset
echo 'source ~/.zsh/zsh-ime-reset/zsh-ime-reset.plugin.zsh' >> ~/.zshrc
```

### `.zshrc` にそのまま貼る

数行だけなので、プラグインの仕組みも、このリポジトリも要りません。使っている OS の分を `.zshrc` に貼ってください。コマンドが無い環境では何もしません。WSL2 の分は長いので、別ファイルにしてあります（下の「WSL2 の注意」）。

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

## 注意（ibus / GNOME）

- **上バーの表示が古いままになることがあります。** `ibus engine` で外から切り替えると、実際の入力は英数に戻っても、GNOME の上バーは「あ」のままのことがあります（Fedora で確認。入力ソースのメニューを開くと「日本語」が選ばれたままで、選び直すと「en」に変わります）。入力は英数になっているので、動きとしては問題ありません。
- **英数のエンジン名は、キーボード配列に合わせてください。** 初期値は日本語配列の `xkb:jp::jpn` です。英語（US）配列のキーボードで使うなら、`xkb:us::eng` にしないと、`@` や `"` などの位置が日本語配列に変わる恐れがあります（Fedora の入力ソースが「英語 (US)」だったときの注意。実際にずれるかは未確認）。貼り付け版は該当の行を書き換え、git で入れた版は、読み込む行の前に環境変数を 1 行足してください。

  ```zsh
  ZSH_IME_RESET_IBUS_ENGINE=xkb:us::eng
  source ~/.zsh/zsh-ime-reset/zsh-ime-reset.plugin.zsh
  ```

## WSL2 の注意

**WSL2 だけ、別のファイル（`zsh-ime-reset-wsl.plugin.zsh`）です。** Windows の IME を閉じるには、常駐する PowerShell が要り、ほかの環境に持ち込むには大きいためです。使い方は、これまでと同じ感覚（Enter で英数に戻る）ですが、**WSL2 では `zsh-ime-reset.plugin.zsh` の代わりに、このファイルを読み込んでください**（両方は読み込みません）。`powershell.exe` が見つからない環境では、何もしません。

```zsh
git clone https://github.com/yoohey/zsh-ime-reset ~/.zsh/zsh-ime-reset
echo 'source ~/.zsh/zsh-ime-reset/zsh-ime-reset-wsl.plugin.zsh' >> ~/.zshrc
```

WSL の中の Linux のプログラムは、Windows の IME を直接は触れません。そこで、Windows 付属の PowerShell を 1 つだけ常駐させ、Enter のたびに、前面のウィンドウ（Enter を押したターミナル）の IME を閉じてもらいます。

```
各 zsh --「off」--> 名前付きパイプ（FIFO） --> 中継（zsh） --> powershell.exe
```

- **閉じるのは、前面のウィンドウの IME です。** Enter を押したターミナルがフォーカスされているときは、それがそのターミナルです。フォーカスの無いターミナルで Enter が起きたとき（tmux の `send-keys`、AI のツールが裏のペインでコマンドを実行したときなど）は、そのとき前面にあるウィンドウの IME が閉じます。別のアプリで日本語を打っている最中でも、閉じます。
- **Enter のときの処理は、パイプに 1 行書くだけ**です（待ちません）。PowerShell は、開いているシェルの数によらず、PC 全体で 1 つ（約 80MB）です。
- **使わなければ、自分で終わります。**最後の Enter から 10 分たつと、中継と PowerShell が終わります。次の Enter で起動し直します。時間は、読み込む前に秒で変えられます（その後に起動する分から効きます）。

  ```zsh
  ZSH_IME_RESET_WSL_IDLE=1800   # 30 分
  source ~/.zsh/zsh-ime-reset/zsh-ime-reset-wsl.plugin.zsh
  ```
- **起動には約 1.5 秒かかります。**シェルを開いた直後や、時間切れのあとの最初の Enter では、少し遅れて英数に戻ります。**PC を再起動した直後の最初の起動は、さらに時間がかかります**（PowerShell と .NET の読み込み、C# のコンパイラの初回の起動など）。その間に押した Enter の分は、準備ができてから順に効きます。その間に別のウィンドウへ切り替えると、そちらの IME が閉じます。
- PowerShell は、端末から切り離して（`setsid`。Debian・Ubuntu などには最初から入っています）起動します。端末につないだまま裏で動かすと、WSL が端末に触れたときに一時停止させられ、IME が戻らず、端末も固まったようになるためです。
- PowerShell が落ちても、Enter が固まることはありません。次の Enter で、中継が PowerShell を起動し直して送り直します（そのときは約 1.5 秒遅れます）。中継ごと止まっていたときも、次の Enter で起動し直します。
- `.ps1` のファイルは読み込まないので、PowerShell の実行ポリシーの設定は関係ありません。中継が PowerShell に送るのは、IME を閉じる決まった 1 行だけです。パイプに書かれた内容を、そのまま実行することはありません。パイプは、自分だけが読み書きできる権限で、`$XDG_RUNTIME_DIR`（無ければ `/tmp`）に作ります。
- 確かめた環境は、Windows 11 の WSL2（Ubuntu 24.04 と、入れたばかりの Debian 13）、Windows Terminal、Google 日本語入力です。Microsoft IME と、ほかのターミナルでは、まだ試していません。

## しくみ

`zle-line-finish` のフックを使います。入力した行が確定したとき、つまり、そのターミナルで Enter が押されたときだけ動きます。`precmd` だと、裏のコマンドが終わったときにも動いてしまい、そのときフォーカスのある別のウィンドウの IME を切ってしまうので使いません。macOS では、すでに ABC のときは切り替えを省くので、普通の Enter で余計な処理は走りません。

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

ibus の場合は、`fcitx5-remote -c` の部分を `ibus engine xkb:jp::jpn`（US 配列なら `xkb:us::eng`）に、`command -v fcitx5-remote` の判定を `command -v ibus` に書き換えてください（tmux の中から呼ぶ形は、まだ試していません）。

## テスト

```zsh
./tests/run.zsh
```

疑似端末で zsh を動かし、偽の `fcitx5-remote`・`macism`・`ibus`・`powershell.exe` を呼ぶかを調べます。確かめた環境は NixOS 26.05（zsh 5.9、fcitx5）、Fedora（ibus。貼り付けた形で、Enter ごとに英数に戻ること）、WSL2 の Ubuntu 24.04 と Debian 13（試験と、Windows Terminal＋Google 日本語入力での実際の動き。試験は Ubuntu で流した）です。macOS の分岐は、偽の `macism` でしか試していません。

## 解説記事

作った経緯と、tmux の prefix の設定、migemo の補完（[zsh-migemo-fallback](https://github.com/yoohey/zsh-migemo-fallback)）も含めた全体の話は、Zenn の記事にまとめています: https://zenn.dev/yoohey/articles/ime-terminal-stress

## ライセンス

MIT
