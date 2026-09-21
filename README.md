# productcamp-uptime

External uptime check for https://anketapc2026.ru — GitHub Actions every 10 minutes
(`.github/workflows/uptime.yml` → `check.sh`). Alerts go to Telegram once on failure, hourly while it
stays down, and once on recovery. Needs repository secrets `TG_BOT_TOKEN` and `TG_CHAT_ID`.

This repo is public on purpose (unlimited Actions minutes) and holds nothing but this script.
The deep checks (DB, deliveries, PM2, certs, API credit) run on the server: `scripts/watchdog.sh`
in the questionnaire repo.
