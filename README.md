# salesforce_attendance

Salesforce の勤怠入力・経費精算を自動化する Ruby スクリプトです。Selenium WebDriver を使用します。

- `input_attendance.rb` … 指定した出退勤時刻を先月（または指定月）の全営業日に一括入力
- `input_expense.rb` … 交通費を締め期間（昨月21日〜今月20日）の対象曜日に一括入力
- `salesforce_session.rb` … 両者で共用するログイン処理

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
| `attendance` | 勤怠入力の設定（下記） | - |
| `expense` | 経費精算の設定（下記） | - |

#### `attendance.selectors` 配下（勤怠入力）

勤怠入力画面の要素をすべて id で指定します。

| キー | 対象要素 | 既定値 |
|------|----------|--------|
| `tab_link` | 勤怠タブのリンク | 環境ごとに異なる |
| `year_month_list` | 対象月のセレクト | `yearMonthList` |
| `shim` | 読み込み中のオーバーレイ | `shim` |
| `time_cell_prefix` | 日付ごとの入力欄 id の接頭辞（`+ 日付` で id になる） | `ttvTimeSt` |
| `dialog` | 時刻入力ダイアログ | `dijit_DialogUnderlay_0` |
| `start_time_input` / `end_time_input` | 出勤・退勤時刻の入力欄 | `startTime` / `endTime` |
| `time_ok` | 時刻入力の確定ボタン | `dlgInpTimeOk` |
| `confirm_button` | 確認ダイアログの OK | `confirmAlertOk` |

#### `expense` 配下（経費精算）

| キー | 説明 | 例 |
|------|------|----|
| `start_day` | 締め期間の開始日（昨月のこの日から） | `21` |
| `end_day` | 締め期間の終了日（今月のこの日まで） | `20` |
| `item` | 費用項目 | `'交通費'` |
| `from` | 経路の出発地 | `'東京'` |
| `to` | 経路の到着地 | `'品川'` |
| `weekdays` | 入力対象の曜日（0=日 … 6=土、既定は月水金） | `[1, 3, 5]` |
| `date_format` | 利用日欄に入力する書式 | `'%Y/%m/%d'` |
| `selectors` | 経費精算画面の要素指定（下記） | - |

金額は Salesforce 側の経路検索で自動算出されるため、スクリプトからは入力しません。

`selectors` は画面ごとに異なるため、実際の DOM に合わせて設定します。値を文字列で書くと `id` 指定、`css: .foo` のようにキー付きで書くとその方法で検索します。

| キー | 対象要素 | 既定値 |
|------|----------|--------|
| `tab_link` | 経費精算タブのリンク | 環境ごとに異なる |
| `form_area` | 経費精算の入力エリア（遷移完了の判定に使用） | `tsfFormArea` |
| `add_button` | 明細の追加ボタン | `css: #expApplyForm0 .png-add` |
| `dialog` | 入力ダイアログ | `dijit_Dialog_3` |
| `date_input` | 利用日の入力欄 | `DlgDetailDate` |
| `item` | 費目の select | `DlgDetailExpItem` |
| `from_input` / `to_input` | 経路の出発地・到着地 | `DlgExpDetailStFrom` / `DlgExpDetailStTo` |
| `round_trip_button` | 片道／往復の切り替えボタン | `css: .pp_btn_oneway` |
| `search_button` | 経路検索（自動計算）ボタン | `css: .pp_btn_ektsrch` |
| `loading` | ダイアログのローディング表示（消えるまで待機） | `css: .ts-dialog-loading` |
| `search_result_ok` | 検索結果の確定ボタン | `expSearchOk` |
| `continue_button` | 「続けて入力」ボタン | `css: .ts-edge-continue button` |
| `confirm_button` | 確認ダイアログの OK | `confirmAlertOk` |

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

### 経費精算（交通費）を入力

実行日を基準に、締め期間（既定は昨月21日〜今月20日）を対象に入力します。期間は config の `start_day` / `end_day` で調整します。

```bash
ruby input_expense.rb
```

## 動作の流れ

### 勤怠入力

1. Chrome を起動し、Salesforce にログイン
2. 勤怠入力ページへ遷移
3. 対象月の各日付について：
   - 営業日（勤怠入力欄がある日）のみ処理
   - ダイアログを開き、出勤・退勤時刻を入力して送信
   - 確認ダイアログが表示された場合は自動で承認
4. 結果を標準出力に表示（`日付:Success` / `日付:Failure` / `日付:Holiday`）

### 経費精算

1. Chrome を起動し、Salesforce にログイン
2. 経費精算ページへ遷移し、入力エリア（`form_area`）が表示されるまで待機
3. 明細の追加ボタンから入力ダイアログを開く
4. 昨月21日〜今月20日のうち対象曜日（既定は月・水・金）の各日について：
   - 利用日・費目（交通費）・経路（from/to）を入力
   - 往復に切り替えたうえで経路検索を実行し、ローディングが消えたら検索結果を確定して金額を反映させる
   - 「続けて入力」で次の日付へ進む（最終日の入力後はダイアログを閉じる）
5. 結果を標準出力に表示（`日付:Success` / `日付:Failure`）
