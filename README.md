# Audio Setup: Sound Blaster X3 Surround

## Hardware

- **Sound card**: Creative Sound Blaster X3 
- **Front speakers**: Edifier powered pair on Line Out 1 (green, Front L/R)
- **Rear speakers**: Edifier powered pair on Line Out 2 (black, Rear L/R)
- **Subwoofer**: On Line Out 3 (orange, C/SUB) via AUX3
- **Line In**: UDreamer turntable (3.5mm headphone out)
- **OS**: Kubuntu 26.04 LTS, PipeWire 1.6.2, WirePlumber 0.5.13

## Known X3 Driver Bug

The X3 ALSA driver has a channel swap: `RearLeft↔Center` and `RearRight↔LFE`. The pro-audio profile workaround maps AUX channels to the correct physical outputs:

| Our audio | PipeWire | ALSA label | Physical jack |
|-----------|----------|------------|---------------|
| FL | AUX0 | Front Left | Line Out 1 green |
| FR | AUX1 | Front Right | Line Out 1 green |
| RL | AUX4 | Front Center (swapped) | Line Out 2 black |
| RR | AUX5 | Woofer/LFE (swapped) | Line Out 2 black |
| LFE | AUX3 | Rear Right (swapped) | Line Out 3 orange |

## Architecture

Uses PipeWire pro-audio profile with a unified loopback sink that drops the FC channel.

The loopback sink (`unified-upmix`) is the default audio destination:
- Stereo sources are upmixed to 5 channels using PipeWire's PSD algorithm (`channelmix.upmix-method = psd`)
- The playback side maps to `[AUX0 AUX1 AUX4 AUX5 AUX3]`, working around the X3 channel swap bug
- The FC channel is folded into FL/FR by PipeWire's channel mixer (no physical center speaker)

## Unified Upmix Sink

Config: [configs/unified-upmix-sink.conf](configs/unified-upmix-sink.conf)

All audio (local playback, Bluetooth, VBAN) routes through this sink.

Key settings:
- `capture.props`: 5 channels `[FL FR RL RR LFE]`. PSD upmix applied to any connected stereo stream.
- `playback.props`: 5 channels `[AUX0 AUX1 AUX4 AUX5 AUX3]` targeting pro-output-0.
- `target.object` points to `alsa_output.usb-Creative_Technology_Ltd_Sound_Blaster_X3_9E42D45FF9ACC811-03.pro-output-0`

### Upmix Config Scopes

| File | Location | Scope |
|------|----------|-------|
| `unified-upmix-sink.conf` | `/etc/pipewire/pipewire.conf.d/` | Creates the loopback sink with upmix on capture side |
| `pipewire-pulse-upmix.conf` | `/etc/pipewire/pipewire-pulse.conf.d/upmix.conf` | Default stream properties for PulseAudio clients |
| `client-upmix.conf` | `/etc/pipewire/client.conf.d/upmix.conf` | Default stream properties for native PipeWire clients |

The `channelmix.*` properties only activate when PipeWire converts between channel counts (e.g. stereo source to 5ch sink).

## VBAN

Configs: [configs/vban-recv.conf](configs/vban-recv.conf) (receiver), [configs/vban-send.conf](configs/vban-send.conf) (sender)

PipeWire's built-in VBAN modules stream audio over UDP at low latency (~5-20ms). The receiver runs on this machine (opti.local), listening on port 6980. The sender runs on the source machine.

Both sender and receiver use 5 channels `[FL FR RL RR LFE]` matching the unified-upmix sink. The sender's game audio (5.1) gets FC folded into FL/FR by PipeWire's channel mixer. The receiver connects directly to `unified-upmix` with no additional upmix.

### Sender (Linux)

On the sending machine, clone the repo, set `$REPO`, and symlink the sender config:

```bash
git clone https://github.com/benkalmus/linux-sound-blaster-x3.git
export REPO=$PWD/linux-sound-blaster-x3
sudo mkdir -p /etc/pipewire/pipewire.conf.d
sudo ln -snf $REPO/configs/vban-send.conf \
    /etc/pipewire/pipewire.conf.d/vban-send.conf
systemctl --user restart pipewire
```

The sender creates a sink named "Opti VBAN 5.1". Route app audio to it via pavucontrol. If the sink doesn't appear in the Plasma system tray, right-click the audio icon → **Configure Audio Volume...** → check **Show virtual devices**. The sink streams 48kHz S16LE 5ch `[FL FR RL RR LFE]` to `opti.local:6980`. Game audio at 5.1 is downmixed on the sender side (FC folded into FL/FR by PipeWire's channel mixer).

The sender config includes `channelmix.mix-lfe = true` and `lfe-cutoff = 80` so LFE is mixed from low frequencies even with stereo sources.

Tune latency with `sess.latency.msec` (5ms for wired LAN, 20ms default). `opti.local` must resolve via mDNS (Avahi) — fall back to IP if it doesn't.

## Install

All configs are installed at system level (`/etc/pipewire/`, `/etc/wireplumber/`) so they apply to all users. PipeWire loads configs from three levels (defaults → system → user), with system-level applying to every user.

### Prerequisites

Clone the repo somewhere and set `$REPO`:

```bash
git clone https://github.com/benkalmus/linux-sound-blaster-x3.git
cd linux-sound-blaster-x3
export REPO=$PWD
```

All commands below use `$REPO` — define it to wherever you cloned.

### 1. Set PipeWire profile to pro-audio

The card name varies by machine. Find yours:

```bash
pactl list cards short | grep -i creative
```

Then set it:

```bash
pactl set-card-profile alsa_card.usb-Creative_Technology_Ltd_Sound_Blaster_X3_<SERIAL>-03 pro-audio
```

### 2. Create system config directories

```bash
sudo mkdir -p /etc/pipewire/pipewire.conf.d
sudo mkdir -p /etc/pipewire/client.conf.d
sudo mkdir -p /etc/pipewire/pipewire-pulse.conf.d
sudo mkdir -p /etc/wireplumber/wireplumber.conf.d
```

### 3. Install unified-upmix sink (receiver only)

```bash
sudo ln -snf $REPO/configs/unified-upmix-sink.conf \
    /etc/pipewire/pipewire.conf.d/unified-upmix-sink.conf
```

The `target.object` in `unified-upmix-sink.conf` must match your X3's pro-audio output. Check with:

```bash
pactl list sinks short | grep pro-output
```

Update the config if the name differs.

### 4. Install upmix configs (both machines)

```bash
sudo ln -snf $REPO/configs/pipewire-pulse-upmix.conf \
    /etc/pipewire/pipewire-pulse.conf.d/upmix.conf

sudo ln -snf $REPO/configs/client-upmix.conf \
    /etc/pipewire/client.conf.d/upmix.conf
```

### 5. Install VBAN receiver (receiver only)

```bash
sudo ln -snf $REPO/configs/vban-recv.conf \
    /etc/pipewire/pipewire.conf.d/vban-recv.conf
```

### 6. Install VBAN sender (sender only)

```bash
sudo ln -snf $REPO/configs/vban-send.conf \
    /etc/pipewire/pipewire.conf.d/vban-send.conf
```

### 7. Install WirePlumber routing

```bash
sudo ln -snf $REPO/configs/60-bluetooth-route.conf \
    /etc/wireplumber/wireplumber.conf.d/60-bluetooth-route.conf

sudo ln -snf $REPO/configs/61-vban-route.conf \
    /etc/wireplumber/wireplumber.conf.d/61-vban-route.conf
```

### 8. Bluetooth: disable seat monitoring + SDDM conflict

```bash
sudo ln -snf $REPO/configs/51-no-seat-monitoring.conf \
    /etc/wireplumber/wireplumber.conf.d/51-no-seat-monitoring.conf

sudo mkdir -p /var/lib/sddm/.config/wireplumber/wireplumber.conf.d
sudo cp $REPO/configs/51-sddm-no-bluetooth.conf \
    /var/lib/sddm/.config/wireplumber/wireplumber.conf.d/51-no-bluetooth.conf
sudo systemctl --user -M sddm@.host restart wireplumber
```

### 9. Bluetooth CoD

```bash
sudo cp $REPO/bluetooth/main.conf /etc/bluetooth/main.conf
sudo systemctl restart bluetooth
```

### 10. NetworkManager dispatcher (restarts PipeWire on network change)

```bash
sudo ln -snf $REPO/configs/99-restart-pipewire \
    /etc/NetworkManager/dispatcher.d/99-restart-pipewire
```

### 11. Restart services

```bash
systemctl --user restart pipewire pipewire-pulse wireplumber
```

### 12. Set default sink

```bash
pactl set-default-sink unified-upmix
```

### 13. Set volumes

```bash
amixer -c X3 sset Speaker 100%
wpctl set-volume unified-upmix 1.0
```

### 14. Verify

```bash
pactl list short sinks

paplay /usr/share/sounds/freedesktop/stereo/bell.oga

speaker-test -c 5 -D pipewire -t wav -l 1

pactl info | grep "Default Sink"
```

### Notes

- `/etc/pipewire/pipewire-pulse.conf.d/upmix.conf` may already exist from the package install (stock version with `mix-lfe=true`). The symlink command above overwrites it with the repo version.
- If a user has their own config in `~/.config/` at the same path, it takes precedence over the system-level one. Remove user-level symlinks to let the system config apply.
- The `target.object` in `unified-upmix-sink.conf` contains a machine-specific serial number. Verify and update if needed.

## Vinyl Passthrough

UDreamer turntable (3.5mm headphone out) to X3 Line-In to 5.1 speakers.

Script: [bin/vinyl-toggle](bin/vinyl-toggle)

Toggle on/off to avoid ADC hiss when turntable is idle. When ON:
1. Loads `module-loopback` (source to unified-upmix)
2. Stereo signal gets PSD-upmixed to 5.1

When OFF: unloads loopback.

### Usage

```bash
vinyl-toggle          # toggle
vinyl-toggle on       # force on
vinyl-toggle off      # force off
vinyl-toggle status   # print ON or OFF
```

### Install

```bash
mkdir -p ~/bin
ln -snf $REPO/bin/vinyl-toggle ~/bin/vinyl-toggle
```

Ensure `~/bin` is in `$PATH` (it is by default on Kubuntu).

## Adding a Subwoofer

The unified-upmix sink maps LFE to AUX3 (orange jack, Line Out 3). The subwoofer connects there. LFE is extracted from stereo sources via `channelmix.lfe-cutoff = 80` in `pipewire-pulse-upmix.conf` and `client-upmix.conf`. The `channelmix.mix-lfe = false` prevents the extracted LFE from being folded back into FL/FR.

## Known Quirks

- **X3 channel swap bug**: RearLeft↔Center, RearRight↔LFE. Worked around with AUX remapping.
- **PSD rear channel requirement**: PipeWire's Passive Surround Decoding only sends audio to rear channels when LEFT and RIGHT differ significantly. Identical mono content produces no rear output. This is correct behaviour.
- **VBAN breaks on network change**: Switching WiFi↔ethernet causes the VBAN receiver to stop receiving audio. A NetworkManager dispatcher script (`99-restart-pipewire`) auto-restarts PipeWire when interfaces come up, restoring VBAN connectivity.
- **Bluetooth needs seat monitoring disabled**: WirePlumber's bluez monitor waits for logind seat to become "active". SDDM greeter holds seat0 in "online" state, so the monitor never creates. Disable with `configs/51-no-seat-monitoring.conf`.
- **SDDM WirePlumber grabs Bluetooth endpoints**: SDDM runs its own WirePlumber instance which registers BlueZ endpoints. The user's WirePlumber sees the transport but can't claim it. Disable Bluetooth in SDDM's WirePlumber with `configs/51-sddm-no-bluetooth.conf`.
- **LFE cutoff in client config**: `channelmix.lfe-cutoff` must be set in `stream.properties` of `pipewire-pulse.conf.d/`, not in `stream.props` of a sink node. The sink node's property is not inherited by client adapter nodes (e.g. Chromium). The `configs/pipewire-pulse-upmix.conf` file handles this correctly. The VBAN sender config includes `mix-lfe` and `lfe-cutoff` in its own `stream.props` since it's a module, not a client-connected sink.
