#!/bin/bash
# ⚡ 盘中快报 - 11:30 上午收盘 / 13:00 午间扫描
# 内容：A股大盘 + 持仓板块实时涨跌 + 异常波动警报

DINGTALK_WEBHOOK="https://oapi.dingtalk.com/robot/send?access_token=6b95c03e2db1ddb0a764edbf4c66d05c3fb4d314d27e639b5c68a5c1bb360e2f"
HOUR=$(TZ='Asia/Shanghai' date '+%H')
TODAY=$(TZ='Asia/Shanghai' date '+%m月%d日 %H:%M')

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

# 板块ETF（电网、红利、半导体、黄金、白银）
DIANWANG=$(curl -s "https://qt.gtimg.cn/q=sz159611" 2>/dev/null)   # 电网ETF
HONGLI=$(curl -s "https://qt.gtimg.cn/q=sh512890" 2>/dev/null)     # 红利低波ETF
BANDAO=$(curl -s "https://qt.gtimg.cn/q=sz159915" 2>/dev/null)     # 创业板ETF（AI/科技代理）
GOLD_ETF=$(curl -s "https://qt.gtimg.cn/q=sh518880" 2>/dev/null)   # 黄金ETF
SILVER_LOF=$(curl -s "https://qt.gtimg.cn/q=sz161226" 2>/dev/null) # 白银LOF

DW_PRICE=$(parse_qt "$DIANWANG" 4); DW_CHG=$(parse_qt "$DIANWANG" 32)
HL_PRICE=$(parse_qt "$HONGLI" 4); HL_CHG=$(parse_qt "$HONGLI" 32)
BD_PRICE=$(parse_qt "$BANDAO" 4); BD_CHG=$(parse_qt "$BANDAO" 32)
GD_PRICE=$(parse_qt "$GOLD_ETF" 4); GD_CHG=$(parse_qt "$GOLD_ETF" 32)
SV_PRICE=$(parse_qt "$SILVER_LOF" 4); SV_CHG=$(parse_qt "$SILVER_LOF" 32)

# 默认值
SH_PRICE=${SH_PRICE:-"--"}; SH_CHG=${SH_CHG:-"--"}
SZ_PRICE=${SZ_PRICE:-"--"}; SZ_CHG=${SZ_CHG:-"--"}
CY_PRICE=${CY_PRICE:-"--"}; CY_CHG=${CY_CHG:-"--"}
DW_CHG=${DW_CHG:-"--"}; HL_CHG=${HL_CHG:-"--"}; BD_CHG=${BD_CHG:-"--"}
GD_CHG=${GD_CHG:-"--"}; SV_CHG=${SV_CHG:-"--"}

# ========== 异常波动检测 ==========
ALERTS=""
check_alert() {
  local name="$1" chg="$2" threshold="$3"
  if [ "$chg" != "--" ] && [ -n "$chg" ]; then
    local val=$(echo "$chg" | sed 's/[^0-9.-]//g')
    if [ -n "$val" ]; then
      local abs_val=$(echo "$val" | sed 's/-//')
      if (( $(echo "$abs_val > $threshold" | bc -l 2>/dev/null || echo 0) )); then
        local dir="📈"
        if (( $(echo "$val < 0" | bc -l 2>/dev/null || echo 0) )); then dir="📉"; fi
        ALERTS+="- ${dir} **${name}**：${chg}%（超${threshold}%阈值）\n"
      fi
    fi
  fi
}

check_alert "电网ETF" "$DW_CHG" 2
check_alert "红利低波ETF" "$HL_CHG" 2
check_alert "创业板ETF" "$BD_CHG" 2
check_alert "黄金ETF" "$GD_CHG" 1.5
check_alert "白银LOF" "$SV_CHG" 2

# ========== 时段判断 ==========
if [ "$HOUR" -lt 12 ]; then
  PERIOD="上午收盘"
  NEXT="下午展望"
else
  PERIOD="午间扫描"
  NEXT="下午关注"
fi

# ========== 组装快报 ==========
REPORT="## ⚡ ${TODAY} ${PERIOD}快报\n\n"
REPORT+="---\n\n"

REPORT+="### 📊 大盘\n"
REPORT+="- 上证：**${SH_PRICE}**（${SH_CHG}%）\n"
REPORT+="- 深证：**${SZ_PRICE}**（${SZ_CHG}%）\n"
REPORT+="- 创业板：**${CY_PRICE}**（${CY_CHG}%）\n\n"

REPORT+="### 💰 你的持仓板块\n"
REPORT+="- ⚡ 电网ETF：**${DW_CHG}%**\n"
REPORT+="- 🏦 红利低波ETF：**${HL_CHG}%**\n"
REPORT+="- 🔵 创业板(AI/科技)：**${BD_CHG}%**\n"
REPORT+="- 🏅 黄金ETF：**${GD_CHG}%**\n"
REPORT+="- 🥈 白银LOF：**${SV_CHG}%**\n\n"

if [ -n "$ALERTS" ]; then
  REPORT+="### 🚨 异常波动警报\n"
  REPORT+="$ALERTS\n"
fi

REPORT+="### 🔮 ${NEXT}\n"
# 根据上午走势给下午预判
DW_VAL=$(echo "$DW_CHG" | sed 's/[^0-9.-]//g' 2>/dev/null)
BD_VAL=$(echo "$BD_CHG" | sed 's/[^0-9.-]//g' 2>/dev/null)

if [ -n "$DW_VAL" ] && (( $(echo "$DW_VAL > 1" | bc -l 2>/dev/null || echo 0) )); then
  REPORT+="- ⚡ 电网强势，关注下午能否延续\n"
elif [ -n "$DW_VAL" ] && (( $(echo "$DW_VAL < -1" | bc -l 2>/dev/null || echo 0) )); then
  REPORT+="- ⚡ 电网回调，观察是否为加仓机会\n"
fi

if [ -n "$BD_VAL" ] && (( $(echo "$BD_VAL < -2" | bc -l 2>/dev/null || echo 0) )); then
  REPORT+="- 🔵 AI链大幅调整，关注超跌反弹可能\n"
fi

REPORT+="- 🏦 红利低波：防御属性，波动小，耐心持有\n\n"

REPORT+="> ⚠️ 以上内容由AI基于公开信息生成，仅供参考，不构成投资建议。\n"
REPORT+="> 📊 看板：[点击查看](https://779179430-rgb.github.io/portfolio-dashboard/)"

send_msg "⚡ ${TODAY} ${PERIOD}快报" "$REPORT"
echo "✅ ${PERIOD}快报已推送"
