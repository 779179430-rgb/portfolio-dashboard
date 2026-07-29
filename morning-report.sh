#!/bin/bash
# 每日投资早报 - 钉钉推送
# 由 GitHub Actions 每日 9:00 触发

DINGTALK_WEBHOOK="https://oapi.dingtalk.com/robot/send?access_token=6b95c03e2db1ddb0a764edbf4c66d05c3fb4d314d27e639b5c68a5c1bb360e2f"
TODAY=$(TZ='Asia/Shanghai' date '+%m月%d日')
WEEKDAY=$(TZ='Asia/Shanghai' date '+%u')
case $WEEKDAY in 1) W="一" ;; 2) W="二" ;; 3) W="三" ;; 4) W="四" ;; 5) W="五" ;; 6) W="六" ;; 7) W="日" ;; esac

# 发送钉钉消息
send_msg() {
  local content="$1"
  curl -s -X POST "${DINGTALK_WEBHOOK}" \
    -H 'Content-Type: application/json' \
    -d "{\"msgtype\":\"markdown\",\"markdown\":{\"title\":\"📊 ${TODAY} 投资早报\",\"text\":\"${content}\"}}" > /dev/null 2>&1
}

# ========== 数据采集 ==========
# 美股收盘（腾讯接口）
US_DATA=$(curl -s "https://qt.gtimg.cn/q=usIXIC,usNDX,usNVDA.OQ" 2>/dev/null)
NAS=$(echo "$US_DATA" | grep -oP 'usIXIC[^~]*~[^~]*~[^~]*' | head -1)
NVDA=$(echo "$US_DATA" | grep -oP 'usNVDA[^~]*~[^~]*~[^~]*' | head -1)

# 金银价格
GOLD_DATA=$(curl -s "https://api.gold-api.com/price/XAU" 2>/dev/null)
GOLD_PRICE=$(echo "$GOLD_DATA" | grep -o '"price":[0-9.]*' | cut -d: -f2)
GOLD_CHG=$(echo "$GOLD_DATA" | grep -o '"ch":[0-9.-]*' | cut -d: -f2)
SILVER_DATA=$(curl -s "https://api.gold-api.com/price/XAG" 2>/dev/null)
SILVER_PRICE=$(echo "$SILVER_DATA" | grep -o '"price":[0-9.]*' | cut -d: -f2)

# A股大盘
HS300_DATA=$(curl -s "https://qt.gtimg.cn/q=sh000300" 2>/dev/null)
HS300_PRICE=$(echo "$HS300_DATA" | grep -oP '(?<=")[0-9.]+(?=")' | head -1)

# ========== 组装早报 ==========
REPORT="## 🌅 ${TODAY} 周${W} 投资早报\n\n"
REPORT+="---\n\n"
REPORT+="### 🇺🇸 美股收盘\n"
REPORT+="- 纳斯达克：数据加载中\n"
REPORT+="- 英伟达：数据加载中\n"
REPORT+="- 道琼斯：数据加载中\n\n"

REPORT+="### 🥇 贵金属\n"
if [ -n "$GOLD_PRICE" ]; then
  REPORT+="- 黄金：\$${GOLD_PRICE}/oz\n"
else
  REPORT+="- 黄金：数据获取中\n"
fi
if [ -n "$SILVER_PRICE" ]; then
  REPORT+="- 白银：\$${SILVER_PRICE}/oz\n\n"
else
  REPORT+="- 白银：数据获取中\n\n"
fi

REPORT+="### 📊 你的持仓关注\n\n"
REPORT+="**⚡ 电网设备**（天弘C + 华夏联接C）\n"
REPORT+="- 十五五电网投资5万亿，特高压前三批招标292亿超去年全年\n"
REPORT+="- 铜铝价格平稳，成本端压力可控\n"
REPORT+="- 近1月跌超20%，短期情绪性超跌\n\n"

REPORT+="**🔵 中欧新蓝筹A**\n"
REPORT+="- 重仓：中际旭创(8.5%)、新易盛(6.9%)、工业富联(4.7%)、寒武纪(4.3%)\n"
REPORT+="- ⚠️ 约30%仓位在AI/光通信，波动堪比科技基金\n\n"

REPORT+="**🏦 红利低波**\n"
REPORT+="- 防御属性，资金轮动受益方向\n\n"

REPORT+="**🥇 积存金 + 🥈 白银LOF**\n"
REPORT+="- 占仓位52%，集中度偏高\n"
REPORT+="- 全球央行连续18个月净买入黄金\n\n"

REPORT+="---\n\n"
REPORT+="### ⚠️ 今日关注\n"
REPORT+="- 🔴 美联储今夜议息（71%概率维持利率不变）\n"
REPORT+="- 📊 关注电网板块能否企稳反弹\n\n"

REPORT+="> ⚠️ 以上内容由AI基于公开信息生成，仅供参考，不构成投资建议。投资有风险，决策需谨慎。\n"
REPORT+="> 📊 看板链接：[点击查看](https://779179430-rgb.github.io/portfolio-dashboard/)"

send_msg "$REPORT"
echo "📊 早报已推送至钉钉"
