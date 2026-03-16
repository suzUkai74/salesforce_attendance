# salesforce_attendance

Salesforce の勤怠入力を自動化する Ruby スクリプトです。Selenium WebDriver を使用して、指定した出退勤時刻を先月（または指定月）の全営業日に一括入力します。

## 必要環境

- Ruby
- Google Chrome
- ChromeDriver（Chrome のバージョンに合ったもの）

## セットアップ

### 1. 依存 gem のインストール

```bash
bundle install
```

### 2. 設定ファイルの作成

`config.yml.sample` をコピーして `config.yml` を作成し、各項目を編集します。

```bash
cp config.yml.sample config.yml
```

### 設定項目

| キー | 説明 | 例 |
|------|------|----|
| `username` | Salesforce のログインユーザー名 | `user@example.com` |
| `password` | Salesforce のログインパスワード | `password123` |
| `start_time` | 出勤時刻 | `'10:00'` |
| `end_time` | 退勤時刻 | `'19:00'` |
| `chrome_profile` | Chrome プロファイルのパス（省略時: `./chrome_profile`） | `./chrome_profile` |
| `login_url` | Salesforce のログイン URL | `https://login.salesforce.com` |

## 実行方法

### 先月分を入力（デフォルト）

```bash
ruby input_attendance.rb
```

### 特定の月を指定して入力

引数に対象月の任意の日付を渡します。

```bash
ruby input_attendance.rb 2025-12-01
```

## 動作の流れ

1. Chrome を起動し、Salesforce にログイン
2. 勤怠入力ページへ遷移
3. 対象月の各日付について：
   - 営業日（勤怠入力欄がある日）のみ処理
   - ダイアログを開き、出勤・退勤時刻を入力して送信
   - 確認ダイアログが表示された場合は自動で承認
4. 結果を標準出力に表示（`日付:Success` / `日付:Failure` / `日付:Holiday`）
