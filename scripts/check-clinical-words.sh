#!/usr/bin/env bash
# 临床措辞合规扫描（架构文档 §10）。
# 产品定位「陪伴」，UI 文案与 agent 提示词严禁出现临床/医疗措辞。
# 命中任一禁用词即失败退出。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# 禁用词 —— 临床/医疗语义。
FORBIDDEN='治疗|诊断|评估|改善症状|疗效|症状|病情|医疗建议|心理咨询|抑郁|焦虑症'

# 扫描范围：App 端 UI 文案、agent 提示词、隐私说明。
TARGETS=(
  "$ROOT/voxule/voxule"
  "$ROOT/VoxlueKit/Sources/VoxlueServices"
  "$ROOT/backend/agent-proxy/src"
)

hits=0
for dir in "${TARGETS[@]}"; do
  [ -d "$dir" ] || continue
  if grep -rnE "$FORBIDDEN" "$dir" --include='*.swift' --include='*.ts' \
       --include='*.strings' 2>/dev/null; then
    hits=1
  fi
done

if [ "$hits" -ne 0 ]; then
  echo "❌ 发现临床措辞 —— 产品定位「陪伴」，请改为非临床表达。"
  exit 1
fi
echo "✅ 未发现临床措辞，文案合规。"
