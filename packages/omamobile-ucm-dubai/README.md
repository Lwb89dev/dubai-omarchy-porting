<!-- SPDX-License-Identifier: MIT -->
# omamobile-ucm-dubai

Installs the BSD-3-Clause UCM profiles from `sc7280-mainline/alsa-ucm-conf`, commit `3dbb936f0cc85a5d3f12bab12a4578d85768061c`, extended with `SectionDevice."Speaker"` in `VoiceCall.conf` for hands-free speakerphone calls.

Depends on `dummystreamhack` to keep the hostless `VoiceMMode1` (`hw:0,5`) Q6Voice streams open while `Voice Call` is active. Both Earpiece (`Receiver`) and Speaker (`Music` stereo) call routing were verified on hardware on 2026-11-22.
