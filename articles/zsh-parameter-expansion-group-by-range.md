---
title: "Zsh 変数展開の紹介〜連続した整数のグループ化〜"
emoji: "🏪"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["zsh"]
published: false
---

# Zsh 変数展開の紹介〜連続した整数のグループ化〜

Zsh では変数の値をそのまま使うだけでなく、さまざまな加工をしてから使うことができます。変数展開（Parameter Expansion）と呼ばれるこの加工手段は種類が豊富で高度なことを行えます。本記事では [整数配列の連続区間をハイフンで連結してグループ化する定番のアレ - Qiita] を Zsh で実装しながらいくつかの変数展開を紹介していきます。

紹介する変数展開は全て`zshexpn(1)`か以下のリンクからドキュメントを読めます。
- [14.3 Parameter Expansion]
- [14.3.1 Parameter Expansion Flags]

## 整数配列の連続区間をハイフンで連結してグループ化する定番のアレ

> ### 問題概要
>
> 要素に整数を取る配列に関して、以下のように処理する関数を作成せよ。
>
> 1. 連続する数字の集合を1つの区間とし、区間最小値と区間最大値をハイフンで連結して1つの文字列とする。区間最小値と区間最大値が等しい場合、その数字をそのまま文字列として扱うこととする。
> 1. 上記で生成した文字列をまとめて配列として返す。
>
> <cite>[整数配列の連続区間をハイフンで連結してグループ化する定番のアレ - Qiita]</cite>

## 変数展開の基本

Zsh の変数は`$name`で単純な展開ができます。しかし、加工のための様々な記号を含む場合（または変数の直後に変数名として解釈される文字を置きたい場合）には`${name}`のように中括弧を使用します。

変数展開は大まかに次の三つに分けられます。
- `name`の前に記号を置いて展開するもの（文字数や配列の要素数に変換する`${#name}`等）
- `name`の後に記号を置いて展開するもの（文字列の置換をする`${name/pattern/replacement}`等）
- `name`の前に記号を`()`と共に使って特殊な展開をするフラグ（変数の型に変換する`${(t)name}`等）

また、中括弧による変数展開は`${${name}}`のように入れ子にできます。

## 実装

それでは、以下のような、一つ目の引数に整数のリストを二つ目の引数に区間最小値・最大値を連結する文字を与え、生成した文字列を表示する関数を作っていきます。

```shell:group-by-range.zsh
group-by-range() {
    local numbers=$1
    local separator=$2
    local result=()

    echo $result
}
```

### 文字列の配列化・配列の結合

与えられた整数のリストを扱いやすいように配列にする必要があります。配列化はフラグを使うことで実現できます。配列の結語も配列化とほぼ同じなため、あわせて紹介します。

#### 例

`s:string:`フラグを使うことで、`string`によって文字列を分割し配列へと変換できます。また、`p`フラグを併用し`ps:string:`とすることで、変数や`print`コマンドで使用するものと同じエスケープシーケンスを`string`に指定できます。

```shell:例
$ value='foo bar "hoge fuga" 1 2'
$ echo ${(t)value}
scalar

# 文字列を ' ' で分割して配列にできます。配列を変数に入れる場合は値を`()`で囲む必要があります。
$ array=(${(ps: :)value})
$ echo ${(t)array}
array
$ for v in $array; do echo $v; done
foo
bar
"hoge
fuga"
1
2
```

:::message
`t`フラグを使うことで変数の型に変換できます。
:::

上の例では` `で文字列を分割しているので`"hoge`と`fuga"`に分かれています。これは分けずに`"hoge fuga"`と一つの文字列としてほしいこともあるでしょう。この悩みは`z`フラグを使うことで解決できます。`z`フラグはシェルの解析によって単語を分割します。つまり、シングルクォートやダブルクォートで囲ったものは一つの文字列として分割されます。

```shell:例
$ value='foo bar "hoge fuga" 1 2'
$ array=(${(z)value})
$ for v in $array; do echo $v; done
foo
bar
"hoge fuga"
1
2
```

分割に関するフラグは他にも、改行で分割する`(f)`（`(ps:\n:)`の省略形）、ヌル文字で分割する`(0)`（`(ps:\0:)`の省略形）があります。

また、フラグの`s`を`j`に変えることで配列を指定した文字列で結合できます。改行で結合する`(F)`（`(pj:\n:)`の省略形）も存在しています。

```shell:例
$ array=(foo bar 1 2)
$ echo ${(ps:-:)array}
foo-bar-1-2
$ echo ${(F)array}
foo
bar
1
2
```

#### 実装

今回は半角スペース区切りのリストを渡してもらい、それを配列へ変換することにしましょう。

```diff-shell:group-by-range.zsh
@@ -2 +2 @@
-    local numbers=$1
+    local numbers=(${(ps: :)1})
```

:::details 全体
```shell:group-by-range.zsh
group-by-range() {
    local numbers=(${(ps: :)1})
    local separator=$2
    local result=()

    echo $result
}
```
:::

### 重複削除・ソート

次は、整数の配列から重複した数を取り除き、小さい順で並べなければ話になりません。単純に考えたら`sort | uniq`や`sort -u`を使うでしょう。ですが、重複削除やソートは Zsh の変数展開で行うことができます！

#### 例

辞書順の昇順ソートは`(o)`フラグ、降順ソートは`(O)`フラグ、重複削除は`(u)`フラグで行なえます。ソートされていない配列でも重複を削除できます。これらのフラグは同時に指定することで重複削除とソートを一気に行えます。また、`(o)`または`(O)`に`(n)`フラグを添えることで辞書順ではなく数値でのソートになります。

```shell
value=(3 1 5 10 20 1 30 5 3)
echo ${(o)value}
1 1 10 20 3 3 30 5 5
echo ${(no)value}
1 1 3 3 5 5 10 20 30
echo ${(u)value}
1 3 5 10 20 30
echo ${(nou)value}
1 3 5 10 20 30
```

#### 実装

ソートや削除は配列でしか機能せず、配列は一度変数に入れないといけないため注意が必要です。

```diff-shell:group-by-range.zsh
@@ -2 +2,2 @@
     local numbers=(${(ps: :)1})
+    numbers=${(uo)numbers}
```

:::details 全体
```shell:group-by-range.zsh
group-by-range() {
    local numbers=(${(ps: :)1})
    numbers=${(uo)numbers}
    local separator=$2
    local result=()

    echo $result
}
```
:::

### 文字列にマッチした要素の削除・抽出

`(no)`によるソートは配列に負の数が含まれていると期待通りの動作になりません。

```shell:例
$ value=(1 -10 3 -2 2 10 20 -20 -1 -3)
$ echo ${(no)value}
-1 -2 -3 -10 -20 1 2 3 10 20
# -20 -10 -3 -2 -1 1 2 3 10 20 になってほしい
```

この結果を見ると`-`がついている値が先に`-`を無視して数値でソートされてから何もついていない値が数値でソートされているようです。それなら、`-`がついている値を抽出して降順でソートしたものと何もついていない値を抽出して昇順でソートしたものを組み合わせたら期待通りの結果を得られそうです。ほしい値を抽出する方法を見ていきましょう。

#### 例

抽出したものを取り除いたら、それは削除といえるでしょう。値を抽出する方法と削除する方法をあわせて紹介します。

<!-- textlint-disable ja-technical-writing/sentence-length -->

- `${name#pattern}` `${name##pattern}`
    値を先頭からみて`pattern`にマッチした部分を**削除**、`#`が一つだと最短マッチ、二つだと最長マッチ
    正規表現で表すとそれぞれ`^pattern` `^(pattern)+`
- `${name%pattern}` `${name%%pattern}`
    値を末尾からみて`pattern`にマッチした部分を**削除**、`%`が一つだと最短マッチ、二つだと最長マッチ
    正規表現で表すとそれぞれ`pattern$` `(pattern)+$`
- `${name:#pattern}`
    値が`pattern`と完全にマッチしていたら**削除**
    正規表現で表すと`^pattern$`
- `${name:|arrayname}`
    配列から`arrayname`（要素ではなく変数名）に含まれる要素を**削除**
    つまり、`name`にのみ存在する要素だけ残る（おそらく論理演算でいう非含意）
- `${name:*arrayname}`
    配列と`arrayname`（要素ではなく変数名）の両方に含まれる要素を**抽出**
    つまり、論理積

<!-- textlint-enable ja-technical-writing/sentence-length -->

:::message
上記で使用されている`pattern`は`グロブ`を取ります。
:::

また、`pattern`を使用している最初の 3 種類は`(M)`フラグを併用することで**削除**を**抽出**に変えられます。

```shell:例
$ value=(quad quit queue quote)
$ second_value=(queue queen)

# 先頭から最短マッチした部分を削除
$ echo ${value#q*e}
quad quit Ue

# 先頭から最長マッチした部分を削除
$ echo ${value##q*e}
quad quit quick

# 先頭から最長マッチした部分を「抽出」
$ echo ${(M)value##q*e}
queue quote

# 末尾から最短マッチした部分を削除
$ echo ${value%u*e}
quad quit que q

# 末尾から最長マッチした部分を削除
$ echo ${value%%u*e}
quad quit q q

# 末尾から最長マッチした部分を「抽出」
$ echo ${(M)value%%u*e}
ueue uote

# 完全にマッチしていたら削除
$ echo ${value:#q???}
quick quote

# 完全にマッチしていたら「抽出」
$ echo ${(M)value:#q???}
quad quit

# value から second_value に含まれる要素を削除
echo ${value:|second_value}
quad quit quote

# value と second_value 両方に含まれる要素を抽出
echo ${value:*second_value}
queue
```

#### 実装

負の値と 0 を含む正の値をそれぞれ抽出した後ソートして結合していきましょう。今回は両方とも`(M)`フラグと`:#`を利用して抽出していきます。また、ここで使用しているグロブ`##`は`EXTENDED_GLOB`オプションを有効にする必要があります。

```shell:例
$ setopt EXTENDED_GLOB
$ value=(1 -10 3 -2 2 10 20 -20 -1 -3)
$ echo ${(no)${(M)value:#[[:digit:]]##}}
1 2 3 10 20
$ echo ${(nO)${(M)value:#-[[:digit:]]##}}
-20 -10 -3 -2 -1
```

:::message
グロブ`##`は直前のパターンが 1 回以上出現するものにマッチします。正規表現の`+`と同じです。
:::

```diff-shell:group-by-range.zsh
@@ -2,2 +1,5 @@
+    setopt LOCAL_OPTIONS EXTENDED_GLOB
     local numbers=(${(ps: :)1})
-    numbers=${(uo)numbers}
+    local positives=(${(nuo)${(M)numbers:#[[:digit:]]##}})
+    local negatives=(${(nuO)${(M)numbers:#-[[:digit:]]##}})
+    numbers=($negatives $positives)
```

:::details 全体
```shell:group-by-range.zsh
group-by-range() {
    setopt LOCAL_OPTIONS EXTENDED_GLOB
    local numbers=(${(ps: :)1})
    local positives=(${(nuo)${(M)numbers:#[[:digit:]]##}})
    local negatives=(${(nuO)${(M)numbers:#-[[:digit:]]##}})
    numbers=($negatives $positives)
    local separator=$2
    local result=()

    echo $result
}
```
:::

### 置換

#### 例

`${name/pattern/replacement}`を使うことで値の`pattern`でマッチする最初に部分を`replacement`で置き換えることができます。最初の記号を`${name//pattern/replacement}`のようにスラッシュ二つ`//`にするとマッチした部分全てが置き換えられます。`${name:/pattern/new}`のように`:/`にすると値が`pattern`と完全にマッチした場合のみ置き換えられます。また、`pattern`の最初に`#`がついている場合`pattern`は値の先頭で、`%`がついている場合`pattern`は値の末尾でマッチした部分を置き換えられます。`#%`がついている場合は値全体でマッチした場合に置き換えられます。なお、置換は最長マッチで行われますが、`(S)`フラグを併用することで最短マッチでの置換になります。

```shell:例
$ value=(ab cde fghi jklmn)
$ echo ${value/??/--}
-- --e --hi --lmn
$ echo ${value//??/--}
-- --e ---- ----n
$ echo ${value:/??/--}
-- cde fghi jklmn
$ echo ${value//%??/--}
-- c-- fg-- jkl--

$ value='twinkle twinkle little star'
$ echo ${value//t*e/spy}
spy star
$ echo ${(S)value//t*e/spy}
spy spy lispy star
```

### 変数が定義済み家の確認と変数のデフォルト値

#### 例

`${+name}`は値が定義済みの場合`1`、定義されていない場合は`0`に変換されます。

`${name-default}`は`name`が未定義、つまり`${+name}`が`0`か値が空の場合に`default`へ変換されます。`${name:-default}`は
`name`が定義済みだが値が空の場合に`default`へ変換されます。

```shell:例
$ unset value
$ echo ${+value}
0
$ echo ${value-default}
default
$ echo ${value:-default}
default

$ value=
$ echo ${+value}
1
$ echo ${value-default}

$ echo ${value:-default}
default

$ value=not-default
$ echo ${+value}
1
$ echo ${value-default}
not-default
$ echo ${value:-default}
not-default
```

### 残りの部分の実装

これまでに紹介した変数展開で残りの部分を実装するとこうなります。

```diff-shell:group-by-range.zsh
@@ -7 +7 @@
-    local separator=$2
+    local separator=${2--}
@@ -10 +10,12 @@
-    echo $result
+    local number
+    local tmp_separator=,
+    for number in $numbers; do
+        if [[ -n ${result[-1]} ]] && (( $number == ${${result[-1]}#*$tmp_separator} + 1 )); then
+            result[-1]="${${result[-1]}%$tmp_separator*}$tmp_separator$number"
+            continue
+        fi
+
+        result+=($number)
+    done
+
+    echo ${result//$tmp_separator/$separator}
```

:::details 全体
```shell:group-by-range.zsh
group-by-range() {
    setopt LOCAL_OPTIONS EXTENDED_GLOB
    local numbers=(${(ps: :)1})
    local positives=(${(nuo)${(M)numbers:#[[:digit:]]##}})
    local negatives=(${(nuO)${(M)numbers:#-[[:digit:]]##}})
    numbers=($negatives $positives)
    local separator=${2--}
    local result=()

    local number
    local tmp_separator=,
    for number in $numbers; do
        if [[ -n ${result[-1]} ]] && (( $number == ${${result[-1]}#*$tmp_separator} + 1 )); then
            result[-1]="${${result[-1]}%$tmp_separator*}$tmp_separator$number"
            continue
        fi

        result+=($number)
    done

    echo ${result//$tmp_separator/$separator}
}
```
:::

追加部分を解説します。

```shell
local separator=${2--}
```

関数の第二引数に連結文字が指定されなかった場合`-`を使うように設定します。`${2:--}`ではないので第二引数に空文字列が与えられた場合は空文字列が与えらたら空文字列で連結するようになっています。

```shell
local tmp_separator=,
```

[整数配列の連続区間をハイフンで連結してグループ化する定番のアレ - Qiita]では連続区間をいったん配列でグループ化してから連結文字で連結しています。しかし、今回は文字列をこねくり回すことで連続区間をハイフンで連結しています。文字列をこねくり回す際、連結文字が`-`だと負の値の`-`と区別をつけにくく実装が複雑になってしまうため、一時的な連結文字として`,`を使用しています。

```shell
[[ -n ${result[-1]} ]] && (( $number == ${${result[-1]}#*$tmp_separator} + 1 ))
```

if 文の条件式はまず、配列`$result`に最後の要素が存在しているかを確認しています。これは存在していない変数と数値を演算した場合存在していない変数は 0 として計算されてしまうためです。その後、`${name#pattern}`を利用して最後の要素の先頭から一時的な連結文字の`,`までを削除し、 1 を加えたものが現在の数値と同値か確かめています。

```shell
result[-1]="${${result[-1]}%$tmp_separator*}$tmp_separator$number"
```

配列`$result`の最後の要素の`,`以降の文字を`${name%pattern}`を使って削除して現在の値に置き換えています。置換を使って`${${result[-1]}//$tmp_separator*/$tmp_separator$number}`とした場合、グループ化されていない単一の値だった場合に対応できません。そのため、いったん削除してから新しく値を置いています。

```shell
echo ${result//$tmp_separator/$separator}
```

置換を用いて一時的な連結文字を実際の文字へと置き換えています。

#### 動作確認

さて、これで実装は終わりました。ちゃんと連続した整数をグループ化できるか試してみましょう。せっかくなので入力値は引用記事からコピペした PHP の配列に変数展開を使ってスペース区切りの文字列へと変換してしまいましょう。

> ```php:入力
> [1,2,3,4,5,8,9,10,13,14,20,22]
> ```
>
> <cite>[整数配列の連続区間をハイフンで連結してグループ化する定番のアレ - Qiita]</cite>

```shell
$ source ./group-by-range.zsh
$ input=[1,2,3,4,5,8,9,10,13,14,20,22]
$ group-by-range ${${${input//,/ }#\[}%\]}
1-5 8-10 13-14 20 22
```

:::message
変数展開部分は 3 重にネストされていて少し見づらいですが内側から見ていくと次のようになっています。

1. `,`を` `に置換
1. 先頭の`[`を削除（`[`はグロブで使う記号なのでエスケープが必要）
1. 末尾の`]`を削除（同様）
:::

しっかりとグループ化できているようです！整数のリストに負の値を含めたり連結文字を変えてみたりしましょう。

```shell
$ group-by-range '1 -1 3 -3 5 -5 4 2 -2 -4 -10 -9 -8 8 9 10 -13 -14 20 22 -22 -20 14 13'
-22 -20 -14--13 -10--8 -5--1 1-5 8-10 13-14 20 22
$ group-by-range '1 -1 3 -3 5 -5 4 2 -2 -4 -10 -9 -8 8 9 10 -13 -14 20 22 -22 -20 14 13' '~'
-22 -20 -14~-13 -10~-8 -5~-1 1~5 8~10 13~14 20 22
```

負の値や連結文字も問題なさそうです。お疲れさまでした。

## 終わりに

文字列の配列化、配列の結合、重複削除、ソート、値の削除や抽出、置換等今回は配列（や文字列）そのものをいじる変数展開を紹介しました。 Zsh には他にも、文字列の大文字小文字を変換するフラグや文字列のクォートをいじるフラグ等便利な変数展開フラグが数十個存在しています。 [14.3.1 Parameter Expansion Flags] を参照して面白そうなフラグを試してみるのも良いでしょう。また、今回は機会がなかったため紹介しませんでしたが、配列の添字を指定する際に使う添字フラグも存在しています。どんなものがあるか気になった人は`zshparam(1)`または [15.2.3 Subscript Flags] を確認してみてください。便利な変数展開、一つ覚えるだけでも Zsh 生活を鮮やかにしてくれるでしょう。

整数だけでなく文字のグループ化にも対応したものが [Gist][group-by-range Gist] に置いてあります。


[整数配列の連続区間をハイフンで連結してグループ化する定番のアレ - Qiita]: https://qiita.com/mpyw/items/0fdffd3c70b3abd802f5
[14.3 Parameter Expansion]: https://zsh.sourceforge.io/Doc/Release/Expansion.html#Parameter-Expansion
[14.3.1 Parameter Expansion Flags]: https://zsh.sourceforge.io/Doc/Release/Expansion.html#Parameter-Expansion-Flags
[15.2.3 Subscript Flags]: https://zsh.sourceforge.io/Doc/Release/Parameters.html#Subscript-Flags
[group-by-range Gist]: https://gist.github.com/hexium310/76a40d80b7014ca29685350d46667335
