<!-- SPDX-License-Identifier: MIT -->
# omamobile-ucm-dubai

Installs the BSD-3-Clause UCM profiles from `sc7280-mainline/alsa-ucm-conf`, commit `3dbb936f0cc85a5d3f12bab12a4578d85768061c`.

The package is not in the first rootfs. HiFi needs real sound-card, routing and low-volume tests. VoiceCall additionally invokes `dummystreamhack@…` user units; that helper is not packaged here and call audio remains unverified.
