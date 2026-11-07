#!/bin/zsh
# Renders header.html to the App Store product page header (3840 × 1646, 21:9, no alpha).
set -euo pipefail
here=${0:A:h}
chrome="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
out=$here/../screenshots/marketing/header
mkdir -p $out
"$chrome" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
  --allow-file-access-from-files --virtual-time-budget=4000 \
  --window-size=3840,1646 --screenshot=$out/header-raw.png "file://$here/header.html" 2>/dev/null
# Flatten to JPEG then back to PNG to drop the alpha channel App Store Connect rejects.
sips -s format jpeg -s formatOptions 95 $out/header-raw.png --out $out/header.jpg >/dev/null
sips -s format png $out/header.jpg --out $out/header.png >/dev/null
rm $out/header-raw.png
sips -g pixelWidth -g pixelHeight -g hasAlpha $out/header.png | tail -3
