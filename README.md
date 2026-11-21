# Audio Setup: Sound Blaster X3 Surround

## Hardware

- **Sound card**: Creative Sound Blaster X3 
- **Front speakers**: Edifier powered pair on Line Out 1 (green, Front L/R)
- **Rear speakers**: Edifier powered pair on Line Out 2 (black, Rear L/R)
- **Subwoofer**: On Line Out 3 (orange, C/SUB) via AUX3
- **Line In**: UDreamer turntable (3.5mm headphone out)
- **OS**: Kubuntu 26.04 LTS, PipeWire 1.6.2, WirePlumber 0.5.13

## Quick Install

Edit `config.conf` first. It holds the peer address, sender name, VBAN port, card id, and X3 sink.

```bash
sudo make            # VBAN host (default)
sudo make sender     # VBAN sender
sudo make bluetooth
sudo make vinyl
sudo make all
```

`sudo make -n host` previews the commands. `sudo make doctor` checks the installed state.

`sudo make host` masks the sddm user's audio units so the login greeter cannot take the X3 or bind the VBAN port.

The four value-driven configs are rendered into `/etc`, not symlinked. Re-run `sudo make host` after editing `config.conf`. Revert with `sudo make revert-host`, `revert-sender`, `revert-bluetooth`, or `revert-vinyl`.

## Channel Order And The "Swap" Myth

The X3's USB descriptor and ALSA channel map are standard:

```
FL FR FC LFE RL RR SL SR
```

The pro-audio profile exposes these as `aux0` to `aux7`. The playback map is:

| Logical | Aux | Physical jack |
|---------|-----|---------------|
| FL | aux0 | Line Out 1 green |
| FR | aux1 | Line Out 1 green |
| RL | aux4 | Line Out 2 black |
| RR | aux5 | Line Out 2 black |
| LFE | aux3 | Line Out 3 orange |

Older versions of this repo described a `RearLeft↔Center` and `RearRight↔LFE` driver swap. That was a misreading of `amixer`'s channel labels. ALSA names the eight mixer channels in a different order than the X3 descriptor. `amixer` calls index 4 "Front Center" and index 5 "Woofer", but those channels are RL and RR. No aux swap is needed. The full table is in [docs/channel-map.md](docs/channel-map.md).

## Architecture

Uses PipeWire pro-audio profile with a unified loopback sink that drops the FC channel.

The loopback sink (`unified-upmix`) is the default audio destination:
- Stereo sources are upmixed to 5 channels using PipeWire's PSD algorithm (`channelmix.upmix-method = psd`)
- The playback side maps `[FL FR RL RR LFE]` to `[AUX0 AUX1 AUX4 AUX5 AUX3]` (see [docs/channel-map.md](docs/channel-map.md))
- The FC channel is folded into FL/FR by PipeWire's channel mixer (no physical center speaker)

## Unified Upmix Sink

Config: [configs/unified-upmix-sink.conf](configs/unified-upmix-sink.conf)

All audio (local playback, Bluetooth, VBAN) routes through this sink.

Key settings:
- `capture.props`: 5 channels `[FL FR RL RR LFE]`. PSD upmix applied to any connected stereo stream.
- `playback.props`: 5 channels `[AUX0 AUX1 AUX4 AUX5 AUX3]` targeting pro-output-0.
- `target.object` comes from `X3_SINK` in `config.conf` (the X3 pro-audio output).

### Upmix Config Scopes

| File | Location | Scope |
|------|----------|-------|
| `unified-upmix-sink.conf` | `/etc/pipewire/pipewire.conf.d/` | Creates the loopback sink with upmix on capture side |
| `pipewire-pulse-upmix.conf` | `/etc/pipewire/pipewire-pulse.conf.d/upmix.conf` | Default stream properties for PulseAudio clients |
| `client-upmix.conf` | `/etc/pipewire/client.conf.d/upmix.conf` | Default stream properties for native PipeWire clients |

The `channelmix.*` properties only activate when PipeWire converts between channel counts (e.g. stereo source to 5ch sink).

## VBAN

Configs: [configs/vban-recv.conf](configs/vban-recv.conf) (receiver), [configs/vban-send.conf](configs/vban-send.conf) (sender)

PipeWire's built-in VBAN modules stream audio over UDP at low latency (~5-20ms). The receiver runs on the machine with the X3, listening on `VBAN_PORT` from `config.conf` (default 6980). The sender runs on the source machine.

Both sender and receiver use 5 channels `[FL FR RL RR LFE]` matching the unified-upmix sink. The sender's game audio (5.1) gets FC folded into FL/FR by PipeWire's channel mixer. The receiver connects directly to `unified-upmix` with no additional upmix.

### Sender (Linux)

On the sending machine, clone the repo, edit `config.conf`, and run:

```bash
sudo make sender
```

The sender creates a sink named "Opti VBAN 5.1". Route app audio to it via pavucontrol. If the sink doesn't appear in the Plasma system tray, right-click the audio icon → **Configure Audio Volume...** → check **Show virtual devices**. The sink streams 48kHz S16LE 5ch `[FL FR RL RR LFE]` to `HOST_ADDR:VBAN_PORT` (default `opti.local:6980`). Game audio at 5.1 is downmixed on the sender side (FC folded into FL/FR by PipeWire's channel mixer).

The sender config includes `channelmix.mix-lfe = true` and `lfe-cutoff = 80` so LFE is mixed from low frequencies even with stereo sources.

Tune latency with `sess.latency.msec` (5ms for wired LAN, 20ms default). `HOST_ADDR` must resolve via mDNS (Avahi) — fall back to IP if it doesn't.

## Manual Install

Use `sudo make`. The scripts read `config.conf` and render the templates into `/etc`. The old step-by-step commands are in git history at commit 7192061.

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
sudo make vinyl
```

Ensure `~/bin` is in `$PATH` (it is by default on Kubuntu).

## Headphone L/R Swap (Onboard Audio)

Some systems (e.g. AMD Matisse/Starship HD Audio + ALC1220 motherboard output) present reversed left/right headphone channels. Two configs are provided, one per layer:

| Config | Layer | How it works |
|--------|-------|--------------|
| `configs/swap-lr.conf` | WirePlumber | Sets `audio.position = ["FR","FL"]` on the hardware sink via `monitor.alsa.rules`; same sink name, no graph change |
| `configs/50-lr-swap.conf` | PipeWire | Loopback virtual sink that swaps in software; needs default-sink switch |

### WirePlumber approach (recommended)

`configs/swap-lr.conf` matches the node by name and flips its channel order. The `node.name` in the match must be your device's sink — find it with:

```bash
pactl list sinks short | grep analog
```

Rename the file to a leading number lower than any existing rule, then install (system-wide or per-user):

```bash
sudo mkdir -p /etc/wireplumber/wireplumber.conf.d
sudo ln -snf $REPO/configs/swap-lr.conf \
    /etc/wireplumber/wireplumber.conf.d/swap-lr.conf
# or per-user instead of system-level:
# mkdir -p ~/.config/wireplumber/wireplumber.conf.d
# ln -snf $REPO/configs/swap-lr.conf \
#     ~/.config/wireplumber/wireplumber.conf.d/swap-lr.conf

systemctl --user restart wireplumber
```

Verify a channel test (e.g. `speaker-test -c 2 -t wav` or a YouTube L/R test) pans correctly. Revert by removing the symlink and restarting.

### PipeWire loopback alternative

`configs/50-lr-swap.conf` creates a `lr-swapped_sink` virtual sink targeting the hardware sink with `audio.position` mirrored on each side. It adds a processing hop and requires it to be the default sink:

```bash
sudo ln -snf $REPO/configs/50-lr-swap.conf \
    /etc/pipewire/pipewire.conf.d/50-lr-swap.conf
systemctl --user restart pipewire wireplumber
wpctl set-default lr-swapped_sink
```

Only the WirePlumber file is needed for a plain headphone flip; the loopback variant is for when a PipeWire-only setup is preferred.

## Adding a Subwoofer

The unified-upmix sink maps LFE to AUX3 (orange jack, Line Out 3). The subwoofer connects there. LFE is extracted from stereo sources via `channelmix.lfe-cutoff = 80` in `pipewire-pulse-upmix.conf` and `client-upmix.conf`. The `channelmix.mix-lfe = false` prevents the extracted LFE from being folded back into FL/FR.

## ALSA Mixer Reset on Boot

The X3's USB audio descriptor is incomplete. PipeWire probes the device with unsupported channel configs, fails with `Broken configuration: no configurations available`, and the failed init resets the hardware mixer. The built-in `alsa-restore.service` runs too early (before PipeWire), so levels get stomped.

Configs: [configs/alsa-restore-delayed.service](configs/alsa-restore-delayed.service), [configs/alsa-restore-delayed.timer](configs/alsa-restore-delayed.timer)

A systemd timer runs `alsactl restore` at 15s, 45s, 90s, and 180s after boot, after the X3 finishes card init. The stock `alsa-restore.service` stores the current levels on shutdown, so the late passes restore whatever you last set. `sudo make host` installs and enables the timer.

To save the levels without a reboot:

```bash
sudo alsactl store
```

## Known Quirks

- **X3 channel labels look swapped**: `amixer` labels the eight channels in ALSA generic order, so its "Woofer" is the right rear. There is no hardware swap. See [docs/channel-map.md](docs/channel-map.md).
- **PSD rear channel requirement**: PipeWire's Passive Surround Decoding only sends audio to rear channels when LEFT and RIGHT differ significantly. Identical mono content produces no rear output. This is correct behaviour.
- **VBAN breaks on network change**: Switching WiFi↔ethernet causes the VBAN receiver to stop receiving audio. A NetworkManager dispatcher script (`99-restart-pipewire`) auto-restarts PipeWire when interfaces come up, restoring VBAN connectivity.
- **Bluetooth needs seat monitoring disabled**: WirePlumber's bluez monitor waits for logind seat to become "active". SDDM greeter holds seat0 in "online" state, so the monitor never creates. Disable with `configs/51-no-seat-monitoring.conf`.
- **SDDM greeter audio is masked**: `sudo make host` masks the sddm user's `pipewire`, `pipewire-pulse`, `wireplumber`, and `filter-chain` units. The greeter cannot start an audio stack, take the X3, or bind the VBAN port. If the sddm user manager is not running, the installer writes the mask files under the sddm user's `$HOME/.config/systemd/user`. The `51-sddm-no-alsa.conf` and `51-sddm-no-bluetooth.conf` drop-ins are retained until the cleanup tracked in `TODO.md`.
- **LFE cutoff in client config**: `channelmix.lfe-cutoff` must be set in `stream.properties` of `pipewire-pulse.conf.d/`, not in `stream.props` of a sink node. The sink node's property is not inherited by client adapter nodes (e.g. Chromium). The `configs/pipewire-pulse-upmix.conf` file handles this correctly. The VBAN sender config includes `mix-lfe` and `lfe-cutoff` in its own `stream.props` since it's a module, not a client-connected sink.

## Future Work

- [Projector 5.1 into the X3](docs/future-optical-decode.md): eARC AVR, optical capture, and Edifier bypass findings. Sidelined. The current setup keeps the X3 on USB and uses Bluetooth for casual media.

## Development

Python is checked with ruff and pyright. The agent tests run the real agent against a stub BlueZ on a private D-Bus bus, so they need no adapter, no root, and no restart.

```bash
make lint   # ruff + pyright
make test   # six agent scenarios in bluetooth/
make check  # both
```

`bin/bluetooth-auto-agent` runs on `/usr/bin/python3` and needs no virtualenv. Its imports come from the Ubuntu packages `python3-dbus` and `python3-gi`, which live in `/usr/lib/python3/dist-packages`; `pyrightconfig.json` points the type checker there for that reason.
