#!/bin/bash
################################################################################
# LuminOS Build Pipeline - Quick Reference
################################################################################

cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════╗
║                 LuminOS Modular Build Pipeline v8.3                      ║
║                       QUICK REFERENCE GUIDE                              ║
╚══════════════════════════════════════════════════════════════════════════╝

PHASES (in order):
  1. configure  → Bootstrap Debian base system
  2. packages   → Install system packages  
  3. desktop    → Install KDE Plasma
  4. ai         → Setup Ollama (no models bundled)
  5. cleanup    → Clean system for ISO
  6. iso        → Build final ISO image

═══════════════════════════════════════════════════════════════════════════

COMMON COMMANDS:

Full Build (all phases):
  $ sudo ./build.sh

Run specific phase:
  $ sudo ./build.sh --phase desktop
  $ sudo ./build.sh --phase iso

Skip phases:
  $ sudo ./build.sh --skip-ai --skip-cleanup
  $ sudo ./build.sh --skip-desktop

Continue previous build (incremental):
  $ sudo ./build.sh --incremental
  $ sudo ./build.sh --incremental --phase iso

Debug mode (verbose):
  $ sudo ./build.sh --debug
  $ tail -f work/logs/build.log

═══════════════════════════════════════════════════════════════════════════

TYPICAL WORKFLOWS:

1. FULL BUILD (First Time)
   $ sudo ./build.sh
   Time: ~40 minutes

2. ITERATE ON DESKTOP
   # First time full build
   $ sudo ./build.sh
   
   # Modify 04-customize-desktop.sh
   # Edit: vi 04-customize-desktop.sh
   
   # Rebuild just desktop
   $ sudo ./build.sh --incremental --phase desktop
   $ sudo ./build.sh --incremental --phase cleanup
   $ sudo ./build.sh --incremental --phase iso
   Time: ~10 minutes

3. REBUILD ISO ONLY
   # (if filesystem already created)
   $ sudo ./build.sh --incremental --phase iso
   Time: ~5 minutes

4. DEBUG BUILD FAILURE
   $ sudo ./build.sh --debug
   $ tail -100 work/logs/XX-phase.log
   $ # Fix issue
   $ sudo ./build.sh --incremental

5. MINIMAL BUILD
   $ sudo ./build.sh --skip-ai
   or
   $ sudo ./build.sh --skip-desktop

═══════════════════════════════════════════════════════════════════════════

LOG FILES:

Main build log:
  work/logs/build.log
  
Phase-specific logs:
  work/logs/02-configure.log
  work/logs/03-desktop.log
  work/logs/04-customize.log
  work/logs/05-ai.log
  work/logs/06-cleanup.log
  work/logs/07-plymouth.log
  work/logs/08-software.log
  work/logs/iso-squashfs.log
  work/logs/iso-grub.log

Debug log (if --debug):
  work/logs/debug.log

═══════════════════════════════════════════════════════════════════════════

MANUAL CHROOT ACCESS:

# If you need to manually debug inside the build environment
$ sudo chroot work/chroot /bin/bash

# Mount filesystems first if needed
$ sudo mount --bind /dev work/chroot/dev
$ sudo mount -t proc /proc work/chroot/proc
$ sudo mount -t sysfs /sys work/chroot/sys

═══════════════════════════════════════════════════════════════════════════

KEY FEATURES:

✓ Modular phases (run independently)
✓ Comprehensive logging per phase
✓ Error handling and recovery
✓ Incremental builds (skip previous phases)
✓ Debug mode for troubleshooting
✓ Phase skipping for customization
✓ No AI models bundled (users install on first boot)
✓ Clean system before ISO creation
✓ Production-ready

═══════════════════════════════════════════════════════════════════════════

HELP:

$ ./build.sh --help              Full help with examples
$ ./build.sh --list-phases       Show available phases
$ cat BUILD_PIPELINE_GUIDE.md    Detailed documentation

═══════════════════════════════════════════════════════════════════════════

BUILD TIMES (approximate):

Full clean build:      ~40 minutes
  - Configure:        ~5 min
  - Packages:         ~5 min
  - Desktop:          ~15 min
  - AI:               ~2 min
  - Cleanup:          ~2 min
  - ISO:              ~5 min

Incremental rebuild:   ~10-15 minutes
  (skips configure, packages)

ISO only rebuild:      ~5 minutes
  (if filesystem exists)

═══════════════════════════════════════════════════════════════════════════

EOF
