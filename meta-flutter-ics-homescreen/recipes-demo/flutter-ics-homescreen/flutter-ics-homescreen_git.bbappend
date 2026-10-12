# ============================================================
# flutter-ics-homescreen — use our fork instead of the upstream
# AGL gerrit source.
# ============================================================
# The recipe lives in meta-agl-demo:
#   recipes-demo/flutter-ics-homescreen/flutter-ics-homescreen_git.bb
# and is pinned by AGL to the upstream `trout` branch.
#
# That recipe already carries everything AGL specific for the
# trout release — ics-homescreen.{toml,yaml}, kvm.conf,
# radio-presets.yaml, the systemd unit, the AOT defines
# (DISABLE_BKG_ANIMATION / ENABLE_VOICE_ASSISTANT) and
# PUBSPEC_IGNORE_LOCKFILE = "1". This bbappend therefore only
# redirects the git source; the rest of the recipe is untouched.
# ============================================================

FLUTTER_ICS_HOMESCREEN_SRC ?= "git://github.com/mukhayyar/flutter-agl.git;protocol=https;branch=master"

# Bump together with the application source in this repository.
FLUTTER_ICS_HOMESCREEN_SRCREV ?= "4be99068c5f54525a1ad94fe014d9f08e7e47f6a"

SRC_URI:remove = "git://gerrit.automotivelinux.org/gerrit/apps/flutter-ics-homescreen;protocol=https;branch=${AGL_BRANCH}"
SRC_URI:prepend = "${FLUTTER_ICS_HOMESCREEN_SRC} "
SRCREV = "${FLUTTER_ICS_HOMESCREEN_SRCREV}"

# ------------------------------------------------------------
# Local development against a working tree — DEVELOPMENT ONLY
# ------------------------------------------------------------
# Uncomment to build straight from a checkout instead of the
# pinned revision.  Never ship an image built this way: the
# resulting binary has no traceable SRCREV.
#
# inherit externalsrc
# EXTERNALSRC = "/absolute/path/to/flutter-agl"
# EXTERNALSRC_BUILD = "${WORKDIR}/build"
# SRC_URI:remove = "${FLUTTER_ICS_HOMESCREEN_SRC}"
