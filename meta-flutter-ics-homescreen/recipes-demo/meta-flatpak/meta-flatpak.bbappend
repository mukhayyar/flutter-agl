# ============================================================
# Flatpak repository configuration — OPTIONAL
# ============================================================
# This bbappend only has an effect when the *external* meta-flatpak
# layer (https://github.com/flatpak/meta-flatpak) is present in
# bblayers.conf and provides meta-flatpak.bb.
#
# The AGL trout manifest does NOT include meta-flatpak: flatpak
# (1.15.8) and ostree (2024.5) come from meta-openembedded/meta-oe,
# and remote repositories are registered on the target by
# meta-agl-app-store's flatpak-predefined-repos recipe.  Without the
# external layer bitbake simply reports "No recipes available for
# .../meta-flatpak.bbappend" and ignores this file.
# ============================================================

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += " \
    file://flathub.key \
    file://flathub.url \
    # file://my-project.key \
    # file://my-project.url \
"

do_install:append() {
    install -d ${D}${sysconfdir}/flatpak-session

    # --- Install Flathub Remote ---
    install -m 0644 ${WORKDIR}/flathub.key ${D}${sysconfdir}/flatpak-session/
    install -m 0644 ${WORKDIR}/flathub.url ${D}${sysconfdir}/flatpak-session/

    # --- Install Your Custom Remote (Uncomment when ready) ---
    # install -m 0644 ${WORKDIR}/my-project.key ${D}${sysconfdir}/flatpak-session/
    # install -m 0644 ${WORKDIR}/my-project.url ${D}${sysconfdir}/flatpak-session/
}
