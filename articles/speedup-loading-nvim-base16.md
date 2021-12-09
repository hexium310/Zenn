---
title: "RRethy/nvim-base16 から必要なカラースキームだけを読み込んで Neovim の起動を速くする"
emoji: "🎨"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["neovim"]
published: true
---

:::message
この記事は [Vim Advent Calendar 2021] カレンダー 2 の 10 日目の記事です。
:::

# 概要

Neovim 用の base16 カラースキームプラグインとして [RRethy/nvim-base16] が存在しています。このプラグインは [chriskempson/base16-vim] と違い、Neovim 組み込みの LSP や Tree-sitter のハイライトグループに対応しています。基本的に Lua で書かれていますが、`:colorscheme` 時に全てのカラースキームの設定を読み込んでおり Neovim の起動時間を増やしています。
本記事では使用するカラースキームだけを読み込むようにして Neovim 起動の足を引っ張らないようにするハックを紹介します。

# 結論

`:colorscheme` の実行前に `package.loaded['colors']` へ使用するカラースキームのみを含んだテーブルを格納します。

```vim
lua << EOF
package.loaded['colors'] = {
  ['<color-scheme-you-use>'] = require('colors.<color-scheme-you-use>'),
}
EOF

colorscheme base16-<color-scheme-you-use>
```

dein.vim を使っている場合は `hook_add` 内で `ColorSchemePre` autocmd を使って格納してもよいでしょう。

```vim
autocmd ColorSchemePre * lua package.loaded['colors'] = {
      \  ['<color-scheme-you-use>'] = require('colors.<color-scheme-you-use>'),
      \}
```

# 詳細

## 環境

読み込み時間の計測や読み込みが遅い原因の調査をした際の環境は以下のとおりです。

| ツール・プラグイン | バージョン                     |
|--------------------|--------------------------------|
| Neovim             | NVIM v0.7.0-dev+690-gc4d70dae8 |
| RRethy/nvim-base16 | `7344e74`                      |
| Zsh                | 5.8                            |
| jq                 | 1.6                            |

## プラグインをそのまま使用したときの読み込み時間の計測

プラグインをそのまま使用してカラースキームを設定したときのカラースキームファイルの読み込み時間を計測します。 起動時に以下のファイルを読み込みつつ、`nvim --startuptime` を使ってログを取ります。

```vim: all.vim
set runtimepath+=$XDG_CACHE_HOME/dein/repos/github.com/RRethy/nvim-base16

colorscheme base16-tomorrow-night-eighties
```

Neovim の起動 10 回の時間の平均を取ります。

```sh
$ repeat 10 nvim -u all.vim --startuptime all.log -c q
$ cat all.log | grep base16 | awk '{ print $2 }' >&2 | jq -s 'add/length'
020.564
021.828
025.621
022.383
021.194
019.710
021.420
018.889
020.373
019.108
021.841
026.219
018.513
21.358692307692305
```

カラースキームファイルの読み込みに約 21 ミリ秒かかっています。
なお、chriskempson/base16-vim を使った際のカラースキームファイル読み込みにかかった時間は約 10 ミリ秒でした。計測に使用したファイルと結果を折りたたみの中に記載しておきます。

:::details chriskempson/base16-vim を使った際の読み込み時間
```vim: legacy.vim
set runtimepath+=$XDG_CACHE_HOME/dein/repos/github.com/chriskempson/base16-vim

colorscheme base16-tomorrow-night-eighties
```

```sh
$ repeat 10 nvim -u legacy.vim --startuptime legacy.log -c q
$ cat legacy.log | grep base16 | awk '{ print $2 }' >&2 | jq -s 'add/length'
011.180
010.435
009.817
009.881
009.459
009.299
009.471
009.756
009.574
011.448
10.032
```
:::

実際に使用している Neovim の設定を使用して計測するとこれよりも多く時間がかかっていました。とても耐えられるものではなかったので読み込み時間を減らすため、時間がかかっているものは何かを調べました（プラグインのソースコードをひたすらコメントアウトしながら調べました）。
その結果、以下のファイルで 180 種類のカラースキームを読み込んでいる部分が原因と判明しました。
https://github.com/RRethy/nvim-base16/blob/7344e741b459c527b84df05a231b7e76d8b4fde9/lua/colors/init.lua
`colors/init.lua` が読み込まれる前、つまり `require('colors')` 前に必要なものだけを読み込むように `colors` モジュールを乗っ取ってしまえば改善が期待できそうです。なお、`colors` モジュールはカラースキーム設定用の `/colors/base16-***.vim` が読み込んでいるモジュールの中で読み込まれていました。

## モジュールの乗っ取り

Neovim の Lua では `require(modname)` が実行されるたびモジュールの解決を以下の順番で行い、最初に見つかったものが使用されます。

1. `package.loaded[modname]` に格納されている値
1. Neovim の `runtimepath` 下にある `lua/` ディレクトリー以下のファイル
1. `package.preload[modname]` に格納されている関数の実行結果
1. `package.path` に格納されているパス以下のファイル
1. `package.cpath` に格納されているパス以下のファイル
1. オールインワンローダーでのモジュール検索結果

:::message
dein.vim を使用している場合は 2 番目に（おそらく）`on_lua` の解決に使われるローダーが入ります。
:::

RRethy/nvim-base16 の `colors` モジュールは上記の順番の 2 番目に解決されるのでそれより前の `package.loaded` を使用すればモジュールを乗っ取れそうです。`package.loaded[modname]` には実際に使用する値を格納します。`colors/init.lua` を見るとモジュールとして使用しようとしているものは以下のようなテーブルだとわかります。

```lua
{
  ['<color-scheme-1>'] = require('colors.<color-scheme-1>'),
  ['<color-scheme-2>'] = require('colors.<color-scheme-2>'),
  ...
}
```

つまり、必要なカラースキームだけを `package.laoded['colros']` に格納すれば、`require('colors')` の実行時に 180 個の色設定ファイルは読み込まれなくなります。その結果、カラースキームファイルの読み込み時間が短縮されます。

```lua
package.loaded['colors'] = {
  ['<color-scheme-you-use>'] = require('colors.<color-scheme-you-use>'),
}
```

## 読み込むカラースキームを限定したあとの読み込み時間の計測

必要なカラースキームだけを読み込むようにしたあと、ちゃんと早くなっているのかを確認します。

```vim: mini.vim
set runtimepath+=$XDG_CACHE_HOME/dein/repos/github.com/RRethy/nvim-base16

lua << EOF
package.loaded['colors'] = {
  ['tomorrow-night-eighties'] = require('colors.tomorrow-night-eighties'),
}
EOF

colorscheme base16-tomorrow-night-eighties
```

```sh
$ repeat 10 nvim -u mini.vim --startuptime mini.log -c q
$ cat mini.log | grep base16 | awk '{ print $2 }' >&2 | jq -s 'add/length'
002.911
002.802
001.959
001.870
001.925
001.894
001.952
002.126
002.399
002.886
2.2724
```

読み込むカラースキームが 1 個の場合、約 2 ミリ秒になりました！プラグインをそのまま読み込んだときの約 21 ミリ秒よりも 10 倍近くも早くなりました。chriskempson/base16-vim 使用時の読み込み時間の約 10 ミリ秒と比べても格段に早くなっています。

# 終わりに

今回は [RRethy/nvim-base16] の読み込み時間短縮のために `package.loaded` を使用して必要なモジュールだけを読み込ませるようにしました。このハックは別のプラグインで自分が使いたいモジュールのみを読み込みたいときにも使用できるでしょう（例は思いつきませんが）。ただし、読み使いたいモジュールがそれのみで完結しているか、ソースコードを見ていく必要があります。さらに、プラグインを更新する場合はモジュールの構造に変化がないかを追っていかなければなりません。少なくとも個人的には、このプラグインの読み込み時間の大幅な改善にこれらの労力をつぎ込むのはコスパが良いと思ったため実際に使用しています。


# 参考

<!-- textlint-disable ja-technical-writing/sentence-length -->

- [https://github.com/RRethy/nvim-base16][RRethy/nvim-base16]
- [https://www.lua.org/manual/5.1/manual.html#5.3][Lua マニュアル]
- [https://github.com/neovim/neovim/blob/c4d70dae802ef074aaf54bdcbbd5f73380f74a86/src/nvim/lua/vim.lua#L87][Neovim ローダー]

[Vim Advent Calendar 2021]: https://qiita.com/advent-calendar/2021/vim
[RRethy/nvim-base16]: https://github.com/RRethy/nvim-base16
[chriskempson/base16-vim]: https://github.com/chriskempson/base16-vim
[Neovim ローダー]: https://github.com/neovim/neovim/blob/c4d70dae802ef074aaf54bdcbbd5f73380f74a86/src/nvim/lua/vim.lua#L87
[Lua マニュアル]: https://www.lua.org/manual/5.1/manual.html#5.3

<!-- vim: set wrap: -->
