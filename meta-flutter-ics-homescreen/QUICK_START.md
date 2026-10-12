# Flutter ICS Homescreen — build notes for AGL trout

`meta-flutter-ics-homescreen` is a small customisation layer that appends the
AGL Flutter ICS homescreen recipe shipped by `meta-agl-demo`, so bitbake pulls
the application source from this repository instead of AGL gerrit.

```
meta-flutter-ics-homescreen/
├── conf/
│   └── layer.conf
├── recipes-demo/
│   ├── flutter-ics-homescreen/
│   │   └── flutter-ics-homescreen_git.bbappend   # points the recipe at this fork
│   └── meta-flatpak/
│       └── meta-flatpak.bbappend                 # optional, needs the external meta-flatpak layer
└── QUICK_START.md
```

Target release: **AGL `trout`** — Yocto **5.0 scarthgap** (poky 5.0.15),
`meta-flutter` for the Flutter embedder (`flutter-auto`, `flutter-app` class).

## 1. Get the AGL sources

```bash
mkdir -p ~/AGL && cd ~/AGL
repo init -b trout -u https://gerrit.automotivelinux.org/gerrit/AGL/AGL-repo
repo sync -j8
source meta-agl/scripts/aglsetup.sh -m raspberrypi4 -b build-rpi4 agl-demo agl-devel
```

Cluster in this repository, then add the layer:

```bash
cd ~/AGL
git clone https://github.com/mukhayyar/flutter-agl.git
cd build-rpi4
bitbake-layers add-layer ../../flutter-agl/meta-flutter-ics-homescreen
bitbake-layers show-layers      # meta-flutter-ics-homescreen must be listed
```

## 2. Build

```bash
bitbake agl-ivi-demo-flutter      # full IVI image
bitbake flutter-ics-homescreen    # just the homescreen package
```

Rebuild the app alone while iterating:

```bash
bitbake -c cleansstate flutter-ics-homescreen
bitbake flutter-ics-homescreen
bitbake agl-ivi-demo-flutter
```

## 3. Source selection

The bbappend sets two variables (override either in `local.conf`):

| Variable | Default |
|---|---|
| `FLUTTER_ICS_HOMESCREEN_SRC` | `git://github.com/mukhayyar/flutter-agl.git;protocol=https;branch=master` |
| `FLUTTER_ICS_HOMESCREEN_SRCREV` | pinned commit |

Bump `FLUTTER_ICS_HOMESCREEN_SRCREV` whenever the application source in this
repository changes, otherwise bitbake keeps building the old revision.

For local development, the bbappend carries a commented `externalsrc` block that
builds straight from a working tree instead. Never ship an image built that way —
it has no traceable `SRCREV`.

## 4. Runtime configuration (do not duplicate)

The AGL recipe already installs the trout configuration files —
`ics-homescreen.toml`, `ics-homescreen.yaml`, `radio-presets.yaml`,
`kvm.conf`, the VIS token and the systemd unit — and sets
`PUBSPEC_IGNORE_LOCKFILE = "1"` so `meta-flutter` regenerates `pubspec.lock`
for the Yocto Flutter SDK. Do not override these from this layer.

KUKSA configuration lives in `/etc/xdg/AGL/ics-homescreen.yaml` on the target:

```bash
journalctl -u flutter-ics-homescreen.service
```
