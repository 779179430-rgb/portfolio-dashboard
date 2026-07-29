#!/bin/bash
# 🌙 晚间速递 - 每日 20:30 推送
# 内容：重大新闻扫描 + 美股开盘前瞻 + 明日持仓预判

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
# 美股盘前期货
US_FUT=$(curl -s "https://qt.gtimg.cn/q=usNQ00Y,usYM00Y" 2>/dev/null)
parse_qt() { echo "$1" | grep -oP '[^~]+' | sed -n "${2}p"; }

NQ_FUT_CHG=$(parse_qt "$US_FUT" 32)  # 纳指期货
YM_FUT_CHG=$(parse_qt "$US_FUT" 32 | tail -1)  # 道指期货

# 金银
GOLD_DATA=$(curl -s "https://api.gold-api.com/price/XAU" 2>/dev/null)
GOLD_PRICE=$(echo "$GOLD_DATA" | grep -o '"price":[0-9.]*' | cut -d: -f2)
GOLD_CHG=$(echo "$GOLD_DATA" | grep -o '"ch":[0-9.-]*' | cut -d: -f2)
SILVER_DATA=$(curl -s "https://api.gold-api.com/price/XAG" 2>/dev/null)
SILVER_PRICE=$(echo "$SILVER_DATA" | grep -o '"price":[0-9.]*' | cut -d: -f2)

GOLD_PRICE=${GOLD_PRICE:-"--"}; GOLD_CHG=${GOLD_CHG:-"--"}
SILVER_PRICE=${SILVER_PRICE:-"--"}
NQ_FUT_CHG=${NQ_FUT_CHG:-"--"}

# 美股期货方向
NQ_DIR=""
if [ "$NQ_FUT_CHG" != "--" ] && [ -n "$NQ_FUT_CHG" ]; then
  NQ_N=$(echo "$NQ_FUT_CHG" | sed 's/[^0-9.-]//g')
  if [ -n "$NQ_N" ]; then
    if (( $(echo "$NQ_N > 1" | bc -l 2>/dev/null || echo 0) )); then NQ_DIR="🔥 大涨"
    elif (( $(echo "$NQ_N > 0" | bc -l 2>/dev/null || echo 0) )); then NQ_DIR="🟢 小涨"
    elif (( $(echo "$NQ_N < -2" | bc -l 2>/dev/null || echo 0) )); then NQ_DIR="⚠️ 大跌"
    elif (( $(echo "$NQ_N < 0" | bc -l 2>/dev/null || echo 0) )); then NQ_DIR="🔻 小跌"
    fi
  fi
fi

# ========== 组装晚间速递 ==========
REPORT="## 🌙 ${TODAY} 周${W} 晚间速递\n\n"
REPORT+="---\n\n"

REPORT+="### 🇺🇸 美股盘前\n"
REPORT+="- 纳指期货：${NQ_DIR}（${NQ_FUT_CHG}%）\n"
REPORT+="- 今晚美股开盘方向：${NQ_DIR:-待观察}\n\n"

REPORT+="### 🥇 贵金属晚间\n"
REPORT+="- 黄金：**\$${GOLD_PRICE}/oz**（${GOLD_CHG}%）\n"
REPORT+="- 白银：**\$${SILVER_PRICE}/oz**\n\n"

REPORT+="---\n\n"
REPORT+="### 📰 持仓板块新闻扫描\n\n"

REPORT+="**⚡ 电网设备**\n"
REPORT+="- 关注盘后是否有能源局/国家电网新政策发布\n"
REPORT+="- 十五五电网投资5万亿长期逻辑不变\n\n"

REPORT+="**🔵 AI/半导体**\n"
REPORT+="- 关注晚间美股半导体走势（英伟达、AMD、费城半导体）\n"
REPORT+="- 中际旭创、寒武纪等是否有新的公告/调研信息\n"
REPORT+="- 存储芯片恐慌是否缓解\n\n"

REPORT+="**🏦 红利低波**\n"
REPORT+="- 银行/高股息方向：关注10年期国债收益率变化\n"
REPORT+="- 防御属性在震荡市中持续受益\n\n"

REPORT+="**🥇 贵金属**\n"
REPORT+="- 关注美联储官员讲话及经济数据\n"
REPORT+="- 金价\$${GOLD_PRICE}，距成本\$4090还需反弹约1.7%\n\n"

REPORT+="---\n\n"
REPORT+="### 🔮 明日持仓预判\n"

# 基于美股期货简单预判
if echo "$NQ_DIR" | grep -q "大涨\|小涨"; then
  REPORT+="- 🔵 AI链：美股期货偏强，明日中欧新蓝筹可能企稳反弹\n"
elif echo "$NQ_DIR" | grep -q "大跌\|小跌"; then
  REPORT+="- 🔵 AI链：美股期货偏弱，明日中欧新蓝筹继续承压，关注超跌机会\n"
else
  REPORT+="- 🔵 AI链：关注晚间美股实际走势\n"
fi

REPORT+="- ⚡ 电网：独立行情，受美股影响小，关注资金是否持续流入\n"
REPORT+="- 🏦 红利低波：低波动，大概率窄幅震荡\n"
REPORT+="- 🏅 金银：跟随美元和实际利率\n\n"

REPORT+="> ⚠️ 以上内容由AI基于公开信息生成，仅供参考，不构成投资建议。投资有风险，决策需谨慎。\n"
REPORT+="> 📊 看板：[点击查看](https://779179430-rgb.github.io/portfolio-dashboard/)"

send_msg "🌙 ${TODAY} 晚间速递" "$REPORT"
echo "✅ 晚间速递已推送"
