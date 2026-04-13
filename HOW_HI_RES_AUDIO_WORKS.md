# Hi-Res Audio Configuration (192 kHz / 24-bit)

This documents the changes made to PipeWire/WirePlumber to drive the **iFi GO link Max** USB DAC at its native 192 kHz / 24-bit format, bypassing PipeWire's default resampling.

## Current state (verified)

```
$ pactl list sinks | grep -A2 'iFi'
Name: alsa_output.usb-iFi_GO_link_Max_iFi_USB_Audio_SE-00.pro-output-0
Description: GO link Max Pro
Sample Specification: s32le 2ch 192000Hz       # ← 24-bit data in a 32-bit container, 192 kHz

$ pactl info | grep 'Default Sample'
Default Sample Specification: float32le 2ch 192000Hz   # ← PipeWire's internal mix format
```

The DAC's active card profile is `pro-audio` (not the default `analog-stereo`).

---

## Change 1 — Force PipeWire's global clock to 192 kHz

**File created:** `~/.config/pipewire/pipewire.conf.d/hi-res.conf`

```ini
context.properties = {
    default.clock.rate = 192000
    default.clock.allowed-rates = [ 192000 ]
}
```

### How this differs from the stock config

Stock values in `/usr/share/pipewire/pipewire.conf` (commented-out defaults):

| Setting                       | Default      | This system     |
|-------------------------------|--------------|-----------------|
| `default.clock.rate`          | `48000`      | `192000`        |
| `default.clock.allowed-rates` | `[ 48000 ]`  | `[ 192000 ]`    |

**Why both keys:**
- `default.clock.rate` sets the rate PipeWire's graph runs at on startup.
- `default.clock.allowed-rates` is the allow-list of rates PipeWire is permitted to *switch to* when a stream requests a different rate. Leaving it at the default `[48000]` would cause PipeWire to resample 192 kHz content down to 48 kHz before sending it to the DAC, defeating the point. Restricting the list to `[192000]` guarantees no resampling happens in the graph.

**Why a drop-in instead of editing `/usr/share/pipewire/pipewire.conf`:**
The `pipewire.conf.d/` directory is merged on top of the system config, so the override survives package upgrades that would otherwise overwrite the main config.

### Trade-off

Everything is now resampled *upstream* (in the application or libsoxr) to 192 kHz. A 44.1 kHz source (most music) will be upsampled by a non-integer factor (44100 → 192000). If you mostly play 44.1 kHz material, an arguably better config is:

```ini
default.clock.allowed-rates = [ 44100 48000 88200 96000 176400 192000 ]
```

…which lets PipeWire switch the graph to whatever rate matches the source, avoiding any resampling at all. The current single-rate config trades that flexibility for a guarantee that the DAC is always locked to 192 kHz.

---

## Change 2 — Switch the DAC card to the `pro-audio` profile

**Not a config file change** — this is persisted by WirePlumber's state store at:

```
~/.local/state/wireplumber/default-profile
    alsa_card.usb-iFi_GO_link_Max_iFi_USB_Audio_SE-00=pro-audio
```

Set once via `pavucontrol` (Configuration tab → GO link Max → Profile: **Pro Audio**) or:

```
wpctl set-profile <card-id> <profile-index>
```

WirePlumber writes the choice to the state file above and re-applies it on every boot.

### Why this matters for 24-bit

The default `analog-stereo` profile exposes the device through PulseAudio-style channel-mapped sinks that go through PipeWire's mixer at **float32**. The `pro-audio` profile exposes the raw ALSA device so the ALSA sink negotiates the **native hardware format directly** — for the GO link Max that's `s32le` (a 32-bit container carrying the DAC's 24-bit samples). Without `pro-audio`, you'd be locked to whatever fixed format the analog profile advertises, typically `s16le` or `s24le` at a single channel layout.

The `.pro-output-0` suffix on the sink name (vs. `.analog-stereo`) is how you can confirm the profile is active.

---

## Verifying it's working end-to-end

```bash
# Confirm the sink is in pro-audio mode at 192 kHz, 32-bit container
pactl list sinks | grep -A4 'iFi'

# Confirm PipeWire's graph clock is locked to 192 kHz
pw-metadata -n settings 0 | grep clock.rate

# Watch a stream's actual format while playing — should show s32le / 192000
pw-top
```

If `pw-top` shows the DAC node running at anything other than 192000, or `pactl list sinks` shows `s16le` / `s24le` / a non-`pro-output` sink name, one of the two changes above has regressed.

---

## Files involved (summary)

| Path                                                        | Purpose                                | Owner       |
|-------------------------------------------------------------|----------------------------------------|-------------|
| `~/.config/pipewire/pipewire.conf.d/hi-res.conf`            | Lock PipeWire graph to 192 kHz         | User-created |
| `~/.local/state/wireplumber/default-profile`                | Persist `pro-audio` card profile       | WirePlumber-managed (set once via pavucontrol) |
| `/usr/share/pipewire/pipewire.conf`                         | Stock defaults (unchanged)             | Package-owned |
