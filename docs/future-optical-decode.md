# Projector 5.1 into the X3: findings

Status: sidelined. The current decision is to keep the X3 on USB from the Linux machine and use Bluetooth for casual media. This page records what was checked, so the work does not start from zero if the goal returns.

## The problem

The XGIMI Horizon 20 Pro's native Jellyfin and Prime apps output 5.1. The X3 cannot receive it. The X3 has no HDMI input. Its TOSLINK port is output only. It has no Dolby Digital or DTS decoder. Dolby Digital Live on the X3 is encoding, and Windows only.

## Paths checked

### USB from the projector

No. The projector's USB ports are host ports. Android TV USB audio is stereo by default. Multichannel needs a root-modified `/vendor/etc/usb_audio_policy_configuration.xml` plus a player that outputs multichannel PCM. Jellyfin and Prime route surround through HDMI/ARC, not USB.

### Optical from the projector

No. The projector's optical is an output. The X3's optical is an output. Two outputs cannot feed each other. The X3 has no decoder for the AC3 bitstream.

### Bluetooth

Stereo only. The projector sends A2DP. opti's `60-bluetooth-route.conf` routes it into `unified-upmix` with `upmix-method = psd`, `rear-delay = 22.0`, `mix-lfe = true`, and `lfe-cutoff = 200`. The rears and LFE are synthesized. A2DP latency is 100-200 ms. This is fine for casual media, not for gaming or lip-sync-critical viewing.

## Options not taken

### eARC AVR with pre-outs

The one-remote, true-5.1 path. Projector HDMI1 eARC to the AVR, AVR pre-outs to the Edifiers. The AVR's power amps stay unused because the Edifiers are powered.

| Model | Pre-outs | Size | Rough used price |
|-------|----------|------|------------------|
| Denon AVR-X2200W | 7.2 | 43 cm wide | £200 |
| Marantz NR1711 | 7.2 | 10.5 cm tall | £300+ |

The size is the blocker. The X2200W is the budget pick. The NR1711 is the slim pick.

### eARC extractor plus 5.1 decoder

About £100-150 for both, and small. The cheap extractors output HDMI audio or optical 5.1, not analog 5.1 RCA, so a 5.1 decoder is needed. More boxes, and no PC HDMI input.

### Optical capture into the Linux machine

A Hifime UR23, about £30-50. Projector optical out to the UR23. Linux captures the AC3 bitstream. `ffmpeg -f spdif` decodes it. `pw-cat` sends 5.1 to `unified-upmix`. The X3 stays.

Latency estimate:

| Stage | Delay |
|-------|-------|
| Optical capture | 20-60 ms |
| `ffmpeg` decode and pipe | 10-40 ms |
| PipeWire output to the X3 | 20-60 ms |
| Total | 50-160 ms |

Measure before committing. Play a click through the projector, record it with a microphone, and measure the offset. The projector's video path may need an audio delay to match. This is a project, not a purchase.

## Edifier bypass: do not

Both models use digital crossovers. There is no passive crossover input to tap.

- **R1800TIII**: PCM1808 ADC to TAS5707, with the crossover in the TAS5707's DSP. Soomal's teardown shows this.
- **R1700BTs**: TAS5805M, four amplifier channels (2 x 15 W tweeter, 2 x 18 W mid-bass), DSP crossover, and a 4-pin bi-amp cable to the passive speaker. Edifier's spec and STEREO GUIDE's review describe this.

A speaker-level A/B switch would feed full-range into the tweeters or remove the crossover. Replacing the crossover needs an external DSP. That costs more than the AVR it avoids.

Use the line inputs instead. The R1700BTs has Line In 1 and Line In 2, switchable from the remote. The R1800TIII has one RCA pair, so add a passive RCA selector.

## Decision

Keep the X3 on USB from the Linux machine. Use Bluetooth with PSD upmix for casual media. Revisit the eARC AVR or the UR23 pipeline only if true 5.1 from the projector's native apps becomes a priority.

## Sources

- Creative Sound Blaster X3 spec sheet: `1 x TOSLINK Optical Out`.
- XGIMI Horizon 20 Pro: HDMI1 eARC, optical output, USB host ports.
- Android TV USB audio policy: stereo default, root edit needed for multichannel.
- Soomal R1800TIII teardown: <https://soomal.cc/posts/10100004557/>
- Edifier R1700BTs product page: <https://www.edifier.com/p/bookshelf-speakers/r1700bts>
- STEREO GUIDE R1700BT review: <https://stereoguide.com/bluetooth-speakers/stereo-boxensets-en/edifier-r1700bt-review-active-speakers-at-a-very-competitive-price/>
