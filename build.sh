#!/bin/bash
################################################################################
# LuminOS Modular Build Pipeline (v8.3)
# 
# Clean, modular ISO build system with independent phases
# Each phase can be run separately, skipped, or debugged independently
#
# Usage:
#   ./build.sh                    # Run full pipeline
#   ./build.sh --phase configure  # Run specific phase
#   ./build.sh --skip-cleanup     # Skip cleanup phase
#   ./build.sh --debug            # Verbose output
#   ./build.sh --list-phases      # Show available phases
#
################################################################################

set -euo pipefail

################################################################################
# Configuration
################################################################################

readonly VERSION="8.3"
readonly BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly WORK_DIR="${BASE_DIR}/work"
readonly CHROOT_DIR="${WORK_DIR}/chroot"
readonly ISO_DIR="${WORK_DIR}/iso"
readonly LOGS_DIR="${WORK_DIR}/logs"
readonly ISO_NAME="LuminOS-0.2.1-amd64.iso"
readonly OLLAMA_VERSION="v0.1.32"
readonly OLLAMA_BINARY="${BASE_DIR}/ollama-linux-amd64"

# Build options
DEBUG=false
SKIP_PHASES=()
RUN_ONLY_PHASE=""
CLEAN_START=true

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

################################################################################
# Logging & Output
################################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*" | tee -a "${LOGS_DIR}/build.log"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $*" | tee -a "${LOGS_DIR}/build.log"
}

log_warn() {
    echo -e "${YELLOW}[⚠]${NC} $*" | tee -a "${LOGS_DIR}/build.log"
}

log_error() {
    echo -e "${RED}[✗]${NC} $*" | tee -a "${LOGS_DIR}/build.log"
}

log_header() {
    echo | tee -a "${LOGS_DIR}/build.log"
    echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}" | tee -a "${LOGS_DIR}/build.log"
    echo -e "${CYAN}║  $*" | tee -a "${LOGS_DIR}/build.log"
    echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}" | tee -a "${LOGS_DIR}/build.log"
    echo | tee -a "${LOGS_DIR}/build.log"
}

debug() {
    if [ "$DEBUG" = true ]; then
        echo -e "${YELLOW}[DEBUG]${NC} $*" | tee -a "${LOGS_DIR}/debug.log"
    fi
}

################################################################################
# Phase Management
################################################################################

declare -A PHASES=(
    ["setup"]="Initialize build environment"
    ["configure"]="Configure system base"
    ["packages"]="Install system packages"
    ["desktop"]="Install desktop environment"
    ["ai"]="Setup AI/Ollama"
    ["cleanup"]="Clean system for ISO"
    ["iso"]="Build ISO image"
)

should_run_phase() {
    local phase="$1"
    
    # If specific phase requested, only run that one
    if [ -n "$RUN_ONLY_PHASE" ] && [ "$RUN_ONLY_PHASE" != "$phase" ]; then
        return 1
    fi
    
    # Check if phase is in skip list
    for skip in "${SKIP_PHASES[@]}"; do
        if [ "$skip" = "$phase" ]; then
            return 1
        fi
    done
    
    return 0
}

list_phases() {
    echo -e "${CYAN}Available Build Phases:${NC}"
    echo
    for phase in configure packages desktop ai cleanup iso; do
        echo "  ${CYAN}${phase}${NC} - ${PHASES[$phase]}"
    done
    echo
}

################################################################################
# Pre-flight Checks
################################################################################

check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        log_error "This script must be run as root"
        exit 1
    fi
    log_success "Running as root"
}

check_dependencies() {
    log_info "Checking build dependencies..."
    
    local missing=()
    local required_commands=(
        "debootstrap"
        "mksquashfs"
        "xorriso"
        "grub-mkrescue"
        "curl"
        "rsync"
    )
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        log_warn "Missing commands: ${missing[*]}"
        log_info "Installing missing dependencies..."
        apt-get update
        apt-get install -y debootstrap squashfs-tools xorriso grub-pc-bin grub-efi-amd64-bin mtools curl rsync
    fi
    
    log_success "All dependencies available"
}

check_disk_space() {
    log_info "Checking available disk space..."
    
    local available_gb
    available_gb=$(df "$BASE_DIR" | tail -1 | awk '{printf "%d", $4 / 1024 / 1024}')
    
    if [ "$available_gb" -lt 10 ]; then
        log_warn "Low disk space: ${available_gb}GB available (need ~10GB). Continuing anyway..."
    fi
    
    log_success "Disk space OK (${available_gb}GB available)"
}

################################################################################
# Phase: Setup
################################################################################

phase_setup() {
    log_header "PHASE 1: Setup Build Environment"
    
    log_info "Cleaning previous build..."
    
    # Unmount previous chroot
    for mount_point in sys proc dev/pts dev; do
        local full_path="${CHROOT_DIR}/${mount_point}"
        if mountpoint -q "$full_path" 2>/dev/null; then
            log_info "Unmounting $mount_point..."
            sudo umount "$full_path" || log_warn "Failed to unmount $mount_point"
        fi
    done
    
    # Kill Ollama processes
    pkill -f "ollama serve" || true
    
    # Clean previous build if requested
    if [ "$CLEAN_START" = true ]; then
        log_info "Removing previous build artifacts..."
        rm -rf "${WORK_DIR}"
        rm -f "${BASE_DIR}/${ISO_NAME}"
    fi
    
    # Create directory structure
    log_info "Creating directory structure..."
    mkdir -p "${CHROOT_DIR}" "${ISO_DIR}/live" "${ISO_DIR}/boot/grub" "${LOGS_DIR}"
    
    log_success "Setup complete"
}

################################################################################
# Phase: Configure System
################################################################################

phase_configure() {
    log_header "PHASE 2: Configure System Base"
    
    log_info "Installing build dependencies..."
    check_dependencies
    
    log_info "Bootstrapping Debian base system..."
    debootstrap \
        --arch=amd64 \
        --components=main,contrib,non-free-firmware \
        --include=linux-image-amd64,live-boot,systemd-sysv \
        trixie "${CHROOT_DIR}" http://ftp.debian.org/debian/
    
    log_info "Configuring APT..."
    mkdir -p "${CHROOT_DIR}/etc/apt/apt.conf.d"
    echo 'Acquire::IndexTargets::deb::Contents-deb "false";' > "${CHROOT_DIR}/etc/apt/apt.conf.d/99-no-contents"
    
    log_success "System configured"
}

################################################################################
# Phase: Install Packages
################################################################################

phase_packages() {
    log_header "PHASE 3: Install System Packages"
    
    log_info "Mounting system filesystems..."
    mount --bind /dev "${CHROOT_DIR}/dev"
    mount --bind /dev/pts "${CHROOT_DIR}/dev/pts"
    mount -t proc /proc "${CHROOT_DIR}/proc"
    mount -t sysfs /sys "${CHROOT_DIR}/sys"
    
    log_info "Running system configuration script..."
    cp "${BASE_DIR}/phases/02-configure-system.sh" "${CHROOT_DIR}/tmp/"
    chmod +x "${CHROOT_DIR}/tmp/02-configure-system.sh"
    chroot "${CHROOT_DIR}" /tmp/02-configure-system.sh 2>&1 | tee -a "${LOGS_DIR}/02-configure.log"
    
    log_success "System packages installed"
}

################################################################################
# Phase: Install Desktop
################################################################################

phase_desktop() {
    log_header "PHASE 4: Install Desktop Environment"
    
    log_info "Running desktop installation script..."
    cp "${BASE_DIR}/phases/03-install-desktop.sh" "${CHROOT_DIR}/tmp/"
    cp "${BASE_DIR}/phases/04-customize-desktop.sh" "${CHROOT_DIR}/tmp/"
    cp "${BASE_DIR}/phases/07-install-plymouth-theme.sh" "${CHROOT_DIR}/tmp/"
    cp "${BASE_DIR}/phases/08-install-software.sh" "${CHROOT_DIR}/tmp/"
    
    chmod +x "${CHROOT_DIR}/tmp/"{03,04,07,08}*.sh
    
    chroot "${CHROOT_DIR}" /tmp/03-install-desktop.sh 2>&1 | tee -a "${LOGS_DIR}/03-desktop.log"
    chroot "${CHROOT_DIR}" /tmp/04-customize-desktop.sh 2>&1 | tee -a "${LOGS_DIR}/04-customize.log"
    chroot "${CHROOT_DIR}" /tmp/07-install-plymouth-theme.sh 2>&1 | tee -a "${LOGS_DIR}/07-plymouth.log"
    chroot "${CHROOT_DIR}" /tmp/08-install-software.sh 2>&1 | tee -a "${LOGS_DIR}/08-software.log"
    
    log_success "Desktop environment installed"
}

################################################################################
# Phase: Install AI/Ollama
################################################################################

phase_ai() {
    log_header "PHASE 5: Setup AI Runtime (Ollama)"
    
    log_info "Preparing Ollama binary..."
    
    # Download Ollama if not present
    if [ ! -f "$OLLAMA_BINARY" ]; then
        log_info "Downloading Ollama binary..."
        curl -fL "https://github.com/ollama/ollama/releases/download/${OLLAMA_VERSION}/ollama-linux-amd64" \
            -o "$OLLAMA_BINARY" 2>&1 | tee -a "${LOGS_DIR}/ollama-download.log"
        
        log_info "Verifying Ollama binary checksum..."
        local sha256file
        sha256file=$(mktemp)
        if curl -fsSL "https://github.com/ollama/ollama/releases/download/${OLLAMA_VERSION}/sha256sum.txt" \
                -o "$sha256file" 2>/dev/null; then
            if grep -q "ollama-linux-amd64" "$sha256file"; then
                local expected_hash actual_hash
                expected_hash=$(grep "ollama-linux-amd64" "$sha256file" | awk '{print $1}')
                actual_hash=$(sha256sum "$OLLAMA_BINARY" | awk '{print $1}')
                if [ "$expected_hash" != "$actual_hash" ]; then
                    log_error "Ollama binary checksum mismatch! Expected: $expected_hash  Got: $actual_hash"
                    rm -f "$OLLAMA_BINARY" "$sha256file"
                    exit 1
                fi
                log_success "Ollama checksum verified"
            else
                log_warn "ollama-linux-amd64 entry not found in sha256sum.txt — skipping verification"
            fi
        else
            log_warn "Could not download sha256sum.txt — skipping checksum verification"
        fi
        rm -f "$sha256file"
        chmod +x "$OLLAMA_BINARY"
    else
        log_info "Using cached Ollama binary"
    fi
    
    log_info "Copying assets and binaries..."
    mkdir -p "${CHROOT_DIR}/usr/share/wallpapers/luminos"
    cp "${BASE_DIR}"/assets/* "${CHROOT_DIR}/usr/share/wallpapers/luminos/" 2>/dev/null || true
    cp "$OLLAMA_BINARY" "${CHROOT_DIR}/usr/local/bin/ollama"
    
    log_info "Running AI setup script..."
    cp "${BASE_DIR}/phases/05-install-ai.sh" "${CHROOT_DIR}/tmp/"
    cp "${BASE_DIR}/utilities/distro-cleanup.sh" "${CHROOT_DIR}/usr/local/bin/"
    cp "${BASE_DIR}/utilities/luminos-firstboot-ai.sh" "${CHROOT_DIR}/usr/local/bin/"
    cp "${BASE_DIR}/services/luminos-firstboot-ai.service" "${CHROOT_DIR}/etc/systemd/system/"
    cp "${BASE_DIR}/utilities/detect-model-recommendation.sh" "${CHROOT_DIR}/usr/local/bin/"
    
    chmod +x "${CHROOT_DIR}/tmp/05-install-ai.sh"
    chmod +x "${CHROOT_DIR}/usr/local/bin/"{distro-cleanup,luminos-firstboot-ai,detect-model-recommendation}.sh
    
    chroot "${CHROOT_DIR}" /tmp/05-install-ai.sh 2>&1 | tee -a "${LOGS_DIR}/05-ai.log"
    
    log_success "AI runtime configured"
}

################################################################################
# Phase: Cleanup
################################################################################

phase_cleanup() {
    log_header "PHASE 6: Clean System for ISO"
    
    log_info "Running comprehensive cleanup..."
    cp "${BASE_DIR}/phases/06-final-cleanup.sh" "${CHROOT_DIR}/tmp/"
    chmod +x "${CHROOT_DIR}/tmp/06-final-cleanup.sh"
    chroot "${CHROOT_DIR}" /tmp/06-final-cleanup.sh 2>&1 | tee -a "${LOGS_DIR}/06-cleanup.log"
    
    log_info "Unmounting system filesystems..."
    umount "${CHROOT_DIR}/sys"
    umount "${CHROOT_DIR}/proc"
    umount "${CHROOT_DIR}/dev/pts"
    umount "${CHROOT_DIR}/dev"
    
    log_success "System cleaned and unmounted"
}

################################################################################
# Phase: Build ISO
################################################################################

phase_iso() {
    log_header "PHASE 7: Build ISO Image"
    
    log_info "Creating filesystem squashfs..."
    mksquashfs "${CHROOT_DIR}" "${ISO_DIR}/live/filesystem.squashfs" \
        -e boot -comp zstd -processors "$(nproc)" 2>&1 | tee -a "${LOGS_DIR}/iso-squashfs.log"
    
    log_info "Copying kernel and initrd..."
    cp "${CHROOT_DIR}/boot"/vmlinuz* "${ISO_DIR}/live/vmlinuz"
    cp "${CHROOT_DIR}/boot"/initrd.img* "${ISO_DIR}/live/initrd.img"
    
    log_info "Configuring GRUB bootloader..."
    cat > "${ISO_DIR}/boot/grub/grub.cfg" << 'GRUBCFG'
set default="0"
set timeout=5
menuentry "LuminOS v0.2.1 Live" {
    linux /live/vmlinuz boot=live quiet splash
    initrd /live/initrd.img
}
GRUBCFG
    
    log_info "Generating ISO image..."
    grub-mkrescue -o "${BASE_DIR}/${ISO_NAME}" "${ISO_DIR}" 2>&1 | tee -a "${LOGS_DIR}/iso-grub.log"
    
    local iso_size
    iso_size=$(du -h "${BASE_DIR}/${ISO_NAME}" | cut -f1)
    log_success "ISO built successfully: $iso_size"
    
    # Cleanup work directory
    log_info "Cleaning up build artifacts..."
    rm -rf "${WORK_DIR}"
}

################################################################################
# Pipeline Execution
################################################################################

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --debug)
                DEBUG=true
                shift
                ;;
            --phase)
                RUN_ONLY_PHASE="$2"
                shift 2
                ;;
            --skip-*)
                phase_name="${1#--skip-}"
                SKIP_PHASES+=("$phase_name")
                shift
                ;;
            --list-phases)
                list_phases
                exit 0
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            --incremental)
                CLEAN_START=false
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
}

show_help() {
    cat << EOF
${CYAN}LuminOS Modular Build Pipeline v${VERSION}${NC}

${BLUE}Usage:${NC}
  $(basename "$0") [OPTIONS]

${BLUE}Options:${NC}
  --phase PHASE          Run only specified phase
  --skip-PHASE           Skip specified phase (can use multiple times)
  --debug                Enable debug output
  --incremental          Don't clean previous build (continue from where left off)
  --list-phases          Show available phases
  --help                 Show this help message

${BLUE}Examples:${NC}
  $(basename "$0")                      # Full build
  $(basename "$0") --phase desktop      # Only build desktop phase
  $(basename "$0") --skip-ai --skip-cleanup
  $(basename "$0") --debug              # Verbose output
  $(basename "$0") --incremental --phase iso  # Continue and build ISO

${BLUE}Phases:${NC}
EOF
    
    for phase in configure packages desktop ai cleanup iso; do
        echo "  ${CYAN}${phase}${NC} - ${PHASES[$phase]}"
    done
}

execute_pipeline() {
    log_header "LuminOS Build Pipeline v${VERSION}"
    
    local phase_order=(configure packages desktop ai cleanup iso)
    local phases_run=0
    local phases_skipped=0
    
    # Execute each phase in order
    for phase in "${phase_order[@]}"; do
        if should_run_phase "$phase"; then
            log_info "Starting phase: ${CYAN}$phase${NC}"
            
            case "$phase" in
                configure) phase_configure ;;
                packages) phase_packages ;;
                desktop) phase_desktop ;;
                ai) phase_ai ;;
                cleanup) phase_cleanup ;;
                iso) phase_iso ;;
            esac
            
            phases_run=$((phases_run + 1))
        else
            log_warn "Skipping phase: $phase"
            phases_skipped=$((phases_skipped + 1))
        fi
    done
    
    log_header "Build Complete!"
    log_success "Phases executed: $phases_run"
    log_info "Phases skipped: $phases_skipped"
    
    if [ -f "${BASE_DIR}/${ISO_NAME}" ]; then
        local iso_size
        iso_size=$(du -h "${BASE_DIR}/${ISO_NAME}" | cut -f1)
        log_success "ISO ready: ${BASE_DIR}/${ISO_NAME} (${iso_size})"
    fi
    
    log_info "Full build log: ${LOGS_DIR}/build.log"
}

################################################################################
# Main
################################################################################

main() {
    # Setup logging
    mkdir -p "${LOGS_DIR}"
    exec 1> >(tee -a "${LOGS_DIR}/build.log")
    exec 2>&1
    
    check_root
    parse_arguments "$@"
    
    # Always do setup first
    phase_setup
    check_disk_space
    
    # Execute pipeline
    execute_pipeline
}

main "$@"
