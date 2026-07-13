#!/usr/bin/env bash
# make_all_videos.sh — batch generate observer lecture videos
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
mkdir -p "${LOG_DIR}"

DECKS=(
  slides_01_observer_ui
  slides_02_observer_cli
)

VOICE="${VOICE:-zh-CN-YunjianNeural}"
SPEED="${SPEED:-1.3}"
MODE="${MODE:-edge}"

echo "=============================="
echo " Observer Video Batch Generator"
echo " Mode : ${MODE}"
echo " Voice: ${VOICE}"
echo " Speed: ${SPEED}x"
echo " Total: ${#DECKS[@]} decks"
echo "=============================="

FAILED=()
for deck in "${DECKS[@]}"; do
  deck_dir="${SCRIPT_DIR}/${deck}"
  log_file="${LOG_DIR}/${deck}.log"

  if [[ ! -d "${deck_dir}" ]]; then
    echo "[SKIP] ${deck} — directory not found"
    continue
  fi

  if [[ -f "${deck_dir}/final.mp4" ]]; then
    echo "[SKIP] ${deck} — final.mp4 already exists (delete to regenerate)"
    continue
  fi

  echo ""
  echo ">>> [$(date '+%H:%M:%S')] Processing: ${deck}"
  echo "    Log: ${log_file}"

  if bash "${SCRIPT_DIR}/dub_slide_video.sh" \
      --deck-dir "${deck_dir}" \
      --mode "${MODE}" \
      --voice "${VOICE}" \
      --speed "${SPEED}" \
      --output-name final.mp4 \
      > "${log_file}" 2>&1; then
    echo "    [OK] $(ls -lh "${deck_dir}/final.mp4" | awk '{print $5, $9}')"
  else
    echo "    [FAIL] See log: ${log_file}"
    FAILED+=("${deck}")
  fi
done

echo ""
echo "=============================="
echo " Done at $(date '+%H:%M:%S')"
if [[ ${#FAILED[@]} -eq 0 ]]; then
  echo " All videos generated successfully!"
else
  echo " Failed decks:"
  for f in "${FAILED[@]}"; do
    echo "   - ${f}"
  done
fi
echo "=============================="
