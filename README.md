# Audio Setup: Sound Blaster X3 Surround 4.0

## Hardware

- **Sound card**: Creative Sound Blaster X3 
- **Front speakers**: Edifier powered pair on Line Out 1 (green, Front L/R)
- **Rear speakers**: Edifier powered pair on Line Out 2 (black, Rear L/R)
- **Line In**: UDreamer turntable (3.5mm headphone out)
- **Future**: subwoofer on Line Out 3 (orange, C/SUB)
- **OS**: Kubuntu 26.04 LTS, PipeWire 1.6.2, WirePlumber 0.5.13

## Known X3 Driver Bug

The X3 ALSA driver has a channel swap: `RearLeft↔Center` and `RearRight↔LFE`. The pro-audio profile workaround maps AUX channels to the correct physical outputs:

| Our audio | PipeWire | ALSA label | Physical jack |
|-----------|----------|------------|---------------|
| FL | AUX0 | Front Left | Line Out 1 green |
| FR | AUX1 | Front Right | Line Out 1 green |
| RL | AUX4 | Front Center (swapped) | Line Out 2 black |
| RR | AUX5 | Woofer/LFE (swapped) | Line Out 2 black |

## Architecture

Uses PipeWire pro-audio profile with a unified loopback sink that drops FC and LFE channels.

The loopback sink (`unified-upmix`) is the default audio destination:
- Stereo sources are upmixed to 4 channels using PipeWire's PSD algorithm (`channelmix.upmix-method = psd`)
- The playback side maps to `[AUX0 AUX1 AUX4 AUX5]`, working around the X3 channel swap bug
- The orange C/SUB jack carries no signal (not mapped yet)

## Unified Upmix Sink

Config: [configs/unified-upmix-sink.conf](configs/unified-upmix-sink.conf)

All audio (local playback, Bluetooth, VBAN) routes through this sink.

Key settings:
- `capture.props`: 4 channels `[FL FR RL RR]`. PSD upmix applied to any connected stereo stream.
- `playback.props`: 4 channels `[AUX0 AUX1 AUX4 AUX5]` targeting pro-output-0.
- `target.object` points to `alsa_output.usb-Creative_Technology_Ltd_Sound_Blaster_X3_9E42D45FF9ACC811-03.pro-output-0`

### Upmix Config Scopes

| File | Location | Scope |
|------|----------|-------|
| `unified-upmix-sink.conf` | `pipewire.conf.d/` | Creates the loopback sink with upmix on capture side |
| `pipewire-pulse-upmix.conf` | `pipewire-pulse.conf.d/` | Default stream properties for PulseAudio clients |
| `client-upmix.conf` | `client.conf.d/` | Default stream properties for native PipeWire clients |

The `channelmix.*` properties only activate when PipeWire converts between channel counts (e.g. stereo source to 4ch sink).

## VBAN

Configs: [configs/vban-recv.conf](configs/vban-recv.conf) (receiver), [configs/vban-send.conf](configs/vban-send.conf) (sender)

PipeWire's built-in VBAN modules stream audio over UDP at low latency (~5-20ms). The receiver runs on this machine (opti.local), listening on port 6980. The sender runs on the source machine.

Both sender and receiver use 5 channels `[FL FR RL RR LFE]` matching the unified-upmix sink. The sender's game audio (5.1) gets FC folded into FL/FR by PipeWire's channel mixer. The receiver connects directly to `unified-upmix` with no additional upmix.

### Sender (Linux)

On the sending machine, clone the repo and symlink the sender config:

```bash
git clone https://github.com/benkalmus/audio-setup-sound-blaster-x3.git ~/repos/audio-setup-sound-blaster-x3
mkdir -p ~/.config/pipewire/pipewire.conf.d
ln -snf ~/repos/audio-setup-sound-blaster-x3/configs/vban-send.conf \
    ~/.config/pipewire/pipewire.conf.d/vban-send.conf
systemctl --user restart pipewire
```

The sender creates a sink named "Opti VBAN 5.1". Route app audio to it via pavucontrol. If the sink doesn't appear in the Plasma system tray, right-click the audio icon → **Configure Audio Volume...** → check **Show virtual devices**. The sink streams 48kHz S16LE 5ch `[FL FR RL RR LFE]` to `opti.local:6980`. Game audio at 5.1 is downmixed on the sender side (FC folded into FL/FR by PipeWire's channel mixer).

LFE extraction requires `channelmix.lfe-cutoff` set in `stream.properties` of `pipewire-pulse.conf.d/`, not in `stream.props` of the sink node. The pipewire-pulse upmix config handles this (see [Install step 3](#3-install-upmix-configs)). Without it, the LFE channel remains silent.

Tune latency with `sess.latency.msec` (5ms for wired LAN, 20ms default). `opti.local` must resolve via mDNS (Avahi) — fall back to IP if it doesn't.

## Install Steps

### 1. Set PipeWire profile to pro-audio

```bash
pactl set-card-profile alsa_card.usb-Creative_Technology_Ltd_Sound_Blaster_X3_9E42D45FF9ACC811-03 pro-audio
```

### 2. Install unified-upmix sink

```bash
mkdir -p ~/.config/pipewire/pipewire.conf.d
ln -snf ~/repos/audio-setup-sound-blaster-x3/configs/unified-upmix-sink.conf \
    ~/.config/pipewire/pipewire.conf.d/unified-upmix-sink.conf
```

### 3. Install upmix configs

```bash
mkdir -p ~/.config/pipewire/client.conf.d
mkdir -p ~/.config/pipewire/pipewire-pulse.conf.d

ln -snf ~/repos/audio-setup-sound-blaster-x3/configs/client-upmix.conf \
    ~/.config/pipewire/client.conf.d/upmix.conf

ln -snf ~/repos/audio-setup-sound-blaster-x3/configs/pipewire-pulse-upmix.conf \
    ~/.config/pipewire/pipewire-pulse.conf.d/upmix.conf
```

### 4. Install VBAN receiver

```bash
ln -snf ~/repos/audio-setup-sound-blaster-x3/configs/vban-recv.conf \
    ~/.config/pipewire/pipewire.conf.d/vban-recv.conf
```

### 5. Install VBAN sender (Linux sending machine only)

```bash
git clone https://github.com/benkalmus/audio-setup-sound-blaster-x3.git ~/repos/audio-setup-sound-blaster-x3
mkdir -p ~/.config/pipewire/pipewire.conf.d
ln -snf ~/repos/audio-setup-sound-blaster-x3/configs/vban-send.conf \
    ~/.config/pipewire/pipewire.conf.d/vban-send.conf
systemctl --user restart pipewire
```

### 6. Install Bluetooth routing

WirePlumber config for routing Bluetooth audio to unified-upmix:

```bash
mkdir -p ~/.config/wireplumber/wireplumber.conf.d
ln -snf ~/repos/audio-setup-sound-blaster-x3/configs/60-bluetooth-route.conf \
    ~/.config/wireplumber/wireplumber.conf.d/60-bluetooth-route.conf
```

Bluetooth CoD (Class of Device) config so the PC advertises as a speaker:

```bash
sudo cp bluetooth/main.conf /etc/bluetooth/main.conf
sudo systemctl restart bluetooth
```

### 7. Bluetooth: disable seat monitoring + SDDM conflict

Two WirePlumber configs are required to make Bluetooth work:

**Seat monitoring:** WirePlumber's bluez monitor waits for logind seat to become "active". Since the SDDM greeter holds seat0 in "online" state, the monitor never creates. Disable it:

```bash
sudo ln -snf ~/repos/audio-setup-sound-blaster-x3/configs/51-no-seat-monitoring.conf \
    /etc/wireplumber/wireplumber.conf.d/51-no-seat-monitoring.conf
```

**SDDM conflict:** SDDM runs its own WirePlumber instance which grabs Bluetooth endpoints. Disable Bluetooth in SDDM's WirePlumber:

```bash
sudo mkdir -p /var/lib/sddm/.config/wireplumber/wireplumber.conf.d
sudo cp ~/repos/audio-setup-sound-blaster-x3/configs/51-sddm-no-bluetooth.conf \
    /var/lib/sddm/.config/wireplumber/wireplumber.conf.d/51-no-bluetooth.conf
sudo systemctl --user -M sddm@.host restart wireplumber
```

### 8. Restart services

```bash
systemctl --user restart pipewire pipewire-pulse wireplumber
```

### 9. Set default sink

```bash
pactl set-default-sink unified-upmix
```

### 10. Set volumes

```bash
amixer -c X3 sset Speaker 100%
wpctl set-volume unified-upmix 1.0
```

### 11. Verify

```bash
pactl list short sinks

paplay /usr/share/sounds/freedesktop/stereo/bell.oga

speaker-test -c 4 -D pipewire -t wav -l 1

pactl info | grep "Default Sink"
```

## Symlink Summary

Complete list of all symlinks for this setup:

```bash
# PipeWire configs
mkdir -p ~/.config/pipewire/pipewire.conf.d
mkdir -p ~/.config/pipewire/client.conf.d
mkdir -p ~/.config/pipewire/pipewire-pulse.conf.d

ln -snf ~/repos/audio-setup-sound-blaster-x3/configs/unified-upmix-sink.conf \
    ~/.config/pipewire/pipewire.conf.d/unified-upmix-sink.conf

ln -snf ~/repos/audio-setup-sound-blaster-x3/configs/client-upmix.conf \
    ~/.config/pipewire/client.conf.d/upmix.conf

ln -snf ~/repos/audio-setup-sound-blaster-x3/configs/pipewire-pulse-upmix.conf \
    ~/.config/pipewire/pipewire-pulse.conf.d/upmix.conf

# VBAN receiver
ln -snf ~/repos/audio-setup-sound-blaster-x3/configs/vban-recv.conf \
    ~/.config/pipewire/pipewire.conf.d/vban-recv.conf

# VBAN sender (only on the sending machine)
ln -snf ~/repos/audio-setup-sound-blaster-x3/configs/vban-send.conf \
    ~/.config/pipewire/pipewire.conf.d/vban-send.conf

# WirePlumber configs
mkdir -p ~/.config/wireplumber/wireplumber.conf.d

ln -snf ~/repos/audio-setup-sound-blaster-x3/configs/60-bluetooth-route.conf \
    ~/.config/wireplumber/wireplumber.conf.d/60-bluetooth-route.conf

ln -snf ~/repos/audio-setup-sound-blaster-x3/configs/61-vban-route.conf \
    ~/.config/wireplumber/wireplumber.conf.d/61-vban-route.conf

# Seat monitoring (sudo)
sudo ln -snf ~/repos/audio-setup-sound-blaster-x3/configs/51-no-seat-monitoring.conf \
    /etc/wireplumber/wireplumber.conf.d/51-no-seat-monitoring.conf

# SDDM Bluetooth disable (sudo, must copy not symlink)
sudo mkdir -p /var/lib/sddm/.config/wireplumber/wireplumber.conf.d
sudo cp ~/repos/audio-setup-sound-blaster-x3/configs/51-sddm-no-bluetooth.conf \
    /var/lib/sddm/.config/wireplumber/wireplumber.conf.d/51-no-bluetooth.conf

# Vinyl toggle script
mkdir -p ~/bin
ln -snf ~/repos/audio-setup-sound-blaster-x3/bin/vinyl-toggle ~/bin/vinyl-toggle

# Bluetooth CoD (sudo)
sudo cp ~/repos/audio-setup-sound-blaster-x3/bluetooth/main.conf /etc/bluetooth/main.conf

# NetworkManager dispatcher (restarts PipeWire on network change, fixes VBAN)
sudo ln -snf ~/repos/audio-setup-sound-blaster-x3/configs/99-restart-pipewire \
    /etc/NetworkManager/dispatcher.d/99-restart-pipewire
```

## Vinyl Passthrough

UDreamer turntable (3.5mm headphone out) to X3 Line-In to 4.0 speakers.

Script: [bin/vinyl-toggle](bin/vinyl-toggle)

Toggle on/off to avoid ADC hiss when turntable is idle. When ON:
1. Loads `module-loopback` (source to unified-upmix)
2. Stereo signal gets PSD-upmixed to 4.0

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
ln -snf ~/repos/audio-setup-sound-blaster-x3/bin/vinyl-toggle ~/bin/vinyl-toggle
```

Ensure `~/bin` is in `$PATH` (it is by default on Kubuntu).

## Adding a Subwoofer

When ready, add AUX5 (or the correct AUX mapping for physical LFE) to the playback position array:

```lua
playback.props = {
    audio.position = [ AUX0 AUX1 AUX4 AUX5 AUX? ]  # add sub channel
    target.object = "...pro-output-0"
}
```

Then connect Line Out 3 (orange) to the subwoofer.

## Known Quirks

- **X3 channel swap bug**: RearLeft↔Center, RearRight↔LFE. Worked around with AUX remapping.
- **PSD rear channel requirement**: PipeWire's Passive Surround Decoding only sends audio to rear channels when LEFT and RIGHT differ significantly. Identical mono content produces no rear output. This is correct behaviour.
- **VBAN breaks on network change**: Switching WiFi↔ethernet causes the VBAN receiver to stop receiving audio. A NetworkManager dispatcher script (`99-restart-pipewire`) auto-restarts PipeWire when interfaces come up, restoring VBAN connectivity.
- **Bluetooth needs seat monitoring disabled**: WirePlumber's bluez monitor waits for logind seat to become "active". SDDM greeter holds seat0 in "online" state, so the monitor never creates. Disable with `configs/51-no-seat-monitoring.conf`.
- **SDDM WirePlumber grabs Bluetooth endpoints**: SDDM runs its own WirePlumber instance which registers BlueZ endpoints. The user's WirePlumber sees the transport but can't claim it. Disable Bluetooth in SDDM's WirePlumber with `configs/51-sddm-no-bluetooth.conf`.
- **LFE cutoff only works in pipewire-pulse.conf.d**: `channelmix.lfe-cutoff` must be set in `stream.properties` of `pipewire-pulse.conf.d/`, not in `stream.props` of a sink node. The sink node's property is not inherited by client adapter nodes (e.g. Chromium). The `configs/pipewire-pulse-upmix.conf` file handles this correctly.
