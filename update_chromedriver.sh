#!/usr/bin/env bash
#
# インストール済みの Google Chrome に合わせて ChromeDriver を更新する。
#
# Homebrew の chromedriver cask は Gatekeeper チェック不通過で無効化されており
# `brew upgrade` で更新できないため、Chrome for Testing から直接取得する運用。
#
# 配置ルール（既存運用に合わせる）:
#   - ~/.chromedrivers/<major>/chromedriver に実体を置く
#   - /opt/homebrew/bin/chromedriver から上記へシンボリックリンクを張る
#
set -euo pipefail

CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
LINK="/opt/homebrew/bin/chromedriver"
STORE="${HOME}/.chromedrivers"

# CPU アーキテクチャに応じたプラットフォーム名。
case "$(uname -m)" in
  arm64) PLATFORM="mac-arm64" ;;
  x86_64) PLATFORM="mac-x64" ;;
  *) echo "未対応のアーキテクチャ: $(uname -m)" >&2; exit 1 ;;
esac

# インストール済み Chrome のフルバージョンとメジャーバージョンを取得。
CHROME_VERSION="$("$CHROME" --version | grep -oE '[0-9]+(\.[0-9]+){3}')"
MAJOR="${CHROME_VERSION%%.*}"
echo "Chrome: ${CHROME_VERSION} (major ${MAJOR})"

# 既に一致する chromedriver が入っていれば何もしない。
if command -v chromedriver >/dev/null 2>&1; then
  CURRENT="$(chromedriver --version 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+){3}' | head -1 || true)"
  if [ "${CURRENT%%.*}" = "$MAJOR" ]; then
    echo "ChromeDriver ${CURRENT} は既にメジャーバージョンが一致しています。更新不要。"
    exit 0
  fi
fi

# Chrome for Testing から同一メジャーバージョンの最新ドライバ URL を解決。
echo "Chrome for Testing から ChromeDriver ${MAJOR} を検索中..."
read -r DRIVER_VERSION URL < <(
  curl -s "https://googlechromelabs.github.io/chrome-for-testing/known-good-versions-with-downloads.json" \
  | MAJOR="$MAJOR" PLATFORM="$PLATFORM" python3 -c '
import json, os, sys
major = os.environ["MAJOR"]
platform = os.environ["PLATFORM"]
data = json.load(sys.stdin)
best = None
for v in data["versions"]:
    if v["version"].split(".")[0] != major:
        continue
    for dl in v["downloads"].get("chromedriver", []):
        if dl["platform"] == platform:
            best = (v["version"], dl["url"])
if not best:
    sys.exit("メジャーバージョン %s のドライバが見つかりませんでした。" % major)
print(best[0], best[1])
'
)
echo "取得対象: ChromeDriver ${DRIVER_VERSION}"

# ダウンロード・展開・配置。
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
curl -sL "$URL" -o "${TMP}/cd.zip"
unzip -oq "${TMP}/cd.zip" -d "$TMP"

mkdir -p "${STORE}/${MAJOR}"
cp "${TMP}/chromedriver-${PLATFORM}/chromedriver" "${STORE}/${MAJOR}/chromedriver"
chmod +x "${STORE}/${MAJOR}/chromedriver"
xattr -d com.apple.quarantine "${STORE}/${MAJOR}/chromedriver" 2>/dev/null || true

# シンボリックリンクを張り替え。
mkdir -p "$(dirname "$LINK")"
ln -sfn "${STORE}/${MAJOR}/chromedriver" "$LINK"

hash -r 2>/dev/null || true
echo "完了: $(chromedriver --version)"
