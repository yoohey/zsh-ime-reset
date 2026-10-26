# zsh-ime-reset

日本語入力がオンのままコマンドを打ち始めて、`ls` が「ｌｓ」になって、がああああああ！！となることを無くす zsh のプラグインです。[English](README.en.md)

![IME をオンにして「こんにちは」を echo すると、Enter で英数に戻り、次の ls はそのまま打てる。「てすと」を Ctrl+U で消したときも英数に戻る](docs/demo.gif)

以下の３つの場面で自動的に英数に戻るようにしています。
- **Enter でコマンドを実行したら、英数に戻ります。** 次のコマンドは、IMEを切り替えずにそのまま英数で打てます。
- **カーソルが行の先頭に戻ったときも、英数に戻ります。** `Ctrl+U` で行を消したとき、`Ctrl+A` で先頭へ移ったとき自動的に英数になります。
- **ターミナルに戻ってきたとき（フォーカスが移ったとき）にカーソルが行の先頭なら、英数に戻ります。** ほかのアプリで日本語を打っていて、Alt+Tab で戻ってきたときなどです。

いずれも英数を打ちたい場面なので、自動的にIMEを英数に戻します。先頭以外の場合は日本語入力中（引数など）とみなし何もしません。

日本語を打つときだけ、いつものキーで IME をオンにしてください。コマンド実行後に再び英数に戻ります。

Linux（fcitx5・ibus）、macOS、WSL2（Windows の IME）で動きます。

## 入れ方

```zsh
git clone https://github.com/yoohey/zsh-ime-reset ~/.zsh/zsh-ime-reset
echo 'source ~/.zsh/zsh-ime-reset/zsh-ime-reset.plugin.zsh' >> ~/.zshrc
```

- **macOS** は切り替えに [macism](https://github.com/laishulu/macism) を使います: `brew install laishulu/homebrew/macism`
- **WSL2** は読み込むファイルが違います（`zsh-ime-reset-wsl.plugin.zsh`。[WSL2 の注意](#wsl2-の注意)）。
- IME を切り替えるコマンドが無い環境（サーバーなど）では何もしません。`.zshrc` を複数のマシンで共有していても大丈夫です。

## 止め方

場面ごとに、変数を `0` にすると止まります。`.zshrc` の、読み込む行の前に書きます（開いているシェルで打っても、すぐに効きます）。

| 変数 | 止まる場面 |
|---|---|
| `ZSH_IME_RESET_ON_ENTER=0` | Enter で行を確定したとき |
| `ZSH_IME_RESET_ON_HEAD=0` | カーソルが行の先頭に着いたとき |
| `ZSH_IME_RESET_ON_FOCUS=0` | ターミナルにフォーカスが来たとき |

```zsh
ZSH_IME_RESET_ON_FOCUS=0
source ~/.zsh/zsh-ime-reset/zsh-ime-reset.plugin.zsh
```

## 対応している環境

| 環境 | 使うコマンド | 必要なもの |
|---|---|---|
| Linux（fcitx5） | `fcitx5-remote -c` | fcitx5 |
| Linux（ibus。Fedora・Ubuntu など） | `ibus engine xkb:jp::jpn` | ibus。英語配列なら、読み込む前に `ZSH_IME_RESET_IBUS_ENGINE=xkb:us::eng` |
| macOS | `macism com.apple.keylayout.ABC` | `brew install laishulu/homebrew/macism` |
| WSL2（Windows の IME） | 常駐させた PowerShell が、Win32 API で前面のウィンドウの IME を閉じる | なし（Windows 付属の `powershell.exe` を使う）。別ファイル `zsh-ime-reset-wsl.plugin.zsh`。[WSL2 の注意](#wsl2-の注意) |

## `.zshrc` にそのまま貼る（Enter だけ）

数行だけなのでプラグインの仕組みもこのリポジトリも要りません。使っている OS の分を `.zshrc` に貼ってください。コマンドが無い環境では何もしません。WSL2 の分は長いので、別ファイルにしてあります（下の「WSL2 の注意」）。

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

`if` でコマンドがあるときだけフックを登録します。これが無いと、fcitx5 や macism の無いマシン（たとえば Fedora）で、Enter のたびに「パッケージをインストールしますか？」（command-not-found）が出てしまい辛いです。ibus・fcitx5・macOS 以外の IME を使っているときは、`_ime_reset` の中身をその IME を切るコマンドに替えてください。プラグイン版（`zsh-ime-reset.plugin.zsh`）はほぼ同じ中身でコメントと ibus のエンジン名を変える環境変数が付いています。環境に応じて変更してください。

## 英数に戻す場面の詳細

場面が来るたびに状態を見るので、開いているシェルで打ってもすぐに効きます（`ZSH_IME_RESET_ON_FOCUS` は、次のプロンプトから）。先頭とフォーカスは、2026-10 に足しました。初回公開版は Enter のときのみ英数へ戻していました。同じ Enter だけの動きにする場合は、`ZSH_IME_RESET_ON_HEAD=0` と `ZSH_IME_RESET_ON_FOCUS=0` を記載して無効にすると Enter でコマンド実行時のみ動きます。

- **カーソルが先頭に着いたとき**: 先頭に移ったときに英数へ戻します。先頭へ移動するイコールコマンドをタイプするだろうということで英数にします。履歴の逐次検索（`Ctrl+R`）の間は、一致したところへカーソルが飛ぶので英数へは戻しません。
- **ターミナルにフォーカスが来たとき**: ターミナルにフォーカスが戻り、かつ、カーソルが先頭にあったときに英数に戻ります。コマンド実行中（例えば tail などでログ監視中）は何もしません。フォーカスの取れないターミナルは、動かない可能性があります。
- Tab の補完で候補を一覧から選んでいる途中（`zstyle ':completion:*' menu select`）にウィンドウを行き来すると、一覧が消えます。そのとき選んでいた候補は行に残るので、続けるときはもう一度 Tab を押してください。
- **tmux の中では`set -g focus-events on` を入れておいてください**: ペインへフォーカスが移ったときに動きます（ペインやウィンドウを切り替えたときも動きます）。上と同じく先頭の際に英数へ戻ります。

## 注意（ibus / GNOME）

- **上バーの表示が古いままになることがあります。** `ibus engine` で外から切り替えると、実際の入力は英数に戻っても、GNOME の上バーは「あ」のままのことがあります（Fedora で確認。入力ソースのメニューを開くと「日本語」が選ばれたままで、選び直すと「en」に変わります）。入力は英数になっているので、動きとしては問題ありません。
- **英数のエンジン名は、キーボード配列に合わせてください。** 初期値は日本語配列の `xkb:jp::jpn` です。英語（US）配列のキーボードで使うなら、`xkb:us::eng` にしないと、`@` や `"` などの位置が日本語配列に変わる恐れがあります（Fedora の入力ソースが「英語 (US)」だったときの注意。実際にずれるかは未確認）。貼り付け版は該当の行を書き換え、git で入れた版は、読み込む行の前に環境変数を 1 行足してください。

  ```zsh
  ZSH_IME_RESET_IBUS_ENGINE=xkb:us::eng
  source ~/.zsh/zsh-ime-reset/zsh-ime-reset.plugin.zsh
  ```

## WSL2 の注意

**WSL2 だけ、別のファイル（`zsh-ime-reset-wsl.plugin.zsh`）にしています。** Windows の IME を閉じるには常駐する PowerShell が要り、ほかの環境（Linux・macOS）に持ち込むには大きいためです。使い方は、これまでと同じ感覚（Enter や行の先頭で英数に戻る。[場面](#英数に戻す場面の詳細)も同じ）ですが、**WSL2 では `zsh-ime-reset.plugin.zsh` の代わりに、`zsh-ime-reset-wsl.plugin.zsh`を読み込んでください**（両方は読み込みません）。`powershell.exe` が見つからない環境では、何もしません。

```zsh
git clone https://github.com/yoohey/zsh-ime-reset ~/.zsh/zsh-ime-reset
echo 'source ~/.zsh/zsh-ime-reset/zsh-ime-reset-wsl.plugin.zsh' >> ~/.zshrc
```

WSL の中の Linux のプログラムはWindows の IME を直接は触れないため、PowerShellを呼び切り替えを実現しています。Windows 付属の PowerShell を 1 つだけ常駐させ、各トリガーのたびにPowerShellをキックし、IMEを英数に戻します。

```
各 zsh --「off」--> 名前付きパイプ（FIFO） --> 中継（zsh） --> powershell.exe
```

- **英数に戻るのは、前面のウィンドウです**。裏のペインで自動でコマンドが実行されたとき（tmux の send-keys、AI のツールなど）は、そのとき使っている別のアプリの日本語入力が切れることがあります。
- **英数へ戻す処理は、パイプに 1 行書くだけ**です（待ちません）。PowerShell は、開いているシェルの数によらず、PC 全体で 1 つ（約 80MB）です。
- **使わなければ、自分で終わります**。最後に英数に戻す処理をしてから 10 分たつと、中継と PowerShell が終わります。次にまた英数に戻す場面が来ると起動し直します。タイムアウトは、変数で変えられます（その後に起動する分から効きます）。

  ```zsh
  ZSH_IME_RESET_WSL_IDLE=1800   # 30 分
  source ~/.zsh/zsh-ime-reset/zsh-ime-reset-wsl.plugin.zsh
  ```
- **起動には 1.5 秒ほどかかることがあります**。シェルを開いた直後や、時間切れのあとの最初の動きでは、少し遅れて英数に戻ります。**PC を再起動した直後の最初の起動は、さらに時間がかかる可能性があります**（PowerShell と .NET の読み込み、C# のコンパイラの初回の起動など）。
- PowerShell は、端末から切り離して（`setsid`。Debian・Ubuntu などには最初から入っています）起動するようにしています。端末につないだまま裏で動かすと、WSL が端末に触れたときに一時停止させられ、IME が戻らず、さらに端末も固まったようになってしまうためです。
- PowerShell が落ちても、コマンド実行やその他の操作が固まらないようにしています。次の実行で、中継が PowerShell を起動し直して送り直します。そのときは 1.5 秒ほどかかることがあります。
- `.ps1` のファイルは読み込まないので、PowerShell の実行ポリシーの設定は関係ないようにしてあります。PowerShell へ送るのは、IME を閉じる決まった 1 行だけです。パイプに書かれた内容をそのまま実行することはないです。パイプは、自分だけが読み書きできる権限で、`$XDG_RUNTIME_DIR`（無ければ `/tmp`）に作ります。
- 確かめた環境は、Windows 11 の WSL2（Ubuntu 24.04 と、入れたばかりの Debian 13）と Windows Terminal です。IME は、Google 日本語入力、Microsoft IME、Copilot IME のどれでも英数に戻ることを確認しました。

## しくみ

英数に戻すタイミングは、zsh の行エディタ（zle）のフックで見ています。場面を見張る処理は `zsh-ime-reset-hooks.zsh` にまとめてあり、`zsh-ime-reset.plugin.zsh` と WSL 版の両方がこれを読みます。実際に英数へ切り替える命令（`fcitx5-remote -c` など）は、環境ごとに `_ime_reset` という関数にしてあり、どの場面からもこれを呼びます。プラグインのファイルだけを置いた場合は、前と同じく Enter のときだけ英数に戻します。

### Enter のとき

`zle-line-finish` のフックを使います。入力した行が確定したとき、つまりそのターミナルで Enter が押されたときに動きます。`precmd`（プロンプトを出す直前）だと、裏のコマンドが終わったときにも動いてしまい、そのときフォーカスのある別のウィンドウの IME を切ってしまうので不採用としました。macOS では、すでに ABC のときは切り替えを省くので、普通の Enter で余計な処理は走りません。

注意: IME の変換を確定する Enter は zsh に届かないので、そのときは戻りません。日本語確定→次の Enter で戻ります。

### カーソルが行の先頭に着いたとき

`zle-line-pre-redraw` のフック（zsh が入力中の行を描き直すたびに動く）で、カーソルの位置（`$CURSOR`）を見ています。前に見たときは先頭でなく、今は先頭、と変わった瞬間だけ英数に戻します。先頭にいる間に何度描き直しても、切り替えるのは 1 回だけです。

次のときは、先頭でも英数に戻しません。

- **新しいプロンプトが出たとき**: Enter のときにもう英数に戻してあります。また、裏で動いていたコマンドが終わってプロンプトが描き直されたときに、ほかのウィンドウで打っている日本語を切ってしまわないためでもあります。
- **履歴を検索している間（`Ctrl+R`）**: 検索の結果に合わせてカーソルが先頭へ飛ぶことがあり、検索の言葉を日本語で打っている途中で切れてしまうためです（`$ISEARCHMATCH_ACTIVE` で見分けています）。

### ターミナルにフォーカスが来たとき

ターミナルの「フォーカスイベント」を使っています。`print -n '\e[?1004h'` を実行しておくと、フォーカスが来たときに `\e[I`、離れたときに `\e[O` が、キー入力と同じように送られてきます。（`\e` については注釈参照）

- フォーカスイベントは、プロンプトが出たとき（`zle-line-init`）に `\e[?1004h` で有効にし、Enter でコマンドを実行する直前（`zle-line-finish`）に `\e[?1004l` で無効にしています。そのため、コマンドの実行中（`tail -f` でログを見ている間など）は、ウィンドウを行き来しても何も起きません。実行したコマンドに、フォーカスイベントが送られることもありません。
- フォーカスしたとき（`\e[I`）には、カーソルが先頭（0）なら英数に戻すウィジェットを割り当てています。
- フォーカスが離れたとき（`\e[O`）には、何もしないウィジェットを割り当てています。割り当てが無いと、Esc と `[O` の 2 つのキーとして読まれてしまうためです（vi のコマンドモードなら、`O` で新しい行が開いてしまいます）。
- この機能に対応していないターミナルではフォーカスの場面だけ動きません。

※ フォーカスイベントは zsh ではなくターミナルの機能です（tmux の `focus-events` も同じもの）。`\e[...]` のような文字の並びは、画面には出ない制御用のコードで、zsh とターミナルはこれで「フォーカスが来たよ」「来たら教えて」といったやり取りをしています。`\e[?1004h` は「フォーカスが変わったら教えて」、`\e[?1004l` は「もう教えなくていいよ」、`\e[I` は「フォーカスが来たよ」、`\e[O` は「フォーカスが離れたよ」という意味です。

### tmux の中で、フォーカスで戻らないとき

tmux（`set -g focus-events on`）は、フォーカスイベントを、選ばれているペインにだけ届けます。ペインやウィンドウを切り替えたときも届くので、先頭のプロンプトのペインに移ると英数になります。

ただし tmux は、同じウィンドウを見ているクライアントのどれか 1 つにでもフォーカスがあれば、ペインにフォーカスがあるとみなします。フォーカスイベントを送らないクライアント（ずっと「フォーカスあり」のまま。アプリに組み込まれたターミナルなど）がつながっていると、ほかのウィンドウへ移ってもペインのフォーカスが外れたことにならず、戻ってきたときのフォーカスイベントも届きません。次のコマンドで、使っていないのに `focused` になっているクライアントがあれば、外してみてください。

```zsh
tmux list-clients -F '#{client_tty} #{client_flags}'
tmux detach-client -t <tty>
```

## おまけ: tmux の prefix でも同じように英数へ戻す

IME がオンのまま tmux の prefix を打つと、次のキーが「かな」になって操作が化けます。prefix を押した瞬間に英数へ戻すことでストレスを軽減します（ここでは prefix が `C-t`。`C-t C-t` で `C-t` そのものを送ります）。

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

tmux は `prefix` に指定したキーを root の割り当てより先に処理するので、`prefix` は `None` にして、root の `C-t` の割り当てで「英数に戻して prefix テーブルへ入る」形にしています。本物の prefix が無くなるので、ステータスバーで待ち状態でなにか処理をしたいときは `client_prefix` ではなく `client_key_table` で判定してください。

ibus の場合は、`fcitx5-remote -c` の部分を `ibus engine xkb:jp::jpn`（US 配列なら `xkb:us::eng`）に、`command -v fcitx5-remote` の判定を `command -v ibus` に書き換えてください（ibusはまだしっかり確認していないですが、多分動くと思います）。

## テスト

```zsh
./tests/run.zsh
```

疑似端末で zsh を動かし、偽の `fcitx5-remote`・`macism`・`ibus`・`powershell.exe` を呼ぶかを調べます（Enter、先頭に着いたとき、フォーカスイベント、それぞれの変数で止まること）。先頭とフォーカスは、NixOS の foot＋tmux で実際の動きも確かめました（WSL2 と macOS では、まだ試していません）。確かめた環境は NixOS 26.05（zsh 5.9、fcitx5）、Fedora（ibus。貼り付けた形で、Enter ごとに英数に戻ること）、WSL2 の Ubuntu 24.04 と Debian 13（試験と、Windows Terminal での実際の動き。IME は Google 日本語入力・Microsoft IME・Copilot IME。試験は Ubuntu で流した）です。macOS の分岐は、偽の `macism` でしか試していません。

## 解説記事

作った経緯と、tmux の prefix の設定、migemo の補完（[zsh-migemo-fallback](https://github.com/yoohey/zsh-migemo-fallback)）も含めた全体の話は、Zenn の記事にまとめています: https://zenn.dev/yoohey/articles/ime-terminal-stress

## ライセンス

MIT
