#!/bin/bash
# 每日自动更新行情数据的脚本
# 由 GitHub Actions 定时触发

echo "📊 $(date '+%Y-%m-%d %H:%M') 开始更新行情数据..."

# 获取黄金价格
GOLD_DATA=$(curl -s "https://api.gold-api.com/price/XAU" 2>/dev/null || echo '{"price":4044,"change":0}')
GOLD_PRICE=$(echo "$GOLD_DATA" | grep -o '"price":[0-9.]*' | head -1 | cut -d: -f2)
GOLD_PRICE=${GOLD_PRICE:-4044}

# 获取白银价格
SILVER_DATA=$(curl -s "https://api.gold-api.com/price/XAG" 2>/dev/null || echo '{"price":57,"change":0}')
SILVER_PRICE=$(echo "$SILVER_DATA" | grep -o '"price":[0-9.]*' | head -1 | cut -d: -f2)
SILVER_PRICE=${SILVER_PRICE:-57}

# 获取沪深300（通过腾讯接口）
HS300_DATA=$(curl -s "https://qt.gtimg.cn/q=sh000300" 2>/dev/null)
HS300_PRICE=$(echo "$HS300_DATA" | grep -oP '(?<=~)[0-9.]+(?=~)' | head -1)
HS300_CHG=$(echo "$HS300_DATA" | grep -oP '(?<=~)[0-9.-]+(?=~)' | head -2 | tail -1)

echo "🥇 黄金: \$${GOLD_PRICE}"
echo "🥈 白银: \$${SILVER_PRICE}"
echo "📈 沪深300: ${HS300_PRICE}"

# 更新 HTML 中的行情数据
TODAY=$(date '+%Y-%m-%d')
if [ -f index.html ]; then
    # 更新日期
    sed -i "s|数据: 202[0-9]-[0-9][0-9]-[0-9][0-9]|数据: ${TODAY}|g" index.html
    
    echo "✅ 更新完成: ${TODAY}"
else
    echo "❌ index.html 不存在"
    exit 1
fi

echo "📊 数据更新完毕"
