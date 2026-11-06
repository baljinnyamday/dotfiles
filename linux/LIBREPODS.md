# AirPods on Linux

| Part | What it does | Install |
|---|---|---|
| Overskride | pair and connect Bluetooth devices | `yay -S overskride-bin` |
| LibrePods | battery, noise control, ear detection, AirPods settings | AUR `librepods-rust-git`, built with `makepkg -d` (Rust comes from rustup, not pacman) |
| snixembed | the StatusNotifier watcher LibrePods needs to start; also shows its icon in polybar's XEmbed tray | `sudo pacman -S snixembed` |
| `linux/bin/librepods-open` | starts LibrePods with its window; i3 runs it at login with `--start-minimized` | linked by `install.sh` |

LibrePods' battery monitor also needs BlueZ's experimental interfaces. In
`/etc/bluetooth/main.conf`, under `[General]`, set `Experimental = true`, then
`sudo systemctl restart bluetooth`.

Pairing: open the case near the PC, hold the button on its back until the light
flashes white, then pair in Overskride.

## Hi-res mic (built from LibrePods PR #655)

Standard Bluetooth has only one way to use a headset mic: call mode (HFP), which
also turns everything you hear into mono, 24 kHz audio. Macs and iPhones avoid
that with Apple's own AAC-ELD mic link. [LibrePods PR
#655](https://github.com/kavishdevar/librepods/pull/655) adds that link: a mono
64 kHz mic called `AirPods_HiRes_Mic` (node `AirPodsHiRes`), while you keep
hearing stereo at music quality.

The PR is not merged yet, so build it:

```sh
git clone --depth 30 --branch linux/rust https://github.com/LuanAdemi/librepods.git ~/librepods-pr655
cd ~/librepods-pr655/linux-rust
cargo build --release   # needs rustup's cargo, clang, ffmpeg, pipewire-pulse
install -m755 target/release/librepods ~/.local/bin/librepods-hires
librepods-open                            # runs librepods-hires when it exists
pactl set-default-source AirPodsHiRes     # WirePlumber remembers this
wpctl settings --save bluetooth.autoswitch-to-headset-profile false
```

The last line stops apps from switching the AirPods to call mode through the
plain AirPods mic. That mic then exists only in call mode, so apps see just
`AirPods_HiRes_Mic`. Without LibrePods running there is no AirPods mic: for a
call then, pick the AirPods' headset profile in pavucontrol's Configuration tab.

Tested at commit `99b0e58` with AirPods Pro 2 (USB-C, A3048).

The mic only exists while the AirPods are connected and LibrePods runs, and it
only streams while an app records from it. It starts at 100% volume; keep it
there, since more is digital boost that distorts loud speech.

Rebuild after a major ffmpeg update: `librepods-hires` links the system
`libavcodec` and stops starting when that library's version changes.

### When #655 is merged

Check with `gh pr view 655 -R kavishdevar/librepods`. Once it is merged:

```sh
rm ~/.local/bin/librepods-hires   # librepods-open falls back to the packaged librepods
# rebuild librepods-rust-git from the AUR, as above
```

Then remove this section and the `librepods-hires` lines in `linux/bin/librepods-open`.

## Quirks

- LibrePods always picks SBC-XQ over AAC: the order is hard-coded. Both sound
  close to transparent on AirPods, so it is left alone.
- LibrePods forces music mode when a media player starts or a bud goes in. With
  the plain AirPods mic, that cuts a call's mic. The hi-res mic is not affected.
- The case shows 0% while both buds are out of it: the case reports its battery
  only through a bud sitting in it.
- LibrePods writes its log to `~/.xsession-errors`, with UTC timestamps.
