# hnsReborn (Hyper Nikki System Reborn)

日記システム「Hyper Nikki System (HNS)」の書式形式であるHNFを、現代的な技術スタックで表示させることを目的としたソフトです。
バックエンドに Ruby (Sinatra)、フロントエンドに Vue.js (Vue 3) を採用し、SPA (Single Page Application) で実現しています。

## 特徴 (Features)

* **HNF形式の表示**: 既存のHNFファイルをそのままパースして表示可能です。
    * 対応していない形式があったら自分で実装してください。
    * 書式は[./hnf-j.md](./hnf-j.md)を参照してください。
* **モダンなUI**: Vue.js 3 によるリアクティブなフロントエンド。カレンダー遷移や検索がスムーズです。
* **高速な全文検索**: 過去の日記データをインクリメンタルに検索できます。
    * Ruby + SQLite3にる検索です。
* **パーマリンク対応**:
    * 日付リンク: `/#YYYYMMDD`
    * 範囲指定: `/#YYYYMMDD#YYYYMMDD`
    * カテゴリ: `/@カテゴリ名`
    * n年日記: `/#nMMDD`
* **Google/Outlookカレンダー同期**: iCal形式のURLから予定を取り込み、**hnsReborn**上で統合表示できます。
* **柔軟なPIM (予定管理)**:
    * 繰り返し予定、範囲指定、第n曜日指定などの高度な記述に対応。
    * Googleカレンダーの予定ごとに色やスタイルを指定可能。
    * RURIコード (読者コード) に基づいた予定の閲覧制限機能。
    * TODOリスト、リンク集機能を搭載。
* **ハイブリッドな動作環境**:
    * ローカル環境 (Puma/Rack)
    * レンタルサーバー (CGI)(xrea.com(無料サーバー)で動作確認)
* **認証システム**: RURIコードによる簡易認証で、プライベートな日記運用も可能です。
* **日記作成機能**:
    * 簡易ではあるが搭載している。しかし、テストが不十分。
	* 基本は、サーバーの日記ディレクトリにコピーする。(scp/ftp/rsync)

## 必要要件 (Requirements)

* Ruby 3.2 以上推奨
* SQLite3

## セットアップ (Installation)

### 1. リポジトリのクローン
```bash
git clone https://github.com/your-username/hnsReborn.git
cd hnsReborn
```

### 2. ライブラリのインストール
プロジェクト配下に閉じてインストールすることを推奨します。

```bash
bundle config set --local path 'vendor/bundle'
bundle install
```

### 3. 設定ファイルの準備
`config.sample.yml` をコピーして `config.yml` を作成し、環境に合わせて編集してください。

```bash
cp config.sample.yml config.yml
# 必要に応じて vi config.yml などで編集 (パス設定やテーマ指定など)
```

---

## Googleカレンダー連携の設定 (Google Calendar Integration)

`config.yml` にカレンダーのURLや表示スタイルを定義することで、Googleカレンダーの予定を取り込むことができます。

### 1. config.yml の設定
Googleカレンダーの「設定」→「カレンダーの統合」から **「iCal形式の非公開URL」** を取得し、以下のように記述します。

```yaml
diary_root: "./data"

calendars:
  # 識別名 (自由につけてOK)
  private:
    url: "https://calendar.google.com/calendar/ical/example/private-xxx/basic.ics"
    style: "color: #d9534f; font-weight: bold;"  # CSSスタイル (赤太字)
    group: "family" # (任意) このグループ権限を持つRURIにのみ表示

  work:
    url: "https://calendar.google.com/calendar/ical/work/private-yyy/basic.ics"
    style: "color: #337ab7; background-color: #e6f2ff;" # (青文字+背景)
    # groupを指定しない場合、全員に表示されます
```

### 2. 同期スクリプトの実行
以下のコマンドを実行すると、カレンダーデータが取得され `diary/YYYY/yYYYY_識別名` として保存されます。
(cronなどで定期実行することを推奨します)

```bash
bundle exec ruby gcal_sync.rb
```

---

## 予定表の記述方法 (PIM Syntax)

手書きの予定は `diary/repeat` (繰り返し) や `diary/2026/y2026` (単発) に記述します。

### 対応フォーマット

| 記述例 | 意味 |
| :--- | :--- |
| `1/1 元旦` | 特定日 (毎年) |
| `2026/1/1 元旦` | 特定日 (その年のみ) |
| `10/2mon 体育の日` | 10月の第2月曜日 |
| `1/-1sun 1月最終日曜` | 1月の最終日曜日 |
| `e 月末処理` | 毎月末日 |
| `1/a 上旬の予定` | 1月上旬 (1日〜10日) |
| `[2026/8/1-2026/8/31] 夏休み` | 期間指定 |

---

## アクセス制御 (Access Control)

**RURIコード (Read User Resource Identifier)** と呼ばれるコードを用いて、日記や予定の閲覧制限を行えます。

1. **管理者ログイン**: `diary/conf/admin_pass.txt` にパスワードを設すると、設定画面で「管理者メニュー」が表示されます。
2. **グループ設定**: `diary/conf/group.txt` に以下のように記述します。
   ```text
   family: RURI_CODE_FOR_FAMILY
   friends: RURI_CODE_FOR_FRIENDS
   ```
   これにより、`config.yml` や日記ファイル内で `GRP family` と指定されたコンテンツは、そのRURIコードを持つユーザーだけが見られるようになります。

---

## 実行方法 (Local Usage)

以下のコマンドでサーバーを起動します。

```bash
bundle exec puma
```

ブラウザで `http://localhost:9292` にアクセスしてください。

---

## サーバーへのデプロイ (Deployment on XREA/CGI)

XREAなどのCGI環境で動作させる場合の手順です。

### 1. CGI用Gemのインストール
CGI環境では軽量化のため、PumaやWEBrickを除外した構成でインストールします。

* **deploy-xrea**: xrea.comに設置するサンプルコードです。

必要なファイルをUP-Loadしたら、以下を実行します。

```bash
# サーバー上で実行
bundle config set --local path 'vendor/bundle'
bundle install --gemfile=Gemfile.cgi
```

### 2. パーミッションの設定
CGIファイルとディレクトリに適切な権限を付与してください。

```bash
chmod 755 index.cgi
chmod 755 .
```

### 3. .htaccess の設定
`index.cgi` を介してアプリケーションを動作させるため、適切な `.htaccess` を設置してください（リポジトリ内のサンプル(dot.htaccess)を参照）。

## ディレクトリ構成

- `user/`
  - `diary/`: 日記保存ディレクトリ
    - `2001/`: 各年の日記を納めるディレクトリ
	  - `d20010328.hnf`: サンプル日記
	- `cache`: 日記のjsonファイルの保存ディレクトリ (実行すると作成される)
    - `conf/`: 設定ファイル保存ディレクトリ
	  - `admin_pass.txt`: 投稿用のパスワードを入れておく。permission: 600
	  - `auth_ruri.txt`: 管理者用RURIコードを入れておく。permission: 600
	  - `foot.txt`: 最下行に表示されるHTML
	  - `group.txt`: 閲覧グループを入れておく。permission: 600
	  - `head.txt`: 最上行に表示されるHTML
	- `link`: リンク集
	- `repeat`: 繰り返し予定表
	- `todo`: TODO集
	- `search.db`: 日記の全文検索用のデータベース (実行すると作成される)
  - `public_html`
    - `.htaccess`: アクセス制限
    - `app.rb`: アプリケーション本体 (Sinatra)
	- `hnf_parse.rb`: HNFファイルの解析ロジック
	- `public`: 静的ファイル角のディレクトリ
	  - `bootstrap.html` : Vue.jsテンプレート、サンプル

## ライセンス (License)

[MIT License](LICENSE)

---
*Powered by Hyper Nikki System Reborn Project*
