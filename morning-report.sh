#!/bin/bash
# 🌅 盘前早报 - 每日 9:00 推送
# 内容：美股收盘 + 贵金属 + 重大新闻 + 今日持仓关注

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
# 美股三大指数（腾讯接口）
US_IXIC=$(curl -s "https://qt.gtimg.cn/q=usIXIC" 2>/dev/null)
US_DJI=$(curl -s "https://qt.gtimg.cn/q=usDJI" 2>/dev/null)
US_SOX=$(curl -s "https://qt.gtimg.cn/q=usSOX" 2>/dev/null)   # 费城半导体
NVDA=$(curl -s "https://qt.gtimg.cn/q=usNVDA.OQ" 2>/dev/null)

# 解析腾讯行情（格式：name~price~change~changePct）
parse_qt() { echo "$1" | grep -oP '[^~]+' | sed -n "${2}p"; }

NAS_PRICE=$(parse_qt "$US_IXIC" 4)
NAS_CHG=$(parse_qt "$US_IXIC" 32)
DJI_PRICE=$(parse_qt "$US_DJI" 4)
DJI_CHG=$(parse_qt "$US_DJI" 32)
SOX_PRICE=$(parse_qt "$US_SOX" 4)
SOX_CHG=$(parse_qt "$US_SOX" 32)
NVDA_PRICE=$(parse_qt "$NVDA" 4)
NVDA_CHG=$(parse_qt "$NVDA" 32)

# 金银价格
GOLD_DATA=$(curl -s "https://api.gold-api.com/price/XAU" 2>/dev/null)
GOLD_PRICE=$(echo "$GOLD_DATA" | grep -o '"price":[0-9.]*' | cut -d: -f2)
GOLD_CHG=$(echo "$GOLD_DATA" | grep -o '"ch":[0-9.-]*' | cut -d: -f2)
SILVER_DATA=$(curl -s "https://api.gold-api.com/price/XAG" 2>/dev/null)
SILVER_PRICE=$(echo "$SILVER_DATA" | grep -o '"price":[0-9.]*' | cut -d: -f2)
SILVER_CHG=$(echo "$SILVER_DATA" | grep -o '"ch":[0-9.-]*' | cut -d: -f2)

# 默认值
NAS_PRICE=${NAS_PRICE:-"--"} ; NAS_CHG=${NAS_CHG:-"--"}
DJI_PRICE=${DJI_PRICE:-"--"} ; DJI_CHG=${DJI_CHG:-"--"}
SOX_CHG=${SOX_CHG:-"--"} ; NVDA_PRICE=${NVDA_PRICE:-"--"} ; NVDA_CHG=${NVDA_CHG:-"--"}
GOLD_PRICE=${GOLD_PRICE:-"--"} ; GOLD_CHG=${GOLD_CHG:-"--"}
SILVER_PRICE=${SILVER_PRICE:-"--"} ; SILVER_CHG=${SILVER_CHG:-"--"}

# 费城半导体影响判断
SOX_DIR="中性"
if [ "$SOX_CHG" != "--" ]; then
  SOX_VAL=$(echo "$SOX_CHG" | sed 's/[^0-9.-]//g')
  if [ -n "$SOX_VAL" ]; then
    if (( $(echo "$SOX_VAL > 2" | bc -l 2>/dev/null || echo 0) )); then SOX_DIR="🔥 大涨"
    elif (( $(echo "$SOX_VAL > 0" | bc -l 2>/dev/null || echo 0) )); then SOX_DIR="🟢 小涨"
    elif (( $(echo "$SOX_VAL < -3" | bc -l 2>/dev/null || echo 0) )); then SOX_DIR="⚠️ 暴跌"
    elif (( $(echo "$SOX_VAL < 0" | bc -l 2>/dev/null || echo 0) )); then SOX_DIR="🔻 小跌"
    fi
  fi
fi

# ========== 组装早报 ==========
REPORT="## 🌅 ${TODAY} 周${W} 盘前早报\n\n"
REPORT+="---\n\n"

REPORT+="### 🇺🇸 美股收盘\n"
REPORT+="- 纳斯达克：**${NAS_PRICE}** （${NAS_CHG}%）\n"
REPORT+="- 道琼斯：**${DJI_PRICE}** （${DJI_CHG}%）\n"
REPORT+="- 费城半导体：${SOX_DIR}（${SOX_CHG}%）\n"
REPORT+="- 英伟达：**\$${NVDA_PRICE}** （${NVDA_CHG}%）\n\n"

REPORT+="### 🥇 贵金属\n"
REPORT+="- 黄金：**\$${GOLD_PRICE}/oz** （${GOLD_CHG}%）\n"
REPORT+="- 白银：**\$${SILVER_PRICE}/oz** （${SILVER_CHG}%）\n\n"

REPORT+="---\n\n"
REPORT+="### 📊 今日持仓关注\n\n"

# AI链判断
if echo "$SOX_DIR" | grep -q "暴跌\|小跌"; then
  REPORT+="**🔵 中欧新蓝筹A** ⚠️\n"
  REPORT+="- 费城半导体${SOX_DIR}，AI/光模块今日承压\n"
  REPORT+="- 中际旭创、新易盛、工业富联、寒武纪等重仓股可能低开\n"
  REPORT+="- 关注是否有回购/增持等护盘信号\n\n"
else
  REPORT+="**🔵 中欧新蓝筹A**\n"
  REPORT+="- 美股半导体${SOX_DIR}，AI链情绪平稳\n"
  REPORT+="- 重仓：中际旭创(8.5%)、新易盛(6.9%)、工业富联(4.7%)、寒武纪(4.3%)\n\n"
fi

REPORT+="**⚡ 电网设备**（天弘C + 华夏联接C）\n"
REPORT+="- 国家电网H1投资3100亿+12.6%，十五五5万亿规划\n"
REPORT+="- 电网ETF连续多日净流入，资金从AI轮动至电网\n"
REPORT+="- 与AI/半导体关联度有限，独立行情逻辑\n\n"

REPORT+="**🏦 红利低波C**\n"
REPORT+="- 银行PE仅7.2倍/分位13%，股息率4%+\n"
REPORT+="- 资金轮动防御方向，压舱石定位\n\n"

REPORT+="**🥇 积存金 + 🥈 白银LOF**\n"
REPORT+="- 金价\$${GOLD_PRICE}/oz，白银\$${SILVER_PRICE}/oz\n"
REPORT+="- 占仓位52%，关注美联储政策动向\n\n"

REPORT+="---\n\n"
REPORT+="### ⚠️ 今日关注\n"
REPORT+="- 📊 A股开盘关注：电网能否延续强势、AI链是否超跌反弹\n"
REPORT+="- 🔴 费城半导体${SOX_DIR}，对中欧新蓝筹影响最大\n\n"

REPORT+="> ⚠️ 以上内容由AI基于公开信息生成，仅供参考，不构成投资建议。投资有风险，决策需谨慎。\n"
REPORT+="> 📊 看板：[点击查看](https://779179430-rgb.github.io/portfolio-dashboard/)"

send_msg "📊 ${TODAY} 盘前早报" "$REPORT"
echo "✅ 早报已推送"
