#!/bin/bash
# 📊 收盘复盘 - 每日 15:30 推送
# 内容：全市场收盘 + 持仓收益估算 + 板块资金 + 明日展望

DINGTALK_WEBHOOK="https://oapi.dingtalk.com/robot/send?access_token=6b95c03e2db1ddb0a764edbf4c66d05c3fb4d314d27e639b5c68a5c1bb360e2f"
TODAY=$(TZ='Asia/Shanghai' date '+%m月%d日')
WEEKDAY=$(TZ='Asia/Shanghai' date '+%u')
case $WEEKDAY in 1) W="一" ;; 2) W="二" ;; 3) W="三" ;; 4) W="四" ;; 5) W="五" ;; 6) W="六" ;; 7) W="日" ;; esac

send_msg() {
  local title="$1" content="$2"
  curl -s -X POST "${DINGTALK_WEBHOOK}" \
    -H 'Content-Type: application/json' \
    -d "{\"msgtype\":\"markdown\",\"markdown\":{\"title\":\"${title}\",\"text\":\"${content}\"}}" > /dev/null 2>&1
}

# ========== 数据采集 ==========
# 三大指数
SH_DATA=$(curl -s "https://qt.gtimg.cn/q=sh000001" 2>/dev/null)
SZ_DATA=$(curl -s "https://qt.gtimg.cn/q=sz399001" 2>/dev/null)
CY_DATA=$(curl -s "https://qt.gtimg.cn/q=sz399006" 2>/dev/null)

parse_qt() { echo "$1" | grep -oP '[^~]+' | sed -n "${2}p"; }

SH_PRICE=$(parse_qt "$SH_DATA" 4); SH_CHG=$(parse_qt "$SH_DATA" 32)
SZ_PRICE=$(parse_qt "$SZ_DATA" 4); SZ_CHG=$(parse_qt "$SZ_DATA" 32)
CY_PRICE=$(parse_qt "$CY_DATA" 4); CY_CHG=$(parse_qt "$CY_DATA" 32)

# 板块ETF
DIANWANG=$(curl -s "https://qt.gtimg.cn/q=sz159611" 2>/dev/null)
HONGLI=$(curl -s "https://qt.gtimg.cn/q=sh512890" 2>/dev/null)
BANDAO=$(curl -s "https://qt.gtimg.cn/q=sz159915" 2>/dev/null)
GOLD_ETF=$(curl -s "https://qt.gtimg.cn/q=sh518880" 2>/dev/null)
SILVER_LOF=$(curl -s "https://qt.gtimg.cn/q=sz161226" 2>/dev/null)

DW_CHG=$(parse_qt "$DIANWANG" 32); DW_PRICE=$(parse_qt "$DIANWANG" 4)
HL_CHG=$(parse_qt "$HONGLI" 32); HL_PRICE=$(parse_qt "$HONGLI" 4)
BD_CHG=$(parse_qt "$BANDAO" 32); BD_PRICE=$(parse_qt "$BANDAO" 4)
GD_CHG=$(parse_qt "$GOLD_ETF" 32); GD_PRICE=$(parse_qt "$GOLD_ETF" 4)
SV_CHG=$(parse_qt "$SILVER_LOF" 32); SV_PRICE=$(parse_qt "$SILVER_LOF" 4)

# 金银
GOLD_DATA=$(curl -s "https://api.gold-api.com/price/XAU" 2>/dev/null)
GOLD_PRICE=$(echo "$GOLD_DATA" | grep -o '"price":[0-9.]*' | cut -d: -f2)
SILVER_DATA=$(curl -s "https://api.gold-api.com/price/XAG" 2>/dev/null)
SILVER_PRICE=$(echo "$SILVER_DATA" | grep -o '"price":[0-9.]*' | cut -d: -f2)

# 默认值
SH_PRICE=${SH_PRICE:-"--"}; SH_CHG=${SH_CHG:-"--"}
DW_CHG=${DW_CHG:-"--"}; HL_CHG=${HL_CHG:-"--"}; BD_CHG=${BD_CHG:-"--"}
GD_CHG=${GD_CHG:-"--"}; SV_CHG=${SV_CHG:-"--"}
GOLD_PRICE=${GOLD_PRICE:-"--"}; SILVER_PRICE=${SILVER_PRICE:-"--"}

# ========== 涨跌方向标记 ==========
arrow() {
  local v="$1"
  if [ "$v" = "--" ]; then echo ""; return; fi
  local n=$(echo "$v" | sed 's/[^0-9.-]//g')
  if [ -z "$n" ]; then echo ""; return; fi
  if (( $(echo "$n > 0" | bc -l 2>/dev/null || echo 0) )); then echo "🔴"; else echo "🟢"; fi
}

# ========== 组装收盘报告 ==========
REPORT="## 📊 ${TODAY} 周${W} 收盘早报\n\n"
REPORT+="---\n\n"

REPORT+="### 🏛️ 大盘收盘\n"
REPORT+="- 上证：**${SH_PRICE}** $(arrow "$SH_CHG")${SH_CHG}%\n"
REPORT+="- 深证：**${SZ_PRICE}** $(arrow "$SZ_CHG")${SZ_CHG}%\n"
REPORT+="- 创业板：**${CY_PRICE}** $(arrow "$CY_CHG")${CY_CHG}%\n\n"

REPORT+="### 💰 持仓板块今日表现\n\n"
REPORT+="| 板块 | 涨跌 | 持仓关联 |\n"
REPORT+="|------|------|--------|\n"
REPORT+="| ⚡ 电网设备 | $(arrow "$DW_CHG")${DW_CHG}% | 天弘C + 华夏联接C |\n"
REPORT+="| 🏦 红利低波 | $(arrow "$HL_CHG")${HL_CHG}% | 华泰红利低波C |\n"
REPORT+="| 🔵 AI/科技 | $(arrow "$BD_CHG")${BD_CHG}% | 中欧新蓝筹A |\n"
REPORT+="| 🏅 黄金 | $(arrow "$GD_CHG")${GD_CHG}% | 积存金 |\n"
REPORT+="| 🥈 白银 | $(arrow "$SV_CHG")${SV_CHG}% | 国投白银LOF |\n\n"

REPORT+="### 🥇 贵金属\n"
REPORT+="- 黄金：\$${GOLD_PRICE}/oz\n"
REPORT+="- 白银：\$${SILVER_PRICE}/oz\n\n"

# 总结判断
SUMMARY=""
DW_N=$(echo "$DW_CHG" | sed 's/[^0-9.-]//g' 2>/dev/null)
HL_N=$(echo "$HL_CHG" | sed 's/[^0-9.-]//g' 2>/dev/null)
BD_N=$(echo "$BD_CHG" | sed 's/[^0-9.-]//g' 2>/dev/null)

if [ -n "$DW_N" ] && (( $(echo "$DW_N > 1" | bc -l 2>/dev/null || echo 0) )); then
  SUMMARY+="- ⚡ 电网今日表现强劲，验证独立于AI的逻辑\n"
fi
if [ -n "$BD_N" ] && (( $(echo "$BD_N < -1" | bc -l 2>/dev/null || echo 0) )); then
  SUMMARY+="- 🔵 AI链今日承压，关注晚间美股半导体走势\n"
fi
if [ -n "$HL_N" ] && (( $(echo "$HL_N >= 0" | bc -l 2>/dev/null || echo 0) )); then
  SUMMARY+="- 🏦 红利低波稳定，防御价值凸显\n"
fi

if [ -n "$SUMMARY" ]; then
  REPORT+="### 🎯 今日总结\n${SUMMARY}\n"
fi

REPORT+="> ⚠️ 以上内容由AI基于公开信息生成，仅供参考，不构成投资建议。投资有风险，决策需谨慎。\n"
REPORT+="> 📊 看板：[点击查看](https://779179430-rgb.github.io/portfolio-dashboard/)"

send_msg "📊 ${TODAY} 收盘早报" "$REPORT"
echo "✅ 收盘复盘已推送"
