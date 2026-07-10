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

## VBAN Receiver

Config: [configs/vban-recv.conf](configs/vban-recv.conf)

Receives audio from Windows Voicemeeter over VBAN protocol (UDP port 6980). The stream is declared as 2ch `[FL FR]` with `channelmix.upmix` enabled on the stream itself. This ensures PipeWire upmixes stereo to 4ch before reaching the unified-upmix sink.

Voicemeeter sender must be set to 2 channels. The upmix happens on the receiver side.

## Install Steps

### 0. Systemd override: wait for X3 USB device

Prevents race condition where PipeWire starts before the X3 pro-output-0 sink is ready, causing the loopback to fall back to a 2ch S/PDIF sink.

```bash
mkdir -p ~/.config/systemd/user/pipewire.service.d
ln -snf ~/repos/audio-setup-sound-blaster-x3/configs/x3-wait.conf \
    ~/.config/systemd/user/pipewire.service.d/x3-wait.conf
systemctl --user daemon-reload
```

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

### 5. Install Bluetooth routing

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

### 6. Bluetooth: disable seat monitoring + SDDM conflict

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

### 7. Restart services

```bash
systemctl --user restart pipewire pipewire-pulse wireplumber
```

### 8. Set default sink

```bash
pactl set-default-sink unified-upmix
```

### 9. Set volumes

```bash
amixer -c X3 sset Speaker 100%
wpctl set-volume unified-upmix 1.0
```

### 10. Verify

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
