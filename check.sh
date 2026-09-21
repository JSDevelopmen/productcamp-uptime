#!/usr/bin/env bash
# External uptime check for anketapc2026.ru, run by .github/workflows/uptime.yml.
# Complements the on-server watchdog: this one notices when the whole VPS, DNS or network is gone.
# State lives in state/status ("ok" or "fail <since> <last_alert>"), carried between runs by actions/cache.
set -uo pipefail
NOW=$(date +%s)
REPEAT_SECONDS=3600
mkdir -p state
prev=$(cat state/status 2>/dev/null || echo ok)

fails=()
check() { # url expected_substring
  local out code body
  out=$(curl -sL -m 15 -w '\n%{http_code}' "$1" 2>/dev/null)
  code=$(printf '%s' "$out" | tail -1); body=$(printf '%s' "$out" | sed '$d')
  echo "$code $1"
  if [ "$code" != 200 ]; then fails+=("$1 → HTTP ${code:-нет ответа}")
  elif [[ $body != *"$2"* ]]; then fails+=("$1 → 200, но нет «$2»"); fi
}
check https://anketapc2026.ru/api/healthz '"ok":true'
check https://anketapc2026.ru/ 'ProductCamp'
check https://www.anketapc2026.ru/ 'ProductCamp'

send() {
  [ -z "${TG_BOT_TOKEN:-}" ] && { echo "TG_BOT_TOKEN not set"; return; }
  # Token passed via stdin config so it never appears in argv or the log.
  local code
  code=$(printf 'url = "https://api.telegram.org/bot%s/sendMessage"\n' "$TG_BOT_TOKEN" |
    curl -s -m 15 -o /dev/null -w '%{http_code}' -K - \
      --data-urlencode "chat_id=$TG_CHAT_ID" --data-urlencode "text=$1" -d disable_web_page_preview=true)
  echo "telegram: HTTP $code"
}

if [ ${#fails[@]} -eq 0 ]; then
  if [ "${prev%% *}" = fail ]; then
    since=$(echo "$prev" | cut -d' ' -f2)
    send "✅ anketapc2026.ru снова доступна снаружи (лежала ~$(( (NOW - since) / 60 )) мин)"
  fi
  echo ok > state/status
else
  msg="🚨 anketapc2026.ru недоступна снаружи (GitHub Actions):"$'\n'"$(printf '• %s\n' "${fails[@]}")"
  if [ "${prev%% *}" = fail ]; then
    since=$(echo "$prev" | cut -d' ' -f2); last=$(echo "$prev" | cut -d' ' -f3)
    if (( NOW - last >= REPEAT_SECONDS )); then
      send "$msg"$'\n'"Лежит уже $(( (NOW - since) / 60 )) мин."; last=$NOW
    fi
  else
    since=$NOW; last=$NOW; send "$msg"
  fi
  echo "fail $since $last" > state/status
fi
