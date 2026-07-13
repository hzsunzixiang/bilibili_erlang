#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="${SCRIPT_DIR}"
DEFAULT_CONVERTER_DIR="${SCRIPT_DIR}/text-to-ppt-to-video"
DEFAULT_DECK_DIR="${SCRIPT_DIR}/slides_01_observer_ui"
DEFAULT_PYTHON_BIN="/opt/homebrew/Caskroom/miniconda/base/envs/d2l_3.13/bin/python"

CONVERTER_DIR="${DEFAULT_CONVERTER_DIR}"
DECK_DIR="${DEFAULT_DECK_DIR}"
PYTHON_BIN="${DEFAULT_PYTHON_BIN}"
MODE="edge"
EDGE_VOICE="zh-CN-YunjianNeural"
EDGE_RATE="+0%"
QWEN_VOICE="Ethan"
SPEED="1.3"
OUTPUT_NAME="final.mp4"
SLIDES=""
FAST="0"
FORCE_AUDIO="0"
SKIP_VALIDATION="1"
KEEP_CONFIG="0"

usage() {
  cat <<'USAGE'
Usage:
  bash video/dub_slide_video.sh [options]

Required inputs are inferred by default:
  --deck-dir        Slide deck directory containing presentation.pdf and subtitles.md
                    Default: video/slides_01_observer_ui
  --converter-dir   text-to-ppt-to-video converter directory
                    Default: video/text-to-ppt-to-video

Common options:
  --mode edge|qwen          TTS mode. Default: edge
  --voice NAME             Voice name. For edge mode this is Edge voice; for qwen mode this is Qwen voice
  --speed FLOAT            Speech speed multiplier in converter config. Default: 1.3
  --edge-rate RATE         Edge TTS rate string. Default: +0%
  --output-name NAME       Output video filename copied into deck dir. Default: final.mp4
  --slides RANGE           Slide range passed to pipeline, for example 1-5 or 3
  --fast                   Use fast preview mode
  --force-audio            Regenerate audio even if audio files exist
  --with-validation        Enable STT validation instead of skipping it
  --keep-config            Keep config.json changes after the run
  --python PATH            Python executable used to run the pipeline
  -h, --help               Show this help

Examples:
  # Single episode
  bash video/dub_slide_video.sh \
    --deck-dir video/slides_01_observer_ui

  # Specify voice and speed
  bash video/dub_slide_video.sh \
    --deck-dir video/slides_02_observer_cli \
    --voice zh-CN-YunjianNeural \
    --speed 1.3

  # Quick preview (first 2 slides)
  bash video/dub_slide_video.sh \
    --deck-dir video/slides_01_observer_ui \
    --slides 1-2 \
    --fast \
    --output-name preview.mp4
USAGE
}

abspath() {
  local path="$1"
  if [[ "${path}" = /* ]]; then
    printf '%s\n' "${path}"
  else
    printf '%s\n' "${WORKSPACE_DIR}/${path}"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --deck-dir)
      DECK_DIR="$(abspath "$2")"
      shift 2
      ;;
    --converter-dir)
      CONVERTER_DIR="$(abspath "$2")"
      shift 2
      ;;
    --mode)
      MODE="$2"
      shift 2
      ;;
    --voice)
      EDGE_VOICE="$2"
      QWEN_VOICE="$2"
      shift 2
      ;;
    --edge-voice)
      EDGE_VOICE="$2"
      shift 2
      ;;
    --qwen-voice)
      QWEN_VOICE="$2"
      shift 2
      ;;
    --speed)
      SPEED="$2"
      shift 2
      ;;
    --edge-rate)
      EDGE_RATE="$2"
      shift 2
      ;;
    --output-name)
      OUTPUT_NAME="$2"
      shift 2
      ;;
    --slides)
      SLIDES="$2"
      shift 2
      ;;
    --fast)
      FAST="1"
      shift
      ;;
    --force-audio)
      FORCE_AUDIO="1"
      shift
      ;;
    --with-validation)
      SKIP_VALIDATION="0"
      shift
      ;;
    --keep-config)
      KEEP_CONFIG="1"
      shift
      ;;
    --python)
      PYTHON_BIN="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ "${MODE}" != "edge" && "${MODE}" != "qwen" ]]; then
  echo "--mode must be edge or qwen" >&2
  exit 2
fi

if [[ ! "${SPEED}" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  echo "--speed must be a positive number, got: ${SPEED}" >&2
  exit 2
fi

PRESENTATION_PDF="${DECK_DIR}/presentation.pdf"
SUBTITLES_MD="${DECK_DIR}/subtitles.md"
CONFIG_JSON="${CONVERTER_DIR}/config.json"
SLIDES_DIR="${CONVERTER_DIR}/slides"
OUTPUT_VIDEO_DIR="${CONVERTER_DIR}/output/video"
OUTPUT_VIDEO="${OUTPUT_VIDEO_DIR}/final.mp4"
DEST_VIDEO="${DECK_DIR}/${OUTPUT_NAME}"
CONFIG_BACKUP="${CONFIG_JSON}.bak.$(date +%Y%m%d%H%M%S)"

for required_path in "${CONVERTER_DIR}" "${SLIDES_DIR}" "${CONFIG_JSON}" "${PRESENTATION_PDF}" "${SUBTITLES_MD}" "${PYTHON_BIN}"; do
  if [[ ! -e "${required_path}" ]]; then
    echo "Required path not found: ${required_path}" >&2
    exit 1
  fi
done

restore_config() {
  if [[ "${KEEP_CONFIG}" != "1" && -f "${CONFIG_BACKUP}" ]]; then
    mv "${CONFIG_BACKUP}" "${CONFIG_JSON}"
  fi
}
trap restore_config EXIT

cp "${CONFIG_JSON}" "${CONFIG_BACKUP}"

"${PYTHON_BIN}" - "${CONFIG_JSON}" "${QWEN_VOICE}" "${SPEED}" "${EDGE_VOICE}" "${EDGE_RATE}" <<'PY'
import json
import sys
from pathlib import Path

config_path = Path(sys.argv[1])
qwen_voice = sys.argv[2]
speed = float(sys.argv[3])
edge_voice = sys.argv[4]
edge_rate = sys.argv[5]

config = json.loads(config_path.read_text(encoding="utf-8"))
config.setdefault("tts", {})["voice_name"] = qwen_voice
config.setdefault("tts", {})["speech_speed"] = speed
config.setdefault("edge_tts", {})["voice"] = edge_voice
config.setdefault("edge_tts", {})["rate"] = edge_rate
config_path.write_text(json.dumps(config, ensure_ascii=False, indent=4) + "\n", encoding="utf-8")
PY

make -C "${CONVERTER_DIR}" distclean

rm -f "${SLIDES_DIR}/presentation.tex" "${SLIDES_DIR}/presentation.pdf" "${SLIDES_DIR}/subtitles.md"

cp "${PRESENTATION_PDF}" "${SLIDES_DIR}/presentation.pdf"
cp "${SUBTITLES_MD}" "${SLIDES_DIR}/subtitles.md"

pipeline_args=("scripts/pipeline.py")
if [[ "${MODE}" == "edge" ]]; then
  pipeline_args+=("--tts-edge" "--edge-voice" "${EDGE_VOICE}" "--edge-rate" "${EDGE_RATE}")
fi
if [[ "${SKIP_VALIDATION}" == "1" ]]; then
  pipeline_args+=("--skip-validation")
fi
if [[ "${FAST}" == "1" ]]; then
  pipeline_args+=("--fast")
fi
if [[ "${FORCE_AUDIO}" == "1" ]]; then
  pipeline_args+=("--force-audio")
fi
if [[ -n "${SLIDES}" ]]; then
  pipeline_args+=("--slides" "${SLIDES}")
fi

(
  cd "${CONVERTER_DIR}"
  "${PYTHON_BIN}" "${pipeline_args[@]}"
)

if [[ ! -f "${OUTPUT_VIDEO}" ]]; then
  echo "Pipeline finished, but final video was not found: ${OUTPUT_VIDEO}" >&2
  exit 1
fi

find "${OUTPUT_VIDEO_DIR}" -maxdepth 1 -type f -name '*.mp4' -exec cp {} "${DECK_DIR}/" \;
if [[ "${OUTPUT_NAME}" != "final.mp4" ]]; then
  cp "${OUTPUT_VIDEO}" "${DEST_VIDEO}"
fi
ls -lh "${DEST_VIDEO}"

echo "Dubbing video generated: ${DEST_VIDEO}"
echo "Related MP4 files copied to: ${DECK_DIR}"
