#!/bin/zsh
# Renders panorama.html to one wide image per device and slices it into App Store panels.
#   docs/appstore/marketing/render.sh            → both devices
#   docs/appstore/marketing/render.sh iphone     → iPhone only
set -euo pipefail
here=${0:A:h}
chrome="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
out=$here/../screenshots/marketing
mkdir -p $out

render() {
  local device=$1 w=$2 h=$3
  local wide=$out/$device-panorama.png
  "$chrome" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
    --allow-file-access-from-files --virtual-time-budget=4000 \
    --window-size=$((w * 6)),$h --screenshot=$wide "file://$here/panorama.html?device=$device" 2>/dev/null
  local dir=$out/$device
  mkdir -p $dir
  for i in 1 2 3 4 5 6; do
    "$chrome" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
      --allow-file-access-from-files --virtual-time-budget=4000 \
      --window-size=$w,$h --screenshot=$dir/$i.png "file://$here/panorama.html?device=$device&panel=$i" 2>/dev/null
  done
  if [[ $device == iphone ]]; then
    mkdir -p $out/iphone-6.3
    for i in 1 2 3 4 5 6; do sips -z 2622 1206 $dir/$i.png --out $out/iphone-6.3/$i.png >/dev/null; done
  fi
  echo "$device: $(ls $dir | wc -l | tr -d ' ') panels in $dir"
}

which=${1:-all}
if [[ $which == all || $which == iphone ]]; then render iphone 1320 2868; fi
if [[ $which == all || $which == ipad ]]; then render ipad 2752 2064; fi
