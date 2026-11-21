# Channel map

## The eight hardware channels

The X3 exposes eight raw output channels through the pro-audio profile.
PipeWire names them `aux0` to `aux7`. The card's descriptor order is:

| Aux | Position | Physical output |
|-----|----------|-----------------|
| aux0 | FL | Line Out 1 left |
| aux1 | FR | Line Out 1 right |
| aux2 | FC | Line Out 3 center (unused, no center speaker) |
| aux3 | LFE | Line Out 3 sub |
| aux4 | RL | Line Out 2 left |
| aux5 | RR | Line Out 2 right |
| aux6 | SL | unused |
| aux7 | SR | unused |

## The unified-upmix sink

`unified-upmix` is a 5-channel 4.1 sink: `[ FL FR RL RR LFE ]`.
Its playback side targets `pro-output-0` with:

```
audio.position = [ AUX0 AUX1 AUX4 AUX5 AUX3 ]
```

`stream.dont-remix = true` makes PipeWire link ports by position instead of
remixing. Each logical channel therefore lands on one aux port:

| Logical | Aux | Physical |
|---------|-----|----------|
| FL | aux0 | front left |
| FR | aux1 | front right |
| RL | aux4 | rear left |
| RR | aux5 | rear right |
| LFE | aux3 | sub |

The VBAN stream uses the same 5-channel layout, so sender and receiver agree
on channel order. No conversion happens on the receiver side.

## The amixer label trap

The hardware control `Speaker Playback Volume` has eight channels in the
same descriptor order as above. `amixer` displays them with ALSA's generic
channel names, which follow a different order:

| amixer label | Control index | Actual hardware channel |
|--------------|---------------|-------------------------|
| Front Left | 0 | FL |
| Front Right | 1 | FR |
| Rear Left | 2 | FC (center) |
| Rear Right | 3 | LFE (sub) |
| Front Center | 4 | RL (rear left) |
| Woofer | 5 | RR (rear right) |
| Side Left | 6 | SL |
| Side Right | 7 | SR |

So `amixer` calling a channel "Woofer" does not mean it is the sub.
Index 5 is the right rear. This mismatch is what caused the old
"driver swap" theory.

The volume range is 0 to 51. 51 is 0 dB. The saved state uses 47
(-6.3 dB). A value of 36 is -23.6 dB, about 17 dB below 47.

## Why there is no swap workaround

The X3 descriptor and ALSA channel map are standard:

```
FL FR FC LFE RL RR SL SR
```

The apparent swap came from the ALSA `surround51`/`surround41` plugin
ordering and from `amixer`'s generic labels, not from the hardware.
Moving to the pro-audio profile and linking aux ports directly removes
that problem. The correct playback map is the straightforward one above.
No extra swap is needed.

## Setting the right rear volume

```
amixer -c X3 cset numid=13 47,47,47,47,47,47,47,47
```

This sets all eight channels to the same level. Index 5 is RR.

## The mixer reset

The X3 resets its hardware mixer during boot initialization, after the
card has been probed. The saved state in `/var/lib/alsa/asound.state` is
correct, but the root `alsa-restore-delayed` timer runs before that reset,
so the card's own values can win. The symptom is a quiet or missing right
rear. A second restore a few seconds later fixes it. A PipeWire restart
does not trigger the reset.
