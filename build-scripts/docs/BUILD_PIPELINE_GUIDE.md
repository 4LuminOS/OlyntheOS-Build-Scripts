# LuminOS Modular Build Pipeline (v8.3)

## Overview

The refactored build system is now organized into clean, independent phases that can be run separately, skipped, or debugged individually.

## Build Phases

| Phase | Description | Duration | Reusable |
|-------|-------------|----------|----------|
| **1. Configure** | Bootstrap Debian base system | ~5 min | ✓ |
| **2. Packages** | Install system packages & services | ~10 min | ✓ |
| **3. Desktop** | Install KDE Plasma & utilities | ~15 min | ✓ |
| **4. AI** | Setup Ollama without models | ~2 min | ✓ |
| **5. Cleanup** | Clean caches, logs, temp files | ~2 min | ✓ |
| **6. ISO** | Build ISO image | ~5 min | ✓ |

**Total Time:** ~40 minutes for full build

## Quick Start

### Full Build (All Phases)
```bash
sudo ./build.sh
```

### Run Specific Phase Only
```bash
# Only rebuild desktop
sudo ./build.sh --phase desktop

# Only build ISO (if chroot already exists)
sudo ./build.sh --phase iso
```

### Skip Specific Phases
```bash
# Skip AI setup and cleanup
sudo ./build.sh --skip-ai --skip-cleanup

# Run everything except cleanup
sudo ./build.sh --skip-cleanup
```

### Incremental Build
```bash
# Continue from where you left off (don't clean previous build)
sudo ./build.sh --incremental

# Continue and build only ISO
sudo ./build.sh --incremental --phase iso
```

### Debug Mode
```bash
# Verbose output to console and logs
sudo ./build.sh --debug

# View full build log
tail -f work/logs/build.log

# View specific phase log
tail -f work/logs/04-customize.log
```

## Available Commands

```bash
./build.sh --help              # Show help
./build.sh --list-phases       # List all phases
./build.sh --phase PHASE       # Run only PHASE
./build.sh --skip-PHASE        # Skip PHASE
./build.sh --debug             # Verbose output
./build.sh --incremental       # Don't clean previous build
```

## Build Logs

All build logs are saved to `work/logs/`:

```
work/logs/
├── build.log                  # Main build log
├── debug.log                  # Debug output (if --debug)
├── 02-configure.log          # System configuration
├── 03-desktop.log            # Desktop installation
├── 04-customize.log          # Desktop customization
├── 05-ai.log                 # AI/Ollama setup
├── 06-cleanup.log            # Cleanup phase
├── 07-plymouth.log           # Plymouth theme
├── 08-software.log           # Software installation
├── ollama-download.log       # Ollama binary download
├── iso-squashfs.log          # Squashfs creation
└── iso-grub.log              # GRUB ISO creation
```

## Detailed Usage Examples

### 1. Full Clean Build
```bash
sudo ./build.sh
# Cleans previous build, runs all phases in sequence
# Time: ~40 minutes
# Output: LuminOS-0.2.1-amd64.iso
```

### 2. Fast Iteration (Desktop Development)
```bash
# First time full build
sudo ./build.sh

# Later: modify desktop config, then rebuild just desktop phase
# (chroot is already there from previous build)
sudo ./build.sh --incremental --phase desktop
sudo ./build.sh --incremental --phase cleanup
sudo ./build.sh --incremental --phase iso
```

### 3. Skip Optional Features
```bash
# Build without AI (for minimal ISO)
sudo ./build.sh --skip-ai

# Build core only (skip desktop, AI, Plymouth theme)
sudo ./build.sh --skip-desktop --skip-ai --skip-packages
# (This would just bootstrap and cleanup, not very useful but possible)
```

### 4. Rebuild Only ISO
```bash
# If squashfs and kernel are already in work/iso/live/
sudo ./build.sh --incremental --phase iso

# Much faster than full rebuild (seconds instead of minutes)
```

### 5. Debug Build Issues
```bash
# Enable verbose output
sudo ./build.sh --debug

# Check specific phase log
tail -f work/logs/04-customize.log

# Run individual chroot commands
# (Phase scripts are copied to work/chroot/tmp/)
sudo chroot work/chroot /bin/bash
# Now you're in the chroot environment for manual debugging
```

### 6. CI/CD Pipeline
```bash
#!/bin/bash
# Automated build in CI/CD

set -e

# Full clean build
sudo ./build.sh --debug

# Verify ISO was created
if [ -f "LuminOS-0.2.1-amd64.iso" ]; then
    echo "✓ ISO build successful"
    ISO_SIZE=$(du -h LuminOS-0.2.1-amd64.iso | cut -f1)
    echo "Size: $ISO_SIZE"
else
    echo "✗ ISO build failed"
    exit 1
fi
```

## Phase Details

### Phase 1: Configure
- Bootstraps Debian base system
- Installs kernel and boot utilities
- Configures APT package manager

**Logs:** `work/logs/build.log`
**Duration:** ~5 minutes
**Reusable:** Yes (can skip if chroot exists)

### Phase 2: Packages
- Mounts system filesystems in chroot
- Runs `02-configure-system.sh`:
  - System hostname, timezone, locale
  - User creation (root, liveuser)
  - Basic system configuration

**Logs:** 
- `work/logs/02-configure.log`

**Duration:** ~5 minutes
**Reusable:** Yes

### Phase 3: Desktop
- Installs KDE Plasma desktop
- Customizes desktop environment
- Installs Plymouth boot theme
- Installs software (Zen Browser, utilities)

**Logs:**
- `work/logs/03-desktop.log`
- `work/logs/04-customize.log`
- `work/logs/07-plymouth.log`
- `work/logs/08-software.log`

**Duration:** ~15 minutes
**Reusable:** Yes (can skip to rebuild other phases faster)

### Phase 4: AI
- Downloads Ollama binary (if not cached)
- Copies Ollama to chroot
- Installs AI setup scripts:
  - First-boot AI setup (interactive)
  - Cleanup script
  - RAM detection and recommendations
- Enables Ollama systemd service

**Logs:** `work/logs/05-ai.log`
**Duration:** ~2 minutes
**Reusable:** Yes
**Note:** No models are bundled; users install on first boot

### Phase 5: Cleanup
- Removes APT cache
- Clears system logs
- Removes temporary files
- Resets machine-id
- Removes SSH host keys (regenerate on first boot)
- Cleans application caches
- Runs `06-final-cleanup.sh`

**Logs:** `work/logs/06-cleanup.log`
**Duration:** ~2 minutes
**Reusable:** Yes
**Result:** Clean filesystem ready for ISO

### Phase 6: ISO
- Creates squashfs filesystem layer
- Copies kernel and initrd
- Configures GRUB bootloader
- Generates ISO image
- Cleans up work directory

**Logs:**
- `work/logs/iso-squashfs.log`
- `work/logs/iso-grub.log`

**Duration:** ~5 minutes
**Reusable:** Yes
**Output:** `LuminOS-0.2.1-amd64.iso`

## Troubleshooting

### Build Fails at Phase X

1. Check phase log:
   ```bash
   tail -100 work/logs/0X-*.log
   ```

2. Fix the issue (modify script)

3. Resume build:
   ```bash
   sudo ./build.sh --incremental --phase X
   ```

4. Continue with remaining phases:
   ```bash
   sudo ./build.sh --incremental
   ```

### Chroot Mounts Not Cleaned

If previous build didn't unmount properly:
```bash
sudo umount work/chroot/sys work/chroot/proc work/chroot/dev/pts work/chroot/dev 2>/dev/null || true
sudo rm -rf work
sudo ./build.sh
```

### ISO Too Large

Check what's taking space:
```bash
du -h work/chroot | sort -h | tail -20
```

Then modify appropriate phase script (05, 06) to remove unnecessary packages.

### Out of Disk Space

Clean old builds:
```bash
rm -f LuminOS-0.2.1-amd64.iso.old
sudo rm -rf work/
# Rebuild
```

Or use `--skip-packages` and `--skip-desktop` to build minimal ISO for testing.

## Advanced: Custom Build Workflow

### Example: Test-Driven Build

```bash
#!/bin/bash
# Build just the core for quick testing

set -e

# Full build first time
sudo ./build.sh --skip-desktop

# Modify 05-install-ai.sh if needed

# Rebuild AI phase only
sudo ./build.sh --incremental --phase ai

# Cleanup and create ISO
sudo ./build.sh --incremental --phase cleanup
sudo ./build.sh --incremental --phase iso

# Test ISO
ls -lh LuminOS-0.2.1-amd64.iso
```

### Example: Build Different Variants

```bash
# Variant 1: Full LuminOS with everything
sudo ./build.sh
mv LuminOS-0.2.1-amd64.iso LuminOS-full.iso

# Variant 2: Minimal LuminOS (no AI, no extra software)
sudo ./build.sh --skip-ai
mv LuminOS-0.2.1-amd64.iso LuminOS-minimal.iso

# Variant 3: LuminOS with developer tools
# (would need to modify 08-install-software.sh)
```

## Performance Tips

1. **Cache Ollama Binary:** First build downloads Ollama, subsequent builds reuse it
   - Remove `ollama-linux-amd64` to force re-download

2. **Use Incremental Builds:** Skip full bootstrap if chroot exists
   ```bash
   sudo ./build.sh --incremental --phase desktop
   # Much faster than full build
   ```

3. **Build on SSD:** ISO creation with squashfs is I/O intensive

4. **Use Parallel Processors:** Build script auto-detects CPU count
   - Can't change, but faster CPUs = faster builds

5. **Run During off-peak:** Reduces disk contention if on shared system

## Build System Architecture

```
build.sh (main script)
├── Phase Management
│   ├── should_run_phase()
│   └── Phase definitions
├── Pre-flight Checks
│   ├── check_root()
│   ├── check_dependencies()
│   └── check_disk_space()
├── Phase Execution
│   ├── phase_setup()
│   ├── phase_configure()
│   ├── phase_packages()
│   ├── phase_desktop()
│   ├── phase_ai()
│   ├── phase_cleanup()
│   └── phase_iso()
└── Pipeline Control
    ├── parse_arguments()
    ├── execute_pipeline()
    └── Logging system

Supporting Scripts
├── 02-configure-system.sh     (system config)
├── 03-install-desktop.sh      (KDE Plasma)
├── 04-customize-desktop.sh    (desktop tweaks)
├── 05-install-ai.sh           (Ollama setup)
├── 06-final-cleanup.sh        (pre-ISO cleanup)
├── 07-install-plymouth-theme.sh
├── 08-install-software.sh     (utilities)
├── distro-cleanup.sh          (comprehensive cleanup)
├── luminos-firstboot-ai.sh    (first-boot AI setup)
├── luminos-firstboot-ai.service
└── detect-model-recommendation.sh (RAM detection)
```

## Summary

✓ **Modular:** Each phase independent
✓ **Debuggable:** Detailed logs per phase
✓ **Fast:** Incremental builds, phase skipping
✓ **Flexible:** Run specific phases or combinations
✓ **Production-Ready:** Error handling, comprehensive cleanup
✓ **Maintainable:** Clear code structure, documented phases
