#!/usr/bin/env bash
#
# download_edge_functions.sh
#
# Массово скачивает исходный код всех Edge Functions проекта
# через Supabase CLI и сохраняет их в supabase/functions/<name>/index.ts
#
# Требования:
#   - установлен Supabase CLI (brew install supabase/tap/supabase)
#   - выполнен `supabase login`
#   - выполнен `supabase link --project-ref <ref>` в текущей папке
#     (или передайте PROJECT_REF ниже и скрипт сам это сделает)
#
# Использование:
#   chmod +x download_edge_functions.sh
#   ./download_edge_functions.sh
#

set -euo pipefail

# --- Настройки ---------------------------------------------------------
PROJECT_REF="vueumbnmjmxoppddblrr"
OUTPUT_LOG="edge_functions_download_log.txt"

# Список функций, извлечённый из EDGE_FUNCTIONS.txt
FUNCTIONS=(
  "block-consumer"
  "booking-listener"
  "callback-handler"
  "create-client-user"
  "daily_reminder"
  "deepseek-gen-wp-for-tg-client"
  "deepseek-generate-workout-plan"
  "eight-h-reminder-w-confirm"
  "fatsecret-auth"
  "generate-exercise-descriptions"
  "generate-workout-plan"
  "notification-monitor"
  "notification-worker"
  "nutrition-report"
  "parse-workout-plan"
  "receipt-handler"
  "retention-bot"
  "retention-checkin-sender"
  "retention-progress-report"
  "retention-signal-checker"
  "send-push-notification"
  "subscription-expiry-checker"
  "support-request"
  "tg-booking-webhook"
  "upload-receipt"
)

# --- Проверки ------------------------------------------------------------
if ! command -v supabase &> /dev/null; then
  echo "❌ Supabase CLI не найден. Установите: brew install supabase/tap/supabase"
  exit 1
fi

if [ ! -d "supabase" ]; then
  echo "⚠️  Папка supabase/ не найдена. Инициализирую проект..."
  supabase init
fi

# Проверяем линковку; если не слинковано — линкуем
if [ ! -f "supabase/.temp/project-ref" ]; then
  echo "🔗 Проект не слинкован. Линкую с $PROJECT_REF ..."
  supabase link --project-ref "$PROJECT_REF"
fi

# --- Скачивание ------------------------------------------------------------
echo "📥 Начинаю скачивание ${#FUNCTIONS[@]} функций..." | tee "$OUTPUT_LOG"
echo "==============================================" | tee -a "$OUTPUT_LOG"

SUCCESS=0
FAILED=0
FAILED_LIST=()

for fn in "${FUNCTIONS[@]}"; do
  echo -n "→ $fn ... "
  if supabase functions download "$fn" >> "$OUTPUT_LOG" 2>&1; then
    echo "✅ OK"
    SUCCESS=$((SUCCESS + 1))
  else
    echo "❌ FAILED"
    FAILED=$((FAILED + 1))
    FAILED_LIST+=("$fn")
  fi
done

echo "==============================================" | tee -a "$OUTPUT_LOG"
echo "Готово: $SUCCESS успешно, $FAILED с ошибкой." | tee -a "$OUTPUT_LOG"

if [ ${#FAILED_LIST[@]} -gt 0 ]; then
  echo "Не удалось скачать:" | tee -a "$OUTPUT_LOG"
  for fn in "${FAILED_LIST[@]}"; do
    echo "  - $fn" | tee -a "$OUTPUT_LOG"
  done
  echo ""
  echo "Возможные причины: функция была удалена/переименована на сервере,"
  echo "либо недостаточно прав токена. Проверьте supabase functions list."
fi

echo ""
echo "Код функций находится в supabase/functions/<имя>/index.ts"
echo "Полный лог: $OUTPUT_LOG"
