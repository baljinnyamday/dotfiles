#!/bin/sh
# screenconfig.sh -- run by i3 at login. Every connected screen at its native resolution and its
# highest refresh rate (X starts at 60 Hz even on a 144 Hz monitor), placed left to right in
# xrandr's order with the first one primary; outputs with nothing plugged in are switched off.
# Unlike a fixed arandr layout, it can't fail because a monitor named in it is unplugged.
xrandr --query | awk '
  / disconnected/ { off = off " --output " $1 " --off"; want = 0; next }
  / connected/    { out = $1; want = 1; next }
  want && /\+/    {  # the preferred (native) mode line; pick its highest rate
    best = 0
    for (i = 2; i <= NF; i++) { r = $i; gsub(/[*+]/, "", r); if (r + 0 > best + 0) best = r }
    args = args " --output " out " --mode " $1 " --rate " best (prev ? " --right-of " prev : " --primary --pos 0x0")
    prev = out; want = 0
  }
  END { print args off }' | xargs -r xrandr
