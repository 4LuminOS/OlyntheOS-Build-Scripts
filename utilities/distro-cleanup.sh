#!/bin/bash
################################################################################
# Production-Ready Linux Distro Build Cleanup Script
# Safely cleans a system before ISO packaging
# 
# Usage: sudo ./distro-cleanup.sh [OPTIONS]
# Options:
#   -v, --verbose    Show detailed output for each step
#   -d, --dry-run    Show what would be deleted without deleting
#   -h, --help       Show this help message
################################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
VERBOSE=false
DRY_RUN=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/cleanup-$(date +%Y%m%d-%H%M%S).log"

# Initialize log
exec 1> >(tee -a "${LOG_FILE}")
exec 2>&1

################################################################################
# Utility Functions
################################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

safe_rm() {
    local target="$1"
    local description="${2:-}"
    
    if [ ! -e "$target" ]; then
        return 0
    fi
    
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY-RUN] Would remove: $target $description"
        return 0
    fi
    
    if [ "$VERBOSE" = true ]; then
        log_info "Removing: $target $description"
    fi
    
    rm -rf "$target" 2>/dev/null || log_warning "Failed to remove: $target"
}

safe_truncate() {
    local target="$1"
    local description="${2:-}"
    
    if [ ! -f "$target" ]; then
        return 0
    fi
    
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY-RUN] Would truncate: $target $description"
        return 0
    fi
    
    if [ "$VERBOSE" = true ]; then
        log_info "Truncating: $target $description"
    fi
    
    truncate -s 0 "$target" 2>/dev/null || log_warning "Failed to truncate: $target"
}

safe_exec() {
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY-RUN] Would execute: $*"
        return 0
    fi
    
    if [ "$VERBOSE" = true ]; then
        log_info "Executing: $*"
    fi
    
    "$@" 2>/dev/null || log_warning "Command failed: $*"
}

################################################################################
# Safety Checks
################################################################################

check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
    log_success "Running as root"
}

check_in_chroot() {
    # Verify we're in a build environment (chroot or container)
    if [ ! -f /etc/hostname ] && [ ! -f /etc/os-release ]; then
        log_error "Unable to verify system environment"
        return 1
    fi
    return 0
}

################################################################################
# Cleanup Functions
################################################################################

cleanup_apt() {
    log_info "=== Cleaning APT package manager ==="
    
    # Remove cached packages
    safe_exec apt-get clean
    safe_exec apt-get autoclean
    
    # Remove package lists
    safe_rm "/var/lib/apt/lists/*" "(package lists)"
    
    # Rebuild broken lists
    if [ "$DRY_RUN" = false ]; then
        mkdir -p /var/lib/apt/lists/partial
        log_success "APT cache cleaned"
    fi
}

cleanup_package_cache() {
    log_info "=== Cleaning package manager caches ==="
    
    safe_rm "/var/cache/apt" "(apt cache)"
    safe_rm "/var/cache/apt/archives/*" "(old packages)"
    safe_rm "/var/cache/dnf" "(dnf cache)"
    safe_rm "/var/cache/yum" "(yum cache)"
    
    log_success "Package caches cleaned"
}

cleanup_temporary_files() {
    log_info "=== Cleaning temporary files ==="
    
    safe_rm "/tmp/*" "(temporary files)"
    safe_rm "/tmp/.*" "(hidden temp files)"
    safe_rm "/var/tmp/*" "(var temp files)"
    safe_rm "/var/cache/man/*" "(man cache)"
    
    # Preserve critical temp directories
    if [ "$DRY_RUN" = false ]; then
        mkdir -p /tmp /var/tmp
        chmod 1777 /tmp /var/tmp
    fi
    
    log_success "Temporary files cleaned"
}

cleanup_logs() {
    log_info "=== Cleaning system logs ==="
    
    # Truncate log files
    find /var/log -type f \( -name "*.log" -o -name "*.gz" -o -name "*.1" -o -name "*.2*" \) | while read -r logfile; do
        safe_truncate "$logfile" "(log file)"
    done
    
    # Special log files
    safe_truncate "/var/log/lastlog" "(lastlog)"
    safe_truncate "/var/log/wtmp" "(wtmp)"
    safe_truncate "/var/log/btmp" "(btmp)"
    safe_truncate "/var/log/faillog" "(faillog)"
    
    # Clean systemd journal
    if command -v journalctl &> /dev/null; then
        safe_exec journalctl --vacuum=time=1d
        safe_exec journalctl --vacuum=size=1M
    fi
    
    log_success "Logs cleaned"
}

cleanup_bash_history() {
    log_info "=== Cleaning bash history ==="
    
    # Root history
    safe_rm "/root/.bash_history" "(root bash history)"
    
    # User histories
    for user_home in /home/*/; do
        if [ -d "$user_home" ]; then
            safe_rm "${user_home}.bash_history" "(user bash history)"
            safe_rm "${user_home}.bash_sessions" "(bash sessions)"
        fi
    done
    
    # Live user history
    safe_rm "/home/liveuser/.bash_history" "(liveuser history)"
    
    log_success "Bash history cleaned"
}

cleanup_shell_history() {
    log_info "=== Cleaning shell history ==="
    
    # Zsh history
    safe_rm "/root/.zsh_history" "(root zsh history)"
    safe_rm "/home/*/.zsh_history" "(user zsh history)"
    
    # Fish history
    safe_rm "/root/.local/share/fish/fish_history" "(root fish history)"
    safe_rm "/home/*/.local/share/fish/fish_history" "(user fish history)"
    
    log_success "Shell history cleaned"
}

cleanup_machine_id() {
    log_info "=== Resetting machine-id ==="
    
    # Reset machine-id (will regenerate on first boot)
    safe_truncate "/etc/machine-id" "(machine-id)"
    
    # Reset dbus machine-id
    mkdir -p /var/lib/dbus
    safe_rm "/var/lib/dbus/machine-id" "(dbus machine-id)"
    
    if [ "$DRY_RUN" = false ]; then
        # Recreate symlink
        ln -sf /etc/machine-id /var/lib/dbus/machine-id || true
        log_success "Machine-id reset"
    fi
}

cleanup_ssh_keys() {
    log_info "=== Removing SSH host keys (will regenerate on first boot) ==="
    
    safe_rm "/etc/ssh/ssh_host_*" "(SSH host keys)"
    safe_rm "/root/.ssh" "(root SSH keys)"
    
    for user_home in /home/*/; do
        if [ -d "$user_home" ]; then
            safe_rm "${user_home}.ssh" "(user SSH keys)"
        fi
    done
    
    log_success "SSH keys removed (safe to regenerate)"
}

cleanup_network_config() {
    log_info "=== Cleaning network configuration ==="
    
    # Clean DHCP leases
    safe_rm "/var/lib/dhcp/*" "(DHCP leases)"
    safe_rm "/var/lib/dhclient/*" "(DHCP client)"
    
    # Clean interface config
    safe_truncate "/etc/udev/rules.d/70-persistent-net.rules" "(persistent net rules)"
    
    log_success "Network configuration cleaned"
}

cleanup_systemd() {
    log_info "=== Cleaning systemd data ==="
    
    safe_rm "/var/lib/systemd/coredumps/*" "(coredumps)"
    safe_rm "/var/lib/systemd/random-seed" "(random seed)"
    safe_rm "/run/log/journal/*" "(journal files)"
    
    log_success "Systemd data cleaned"
}

cleanup_caches() {
    log_info "=== Cleaning application caches ==="
    
    safe_rm "/var/cache/fontconfig" "(fontconfig cache)"
    safe_rm "/var/cache/ldconfig" "(ldconfig cache)"
    safe_rm "/var/cache/man" "(man cache)"
    safe_rm "/var/cache/locate" "(locate database)"
    
    for user_home in /home/*/ /root/; do
        if [ -d "$user_home" ]; then
            safe_rm "${user_home}.cache" "(user cache)"
            safe_rm "${user_home}.local/share/recently-used.xbel" "(recently used)"
        fi
    done
    
    log_success "Application caches cleaned"
}

cleanup_user_data() {
    log_info "=== Cleaning temporary user data ==="
    
    safe_rm "/root/.Xauthority" "(X authority)"
    safe_rm "/root/.ICEauthority" "(ICE authority)"
    safe_rm "/root/.dbus" "(dbus session)"
    
    for user_home in /home/*/; do
        if [ -d "$user_home" ]; then
            safe_rm "${user_home}.Xauthority" "(user X authority)"
            safe_rm "${user_home}.ICEauthority" "(user ICE authority)"
            safe_rm "${user_home}.dbus" "(user dbus session)"
        fi
    done
    
    log_success "User data cleaned"
}

cleanup_udev() {
    log_info "=== Cleaning udev database ==="
    
    safe_rm "/etc/udev/rules.d/.udevdb" "(udev database)"
    safe_rm "/run/udev/tags.d" "(udev tags)"
    safe_rm "/var/lib/udev/hwdb.bin" "(udev hwdb)"
    
    log_success "Udev database cleaned"
}

cleanup_package_manager_database() {
    log_info "=== Cleaning package database ==="
    
    # APT
    safe_exec apt-get -y purge --auto-remove || true
    
    # DNF/YUM (if present)
    if command -v dnf &> /dev/null; then
        safe_exec dnf clean all || true
    elif command -v yum &> /dev/null; then
        safe_exec yum clean all || true
    fi
    
    log_success "Package database cleaned"
}

cleanup_misc() {
    log_info "=== Cleaning miscellaneous files ==="
    
    # Remove any .Xauthority files
    safe_rm "/var/X11" "(X11 runtime)"
    
    # Clean package manager lock files
    safe_rm "/var/cache/apt/pkgcache.bin" "(package cache)"
    safe_rm "/var/cache/apt/srcpkgcache.bin" "(source package cache)"
    
    # Clean installer/provisioning scripts (if present)
    safe_rm "/var/lib/cloud" "(cloud-init data)"
    safe_rm "/etc/cloud/instances" "(cloud instances)"
    
    log_success "Miscellaneous files cleaned"
}

################################################################################
# Reporting
################################################################################

show_help() {
    head -30 "$0" | tail -9
}

generate_report() {
    log_info "=== Cleanup Report ==="
    
    if [ "$DRY_RUN" = true ]; then
        log_warning "This was a DRY-RUN - no files were actually deleted"
    fi
    
    log_success "Cleanup completed!"
    log_info "Log file saved to: $LOG_FILE"
    
    if [ -f "$LOG_FILE" ]; then
        local lines=$(wc -l < "$LOG_FILE")
        log_info "Operations logged: $lines lines"
    fi
}

################################################################################
# Main Execution
################################################################################

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

main() {
    parse_arguments "$@"
    
    echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Production-Ready Distro Build Cleanup Script      ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
    echo
    
    check_root
    check_in_chroot || log_warning "Could not verify chroot environment"
    
    if [ "$DRY_RUN" = true ]; then
        log_warning "=== DRY-RUN MODE (no files will be deleted) ==="
        echo
    fi
    
    # Execute cleanup stages
    cleanup_apt
    cleanup_package_cache
    cleanup_temporary_files
    cleanup_logs
    cleanup_bash_history
    cleanup_shell_history
    cleanup_machine_id
    cleanup_ssh_keys
    cleanup_network_config
    cleanup_systemd
    cleanup_caches
    cleanup_user_data
    cleanup_udev
    cleanup_package_manager_database
    cleanup_misc
    
    echo
    generate_report
}

main "$@"
