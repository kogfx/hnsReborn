<div align="center">
  <h3>⚠️ 注意 ⚠️</h3>
  <strong>ここに書かれた書式が全てhnsRebornで使えるわけではありません。</strong>
</div>

---

#### ハイパー日記システム Version 2.20

# hnf の記述方法

---

### <a name="overview">ハイパー日記ファイルの概要</a>

ハイパー日記システムでは、日々の日記は 非常に単純なテキスト・ファイルである hnf(Hyper Nikki File) に記述します。 ファイルの名前は "d日付.hnf" です。 例えば 20001年12月1日の場合は "d20011201.hnf" です。 当然 " は省きますし、全て半角小文字です(全角文字ではありません)。

hnf は，日記ディレクトリ(~/diary/)以下に年別のディレクトリを作成し置きます． ~/diary/2001/ には， 2001年の hnf を置きます( ~/diary/ に hnf を置く方法は、廃止されました。)

hnf の漢字コードは，JIS/S-JIS/EUC のいずれでも表示可能ですが，**EUC で書くことを推奨**します．

hnf のファイルの更新時刻は様々に利用されます．hnf をコピーする場合などは， ファイルの更新時刻情報を保持する tar や cp -p を利用することを お勧めいたします．

hnf の基本構造は以下のとおりです．

* コマンドは行頭に置きます。 スペース一つでも空いているとコマンドとして認識されません。
* 1行に1コマンドのみが記述できます．コマンド行の最後は必ず改行します。
* コマンドは全て半角アルファベットの大文字で書きます．
* コマンドの引数は基本的にスペースで区切ります。
* 文末に「~」が存在すると <BR> に置きかえられます。
* hnf はヘッダ部と本文に分かれます．
* ヘッダ部と本文の間は改行のみの1行が来ます．
* ヘッダ部には， [ユーザ変数](user_var-j.html)を記述します(記述しなくても 構いません)．
* ヘッダ部には空白行があってはなりません．
* ヘッダ部の最終行は「OK」だけにしてください。
* OK が存在しないと、その日の日記は表示されません．
* 本文は必ず NEW,LNEW,RLNEW(又は CAT 又は GRP) から始めます．
* 行の先頭の半角アルファベット大文字の文字列は， それがコマンドでなくとも将来コマンドとして使用される可能性があります． このような場合は，スペースを前に入れていただくか， 半角アルファベット大文字の文字列の直後にスペースを入れずに 本文を入力することをお奨めします．

---

### <a name="sample">hnf の例</a>

hnf は以下のような簡単なファイルです．

```text
----- start -----
TENKI 曇
OK

NEW Namazu for hns 1.0.2 リリース
おバカな仕様を修正した 1.0.2 をリリースいたしました．
~
hns-1.02.tar.gz に付属の「Namazu for hns」のドキュメントは
古くなっておりますので，ウェブにあるものを御覧下さい．

NEW No hnf bug
いきなり初の bug が発見されてしまいました．ただし日記を書けば，
実害はありません．
~
詳細は，
LINK http://www.h14m.org/docs/known_bugs-j.html バグ報告
をご覧ください．patch を現在準備中です．
----- end -----
```

hnf および実際の表示例は， [公式日記の hnf](http://www.h14m.org/official_diary/official_diary/) と [公式日記](http://www.h14m.org/official_diary/) を参照してください．

---

### コマンド一覧

コマンドが生成する HTMLタグ は， [テーマ設定](theme-j.html)(theme.ph)によって ほぼカスタマイズ可能です． カスタマイズ可能ですが，コマンドの意味は変わりません． また，変えてはいけません．なお，日記は以下の「基本コマンド」のみで 書くことができます．

### <a name="basic_commands">基本コマンド</a>

<dl>
  <dt><a name="NEW"><strong>NEW</strong></a></dt>
  <dd><b>文法: NEW 1行の文章</b><br>
   セクションのタイトルを記述します． タイトル行は，リンク可能なように自動的にアンカー(a name) が定義されます．アンカー は上から順に数字が増えていきますので， NEW と NEW の間に新しいセクションを追加してはいけません． NEW と NEW の間に新しいセクションを追加するとどこかのページから リンクされている場合，リンク先がずれてしまいます． NEW は必須のコマンドです．必ず記述してください．</dd>
</dl>

<dl>
  <dt><a name="SUB"><strong>SUB</strong></a></dt>
  <dd><b>文法: SUB 1行の文章</b><br>
   セクション内のサブ・セクションのタイトルを記述します． サブ・セクションもリンク可能なように自動的にアンカー(a name) が定義されます．SUB と SUB の間に新しいサブ・セクションを 追加してはいけません．理由は NEW と同じです．</dd>
</dl>

<dl>
  <dt><a name="~"><strong>~</strong></a></dt>
  <dd><b>文法: ~</b><br>
   タグ&lt;br&gt; を表示します．つまり改行されます．このコマンドは， 文末にあったときのみコマンドして認識されます．</dd>
</dl>

---

### <a name="application_command">応用コマンド</a>

#### 基本コマンド拡張コマンド

<dl>
  <dt class="c2"><a name="CAT"><strong>CAT</strong></a></dt>
  <dd><b>文法: CAT カテゴリ1 [カテゴリ2 ...]</b><br>
   <b>例: CAT lynx install</b><br>
   セクションのカテゴリ(分類)を記述します．日記の内容を， カテゴリで分類したい場合に使用します．使用しなくても 構いません． CATコマンドは NEW, LNEW または RLNEW の直前にのみ指定できます． タイトル行にカテゴリ別のアイコンを表示させることも可能です． 詳細は，<a href="cat-j.html">日記のカテゴリ分類の方法</a>をご覧下さい．</dd>
</dl>

<dl>
  <dt class="c2"><a name="LNEW"><strong>LNEW</strong></a></dt>
  <dd><b>文法: LNEW url 1行の文章</b><br>
   <b>例: LNEW http://www.h14m.org/ ハイパー日記システム</b><br>
   <a href="#NEW">NEW</a> と同様セクションのタイトルを指定しますが，url へリンクが 張られます．</dd>
</dl>

<dl>
  <dt class="c2"><a href="#RLNEW"><strong>RLNEW</strong></a></dt>
</dl>

<dl>
  <dt class="c2"><a name="LSUB"><strong>LSUB</strong></a></dt>
  <dd><b>文法: LSUB url 1行の文章</b><br>
   <b>例: LSUB http://www.h14m.org/ ハイパー日記システム</b><br>
   <a href="#SUB">SUB</a> と同様サブ・セクションのタイトルを指定しますが，url へリンクが張られます．</dd>
</dl>

<dl>
  <dt class="c2"><a href="#RLSUB"><strong>RLSUB</strong></a></dt>
</dl>

<dl>
  <dt class="c2"><a name="P"><strong>P</strong></a></dt>
  <dd><b>文法: P</b><br>
   タグ&lt;p&gt; を表示します。段落を分けます。Pコマンドは、 /Pコマンドで閉じる必要があります。</dd>
</dl>

<dl>
  <dt class="c2"><a name="/P"><strong>/P</strong></a></dt>
  <dd><b>文法: /P</b><br>
   Pコマンドを閉じます。タグ&lt;/p&gt; を表示します。</dd>
</dl>

<dl>
  <dt class="c2"><a name="GRP"><strong>GRP</strong></a></dt>
  <dd><b>文法: GRP グループ1 [グループ2 ...]</b><br>
   <b>例: GRP ruri shinomu</b><br>
   <a href="grp-j.html"> ひみつ交換日記機能</a>を利用します。 GRPコマンドはそのセクションに CAT がある場合は、CAT の直前に、 CAT がない場合は、NEW, LNEW または RLNEW の直前にのみ指定できます． 詳細は，<a href="grp-j.html">ひみつ交換日記機能</a>をご覧下さい．</dd>
</dl>

#### リンク・コマンド

<dl>
  <dt class="c2"><a name="LINK"><strong>LINK</strong></a></dt>
  <dd><b>文法: LINK url 説明文章</b><br>
   <b>例: LINK http://www.h14m.org/ ハイパー日記システム</b><br>
   リンクを張ります． 例は，「 <a href="http://www.h14m.org/ ">ハイパー日記システム</a> 」と表示されます．</dd>
</dl>

<dl>
  <dt class="c2"><a name="URL"><strong>URL</strong></a></dt>
  <dd><b>文法: URL url 説明文章</b><br>
   <b>例: URL http://www.h14m.org/ ハイパー日記システム</b><br>
   URL を記述しリンクを張ります．例では「 <a href="http://www.h14m.org/"> ハイパー日記システム(http://www.h14m.org/)</a> 」と表示されます．URL を明示したい場合に使用します．</dd>
</dl>

<dl>
  <dt class="c2"><a name="RLINK"><strong>RLINK</strong></a></dt>
  <dd>
    <b>文法: RLINK 引数1 引数2 説明文章</b><br>
     <b>例: RLINK hoge ?19981201 説明文章</b><br>
     「説明文章」としてリンクされる点は，<a href="#LINK">LINK</a>コマンド と同様ですが， ~/diary/conf/rlink.txt で定義した URL に最初の 引数1 が置き換えられます． よくリンクする URL を設定し日記の記述を省略するために用意されました．<br>
     定義ファイルrlink.txt は
<pre>
定義文字列[スペース]URL
</pre>
    と記述します。例えば，
<pre>
hoge http://www.example.ne.jp/~hoge/diary/
</pre>
    のように記述します． この場合，上記のコマンド例は， http://www.example.ne.jp/~hoge/diary/?19981201 へのリンクを張ります．
  </dd>
</dl>

<dl>
  <dt class="c2"><a name="RLNEW"><strong>RLNEW</strong></a></dt>
  <dd><b>文法: RLNEW 引数1 引数2 1行の文章</b><br>
   <a href="#NEW"> NEW</a>コマンド同様、新しいセクションのタイトルを 記述しますが、 同時に<a href="#RLINK">RLINK</a>コマンド同様にリンクを指定します。</dd>
</dl>

<dl>
  <dt class="c2"><a name="RLSUB"><strong>RLSUB</strong></a></dt>
  <dd><b>文法: RLSUB 引数1 引数2 1行の文章</b><br>
   <a href="#SUB"> SUB</a>コマンド同様、新しいサブ・セクションのタイトルを 記述しますが、 同時に<a href="#RLINK">RLINK</a>コマンド同様にリンクを指定します。</dd>
</dl>

<dl>
  <dt class="c2"><a href="#LNEW"><strong>LNEW</strong></a></dt>
</dl>

<dl>
  <dt class="c2"><a href="#LSUB"><strong>LSUB</strong></a></dt>
</dl>

<dl>
  <dt class="c2"><a href="#LSTRIKE"><strong>LSTRIKE</strong></a></dt>
</dl>

<dl>
  <dt class="c2"><a href="#LIMG"><strong>LIMG</strong></a></dt>
</dl>

#### 装飾コマンド

<dl>
  <dt class="c2"><a name="FONT"><strong>FONT</strong></a></dt>
  <dd><b>文法: FONT 引数1 引数2 文章</b><br>
   <b>例: FONT COLOR red 赤い文字</b><br>
   タグ&lt;font&gt; を表示します．上記例では，「<span class="c3">赤い文字</span>」と表示されます．</dd>
</dl>

<dl>
  <dt class="c2"><a name="STRIKE"><strong>STRIKE</strong></a></dt>
  <dd><b>文法: STRIKE 文章</b><br>
   タグ&lt;strike&gt; を表示します． 「<strike>文章</strike>」と表示されます．</dd>
</dl>

<dl>
  <dt><a name="LSTRIKE"><strong>LSTRIKE</strong></a></dt>
  <dd><b>文法: LSTRIKE url 文章</b><br>
   <b>例: LSTRIKE http://www.h14m.org/ ルリ少佐万歳</b><br>
   STRIKEコマンドと同様 タグ&lt;strike&gt; を表示しますが，同時に リンクを張ります．</dd>
</dl>

<dl>
  <dt><a name="STRONG"><strong>STRONG</strong></a></dt>
  <dd><b>文法: STONG 文章</b><br>
   <b>例: STRONG ルリ少佐万歳</b><br>
   タグ&lt;strong&gt; を表示します．例は， 「<strong>ルリ少佐万歳</strong>」と表示されます．</dd>
</dl>

<dl>
  <dt><a name="SPAN"><strong>SPAN</strong></a></dt>
  <dd><b>文法: SPAN class_name 文章</b><br>
   タグ&lt;span class="class_name"&gt; を表示します． class は CSS で事前に定義しておく必要があります。</dd>
</dl>

<dl>
  <dt class="c2"><a name="DIV"><strong>DIV</strong></a></dt>
  <dd><b>文法: DIV class_name</b><br>
   タグ&lt;div class="class_name"&gt; を表示します． class は CSS で事前に定義しておく必要があります。 DIV は /DIV で閉じる必要があります．</dd>
</dl>

<dl>
  <dt class="c2"><a name="/DIV"><strong>/DIV</strong></a></dt>
  <dd><b>文法: /DIV</b><br>
   タグ&lt;/div&gt; を表示します．</dd>
</dl>

#### 画像コマンド

<dl>
  <dt class="c2"><a name="IMG"><strong>IMG</strong></a></dt>
  <dd><b>文法: IMG {r|l|n} ファイル名 説明文字列</b><br>
   <b>例: IMG l pic1.gif ルリの写真</b><br>
   タグ&lt;img src&gt; を表示します．r は画像を右に，l は画像を左に表示します．1.03-pl1 からは n も指定可能に なりました．n を指定すると align を付けません．説明文字列は画像の説明を 記述します。なお、画像の表示サイズは、 <a href="config-j.html#ImgWidthMaxSize">ImgWidthMaxSize</a> により自動的に調整されます。</dd>
</dl>

<dl>
  <dt class="c2"><a name="LIMG"><strong>LIMG</strong></a></dt>
  <dd><b>文法: LIMG url {r|l|n} ファイル名 説明文字列</b><br>
   <b>例: LIMG http://www.h14m.org/ l pic1.gif ルリの写真</b><br>
   タグ&lt;img src&gt; を表示しリンクを張ります。r は画像を右に，l は画像を左に表示します． n を指定すると align を付けません．説明文字列は画像の説明を 記述します。</dd>
</dl>

<dl>
  <dt class="c2"><a name="MARK"><strong>MARK</strong></a></dt>
  <dd><b>文法: MARK 引数</b><br>
   <b>例: MARK !!</b><br>
   あらかじめ定義されたアイコンを表示します． 引数もあらかじめ定義されたものを指定します． MARK は <a href="theme-j.html">テーマ</a> により定義されています．また，自分で定義することも可能です． アイコンを指定する引数については，互換性を確保する観点から， ハイパー日記システム・プロジェクトで <a href="mark-j.html"> 標準マーク</a>を定めて公開します．</dd>
</dl>

#### 箇条書コマンド

<dl>
  <dt class="c2"><a name="UL"><strong>UL</strong></a></dt>
  <dd><b>文法: UL</b><br>
   タグ&lt;ul&gt; を表示します．UL の後には，LIコマンドが必要です．また，/UL で ULコマンドを 閉じる必要があります．</dd>
</dl>

<dl>
  <dt class="c2"><a name="/UL"><strong>/UL</strong></a></dt>
  <dd><b>文法: /UL</b><br>
   タグ&lt;/ul&gt; を表示します．</dd>
</dl>

<dl>
  <dt class="c2"><a name="OL"><strong>OL</strong></a></dt>
  <dd><b>文法: OL</b><br>
   タグ&lt;ol&gt; を表示します．OL の後には，LIコマンドが必要です．また，/OL で OLコマンドを 閉じる必要があります．</dd>
</dl>

<dl>
  <dt class="c2"><a name="/OL"><strong>/OL</strong></a></dt>
  <dd><b>文法: /OL</b><br>
   タグ&lt;/ol&gt; を表示します．</dd>
</dl>

<dl>
  <dt class="c2"><a name="LI"><strong>LI</strong></a></dt>
  <dd><b>文法: LI 文章</b><br>
   タグ&lt;li&gt; を表示します．LI を書く前に ULまたはOLコマンドが必要です．</dd>
</dl>

<dl>
  <dt class="c2"><a name="DL"><strong>DL</strong></a></dt>
  <dd><b>文法: DL</b><br>
   タグ&lt;dl&gt; を表示します．</dd>
</dl>

<dl>
  <dt class="c2"><a name="DT"><strong>DT</strong></a></dt>
  <dd><b>文法: DT 文章</b><br>
   タグ&lt;dt&gt; を表示します．DT を書く前に DLコマンドが必要です．</dd>
</dl>

<dl>
  <dt class="c2"><a name="DD"><strong>DD</strong></a></dt>
  <dd><b>文法: DD 文章</b><br>
   タグ&lt;dd&gt; を表示します．DD を書く前に DLコマンドが必要です．</dd>
</dl>

<dl>
  <dt class="c2"><a name="/DL"><strong>/DL</strong></a></dt>
  <dd><b>文法: /DL</b><br>
   タグ&lt;/dl&gt; を表示します．</dd>
</dl>

#### 引用系コマンド

<dl>
  <dt class="c2"><a name="PRE"><strong>PRE</strong></a></dt>
  <dd><b>文法: PRE</b><br>
   タグ&lt;pre&gt; を表示します．PRE は /PRE で閉じる必要があります．</dd>
</dl>

<dl>
  <dt class="c2"><a name="/PRE"><strong>/PRE</strong></a></dt>
  <dd><b>文法: /PRE</b><br>
   タグ&lt;/pre&gt; を表示します．</dd>
</dl>

<dl>
  <dt class="c2"><a name="CITE"><strong>CITE</strong></a></dt>
  <dd><b>文法: CITE</b><br>
   タグ&lt;blockquote&gt; を表示します．引用を記述する場合に使います． /CITEコマンドで閉じる必要があります．</dd>
</dl>

<dl>
  <dt class="c2"><a name="/CITE"><strong> /CITE</strong></a></dt>
  <dd><b>文法: /CITE</b><br>
   タグ&lt;/blockquote&gt; を表示します．</dd>
</dl>

#### コメント系コマンド

<dl>
  <dt class="c2"><a name="!"><strong>!</strong></a></dt>
  <dd><b>文法: ! 一行の文章</b><br>
   HTMLでのコメント &lt;!-- 一行の文章 --&gt; を表示します．つまり通常ブラウザでは表示されません．ただし HTMLソースを 読むと見ることができます． <a href="unagi2-j.html">Namazu for hns</a> では検索可能です．</dd>
</dl>

<dl>
  <dt class="c2"><a name="!#"><strong>!#</strong></a></dt>
  <dd><b>文法: !# 一行の文章</b><br>
   なにも表示されません．HTMLソースにも表示されません． ただし，Namazu for hns では検索可能です．</dd>
</dl>

<dl>
  <dt class="c2"><a name="FN"><strong>FN</strong></a></dt>
  <dd><b>文法: FN</b><br>
   脚注を記載します．FNコマンドは引数をとりません． 脚注の内容は，次の行以降に記載して下さい． /FNコマンドで閉じる必要があります． FN ～ /FN内には <a href="#LINK">LINK</a>, <a href="#STRIKE"> STRIKE</a>, <a href="#~">~</a>コマンド のみが使用可能です．脚注は各セクションの末尾に表示されます．</dd>
</dl>

<dl>
  <dt class="c2"><a name="/FN"><strong>/FN</strong></a></dt>
  <dd><b>文法: /FN</b><br>
   FNコマンドを閉じます．</dd>
</dl>

#### 置換コマンド

<dl>
  <dt class="c2"><a name="ALIAS"><strong> ALIAS</strong></a></dt>
  <dd>
    <b>文法: ALIAS 引数</b><br>
     <b>例: ALIAS hns</b><br>
     ~/diary/conf/alias.txt で定義した 文字列に 引数 が置き換えられます． よくリンクする URLなど を設定し日記の記述を省略するために用意されました．<br>
     定義ファイルalias.txt は，
<pre>
引数[スペース]置き換えたい文字列
</pre>
    と記述します． 例えば，
<pre>
hns &lt;a accesskey="L" href="http://www.h14m.org/"&gt;ハイパー日記システム&lt;/a&gt;
</pre>
    のように記述します． この場合，上記のコマンド例は， 「<a accesskey="L" href="http://www.h14m.org/">ハイパー日記システム</a>」と変換されます．
  </dd>
</dl>


#### テーブル系コマンド

<dl>
  <dt class="c2"><a name="RT"><strong>RT</strong></a></dt>
  <dd><b>文法: RT</b><br>
    <a href="#rt_table_enhancement">RT方式</a> によるテーブル表示を行います． RTコマンドは引数をとりません． RT方式によるテーブル記述内容は，次の行以降に記述して下さい． /RTコマンドで閉じる必要があります．
  </dd>
</dl>

<dl>
  <dt class="c2"><a name="/RT"><strong>/RT</strong></a></dt>
  <dd><b>文法: /RT</b><br>
    RTコマンドを閉じます．
  </dd>
</dl>

---

### <a name="link_enhancement">リンク拡張</a>

<p>LNEW, LSUB, LINK, URL, LSTRIKE で指定する url が特定の書式の場合、 以下のように変換されます。</p>

<dl>
  <dt class="c2"><a name="mydiary1"><strong> #YYYYMMDD[x[Sy]]</strong></a></dt>
  <dd>自分の日記へのリンクに変換されます。デフォルトでは 動的生成時は "$MyDiaryURI?YYYYMM[abc]#YYYYMMDDxSy" へのリンクに、 静的生成時は "./YYYYMM.html#YYYYMMDDxSy" へのリンクになります。<br>
   <b>例: LINK #200104011 4月1日の第1セクション</b><br>
   動的生成では 「&lt;a href="http://example.ne.jp/~hoge/diary/?200104a#20010411"&gt; 4月1日の第1セクション&lt;/a&gt; 」と変換されます。<br>
   静的生成では「&lt;a href="./200104.html#20010411"&gt; 4月1日の第1セクション&lt;/a&gt; 」と変換されます。</dd>
</dl>

<dl>
  <dt class="c2"><a name="mydiary2"><strong> #{YYYY,MM,DD[,x[,y]]}</strong></a></dt>
  <dd>自分の日記へのリンクに変換されます。#YYYYMMDDxSy と同様です。</dd>
</dl>

<dl>
  <dt class="c2"><a name="mydiary3"><strong> #{<i>any-string</i>#YYYYMMDD[x[Sy]]}</strong></a></dt>
  <dd>自分の日記へのリンクに変換されます。 "#YYYYMMDDxSy" 以前は任意の文字列です。<br>
  <b>例: LINK #{http://www.example.ne.jp/~hoge/diary/200104a?to=20010401#200104011} 4月1日の第1セクション</b><br>
  "#200104011" と同様に変換されます。</dd>
</dl>

<dl>
  <dt class="c2"><a name="isbn"><strong> ISBN:1-2345-6789-0</strong></a></dt>
  <dd>オンライン書店で ISBN コードを検索します。</dd>
</dl>

<dl>
  <dt class="c2"><a name="cd"><strong> CD:ABCD-1234</strong></a></dt>
  <dd>オンライン CD ショップ で CD 品番を検索します。</dd>
</dl>
<dl>
  <dt class="c2"><a name="hns-dev"><strong> hns-dev:1</strong></a></dt>
  <dd><a href="http://www.h14m.org/hns-dev-ML-j.html">hns開発ML</a>の 任意の番号のアーカイブを表示します。</dd>
</dl>
<dl>
  <dt class="c2"><a name="hns-users"><strong> hns-users:1</strong></a></dt>
  <dd><a href="http://www.h14m.org/hns-users-ML-j.html">hnsサポートML</a>の 任意の番号のアーカイブを表示します。</dd>
</dl>

---

### <a name="rt_table_enhancement">RTテーブル拡張</a>

#### <a name="rt_what">RT方式:</a>

RT方式とは、rubikitch氏制作の <a href="http://www.ruby-lang.org/~rubikitch/computer/rt.html">RTtool</a> で使用されている作表フォーマットです。簡潔な書式で複雑な表も楽に記述可能です。

#### <a name="rt_basic">基本形:</a>

<strong>RT</strong>～<strong>/RT</strong>で囲まれた領域に RT方式の記述 があった場合、テーブルに変換します。

```text
 RT
 1,2,3
 4,5,6
 7,8,9
 /RT
```

<table border='1'>
<caption><strong></strong></caption>
<tbody><colgroup span='3'>

<tr><td align='right'>1</td><td align='right'>2</td><td align='right'>3</td></tr>
<tr><td align='right'>4</td><td align='right'>5</td><td align='right'>6</td></tr>
<tr><td align='right'>7</td><td align='right'>8</td><td align='right'>9</td></tr>
</tbody>
</table>


#### <a name="rt_command">タイトル設定・デリミタ変更・ヘッダ表示:</a>

制御コマンドを記述することで、タイトル設定・デリミタの変更が 可能です。制御コマンドと表の記述部の間には、空行を１行入れる必要があります。

<strong>caption</strong>コマンドで表のタイトルを設定できます。 <strong>delimiter</strong>コマンドでデリミタの変更を行うことが出来ます。 デフォルトのデリミタは<strong>","</strong>か<strong>TAB</strong>です。

表の記述の途中に空行がある場合、それより上の部分をヘッダと見なします。 ヘッダ部分は HTML における THEAD 要素となり、TH タグで強調表示されます。

```text
 RT
  # コメント記述
  caption   = タイトル
  delimiter = : 

  AAA : BBB : CCC

    1 :   2 :   3
    4 :   5 :   6
 /RT
```


<table border='1'>
<caption><strong>タイトル</strong></caption>
<thead>
<tr><th align='center'>AAA</th><th align='center'>BBB</th><th align='center'>CCC</th></tr>
</thead>
<tbody><colgroup span='3'>

<tr><td align='right'>1</td><td align='right'>2</td><td align='right'>3</td></tr>
<tr><td align='right'>4</td><td align='right'>5</td><td align='right'>6</td></tr>
</tbody>
</table>


<br>
<br>

#### <a name="rt_complication">複雑な表の記述:</a>

スパン記号("||","==")で複雑な表も簡単に記述できます。 "||"記号でその場所のセルを上のセルと結合、"=="記号で左のセルと結合します。

```text
 RT
  caption   = ちょっと複雑な表
  delimiter = :
 
  A :  B :  C : == :  D :  E
 
  1 :  2 :  3 :  4 :  5 :  6
  7 : == : || :  8 : == :  9
 10 : 11 : 12 : || : == : 13
 /RT
```

<table border='1'>
<caption><strong>ちょっと複雑な表</strong></caption>
<thead>
<tr><th align='center'>A</th><th align='center'>B</th><th align='center' colspan='2'>C</th><th align='center'>D</th><th align='center'>E</th></tr>
</thead>
<tbody><colgroup span='6'>

<tr><td align='right'>1</td><td align='right'>2</td><td align='right' rowspan='2'>3</td><td align='right'>4</td><td align='right'>5</td><td align='right'>6</td></tr>
<tr><td align='right' colspan='2'>7</td><td align='right' colspan='2' rowspan='2'>8</td><td align='right'>9</td></tr>
<tr><td align='right'>10</td><td align='right'>11</td><td align='right'>12</td><td align='right'>13</td></tr>
</tbody>
</table>



#### <a name="rt_ornament">表の装飾:</a>

表を構成する各ブロック(下図参照)に対して、表示属性を指定可能です。 <br> なお、<strong>TBODY見出し部</strong> は、<strong>tindex_span</strong> の指定が無い場合には出力されません。

<div class='c1'>
<blockquote>
<table border='1' width='75%'>
<caption><strong>TABLE全体(table_foo)</strong></caption>
<thead>
<tr><th align='center' colspan='3'>THEAD部(thead_foo)</th></tr>
</thead>
<tbody>
<colgroup span='1' width='150'>
<colgroup span='3' width='200' align='center'>

<tr><th>TBODY部[見出し]<br>(tindex_foo)<br></th><td colspan='2'>TBODY部[本体]<br>(tbody_foo)<br></td></tr>
</tbody>
</table>
</blockquote>

</div>

<br>

使用できるコマンドは以下のとおりです。


<table border='2' bgcolor='white'>
<caption><strong>RT拡張コマンド</strong></caption>
<thead>
<tr><th align='center' colspan='3'>コマンド</th><th align='center'>機能</th></tr>
</thead>
<tbody><colgroup span='3'>
<colgroup span='4'>

<tr><th align='center' colspan='2' rowspan='8'>TABLE全体</th><th align='center'>caption</th><td align='left'>表の題名</td></tr>
<tr><th align='center'>delimiter</th><td align='left'>デリミタ</td></tr>
<tr><th align='center'>table_class</th><td align='left'>スタイルシート指定</td></tr>
<tr><th align='center'>table_border</th><td align='left'>枠線の幅(ピクセル)</td></tr>
<tr><th align='center'>table_width</th><td align='left'>テーブルの幅(ピクセルまたは%)</td></tr>
<tr><th align='center'>table_height</th><td align='left'>テーブルの高さ(ピクセルまたは%)</td></tr>
<tr><th align='center'>table_frame</th><td align='left'>外枠の表示方法 (void,above,below,hsides,vsides,lhs,rhs,box,border)</td></tr>
<tr><th align='center'>table_rules</th><td align='left'>内側罫線の表示方法 (none,groups,rows,cols,all)</td></tr>
<tr><th align='center' colspan='2' rowspan='2'>THEAD部</th><th align='center'>thead_class</th><td align='left'>スタイルシート指定</td></tr>
<tr><th align='center'>thead_bgcolor</th><td align='left'>BGCOLOR 指定</td></tr>
<tr><th align='center' rowspan='9'>TBODY部</th><th align='center' rowspan='5'>見出し</th><th align='center'>tindex_span</th><td align='left'>見出しとしてグループ化する列数(def=0)</td></tr>
<tr><th align='center'>tindex_class</th><td align='left'>スタイルシート指定</td></tr>
<tr><th align='center'>tindex_bgcolor</th><td align='left'>BGCOLOR 指定</td></tr>
<tr><th align='center'>tindex_width</th><td align='left'>セルの幅(ピクセル)</td></tr>
<tr><th align='center'>tindex_align</th><td align='left'>セル配置(left,center,right)</td></tr>
<tr><th align='center' rowspan='4'>本体</th><th align='center'>tbody_bgcolor</th><td align='left'>BGCOLOR 指定</td></tr>
<tr><th align='center'>tbody_class</th><td align='left'>スタイルシート指定</td></tr>
<tr><th align='center'>tbody_width</th><td align='left'>セルの幅(ピクセル)</td></tr>
<tr><th align='center'>tbody_align</th><td align='left'>セル配置(left,center,right)</td></tr>
</tbody>
</table>

<br>

上記の表の RT 記述は以下のようになっています。

```text
 RT
  caption       = RT拡張コマンド
  delimiter     = :
  tbody_bgcolor = white
  table_border  = 2
  tindex_span   = 3
 
  コマンド :  ==  :       ==      : 機能
 
  TABLE全体:  ==  : caption       : 表の題名
     ||    :  ==  : delimiter     : デリミタ
     ||    :  ==  : table_class   : スタイルシート指定
     ||    :  ==  : table_border  : 枠線の幅(ピクセル)
     ||    :  ==  : table_width   : テーブルの幅(ピクセルまたは%)
     ||    :  ==  : table_height  : テーブルの高さ(ピクセルまたは%)
     ||    :  ==  : table_frame   : 外枠の表示方法 (void,above,below,hsides,vsides,lhs,rhs,box,border)
     ||    :  ==  : table_rules   : 内側罫線の表示方法 (none,groups,rows,cols,all)
   THEAD部 :  ==  : thead_class   : スタイルシート指定
     ||    :  ==  : thead_bgcolor : BGCOLOR 指定
   TBODY部 :見出し: tindex_span   : 見出しとしてグループ化する列数(def=0)
     ||    :  ||  : tindex_class  : スタイルシート指定
     ||    :  ||  : tindex_bgcolor: BGCOLOR 指定
     ||    :  ||  : tindex_width  : セルの幅(ピクセル)
     ||    :  ||  : tindex_align  : セル配置(left,center,right)
     ||    : 本体 : tbody_bgcolor : BGCOLOR 指定
     ||    :  ||  : tbody_class   : スタイルシート指定
     ||    :  ||  : tbody_width   : セルの幅(ピクセル)
     ||    :  ||  : tbody_align   : セル配置(left,center,right)
 /RT
```

---

<div class="c1">
  <h3>ハイパー日記システム Version 2.20</h3>
</div>
<hr>

<p><a href="index-j.html">Index</a></p>
