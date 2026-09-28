# MacBook9,1 internal speakers on Ubuntu

How I got the internal speakers working on a 12" MacBook (Early 2016, `MacBook9,1`)
running Ubuntu. Headphones worked out of the box; the built-in speakers were silent.

| | |
|---|---|
| Machine | MacBook9,1 (12" MacBook, 2016) |
| CPU | Intel Core m7-6Y75 @ 1.20GHz (Skylake) |
| Codec | Cirrus Logic CS4208 (`10134208`, subsystem `106b6500`) |
| Controller | Intel Sunrise Point-LP HD Audio `[8086:9d70]` |
| OS | Ubuntu 26.04.1 LTS |
| Kernels verified | `7.0.0-31-generic`, `7.0.0-34-generic` |
| Driver used | [juicecultus/macbook12-audio-driver](https://github.com/juicecultus/macbook12-audio-driver) @ `75884e2` |

## Diagnosis

- **Headphones** (pin `0x10`) use a normal analog DAC (converter `0x02`) that the
  generic HDA driver handles fine.
- **Internal speakers** (pin `0x1d`, "Fixed Speaker at Int") sit behind an
  "8-Channels Digital" converter (`0x0a`). Driving them needs a codec-specific init
  sequence (GPIO toggling + vendor coefficient writes) that mainline Linux doesn't have.
- The stock `snd-hda-codec-cs420x` finds no quirk for this machine. The boot log shows
  an empty fixup name:

  ```
  CS4208: picked fixup  for codec SSID 106b:0000
  ```

- During playback, `/proc/asound/card0/codec#0` shows converter `0x0a` with `stream=0`.
  No PCM data ever gets there.

Red herrings:

- Unmuting Master / the PipeWire sink didn't help. Master was muted, but that wasn't the cause.
- `model=` module options don't help, because no existing fixup covers this hardware.

## Fix

Replace the stock `snd-hda-codec-cs420x` module with the out-of-tree driver above, built
with DKMS so it rebuilds automatically on kernel updates. The driver contains the
reverse-engineered macOS init sequence for this codec. Its installer downloads the
matching kernel source from kernel.org, swaps in the patched `cs420x.c`, and builds only
that module.

### Steps

Run these in a **real terminal**. `sudo` needs a TTY to prompt for your password, so it
can't run from a non-interactive agent shell.

```bash
./install.sh
```

Or do it by hand:

```bash
sudo apt install -y dkms gcc make wget git linux-headers-$(uname -r)
git clone https://github.com/juicecultus/macbook12-audio-driver.git ~/macbook12-audio-driver
cd ~/macbook12-audio-driver && git checkout 75884e2
sudo ./install.cirrus.driver.sh -i
```

Then reboot. GNOME blocks a plain `sudo reboot` with *"Operation inhibited by … user
session inhibited"*. Use the GNOME power menu → Restart, or save your work and run:

```bash
sudo systemctl reboot -i
```

### Verify

```bash
./verify.sh
```

This checks that DKMS has the module installed for the running kernel, that the
loaded module comes from `updates/dkms`, and then plays a short test tone.

## Gotchas

- **Don't delete `~/macbook12-audio-driver`.** The installer symlinks
  `/usr/src/macbook12-audio-0.1` → that clone, and DKMS rebuilds from it on every
  kernel update.
- **Kernel updates** should rebuild the module automatically (that's how it moved from
  `-31` to `-34`). If sound breaks after an update, check `dkms status`, then rerun
  `sudo ./install.cirrus.driver.sh -i` from the clone.
- **Unsigned module.** The kernel logs `module verification failed … tainting kernel`.
  That's expected. This Mac has no Secure Boot, so the module loads anyway. On a
  Secure Boot machine it would need to be signed (MOK).
- **Mixer controls.** With this driver, `amixer` shows only `PCM` and `IEC958`, with no
  `Master`/`Speaker`. That's normal; use the PipeWire/GNOME volume control.
- **UBSAN warning.** An `array-index-out-of-bounds` trace in
  `sound/hda/codecs/generic.c` during probe shows up in `dmesg`. It's noisy but hasn't
  affected playback.
- **Upstream support.** The driver officially targets kernels up to 6.17+. It builds and
  works on 7.0 as-is, but a future kernel could break it.

## Uninstall

```bash
sudo dkms remove macbook12-audio/0.1 --all
cd ~/macbook12-audio-driver && sudo ./install.cirrus.driver.sh -r
```

Then reboot to go back to the stock module.
