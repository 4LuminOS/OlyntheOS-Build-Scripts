#!/bin/bash
################################################################################
# First-Boot AI Installation Script for LuminOS
# 
# Presents user with options to install AI models on first boot
# Supports both CLI and GUI (zenity) interfaces
#
# Usage: sudo ./luminos-firstboot-ai.sh [--cli|--gui]
################################################################################

set -euo pipefail

# Colors for CLI output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
INTERFACE="${1:-auto}"
OLLAMA_BIN="/usr/local/bin/ollama"
OLLAMA_USER="ollama"
MARKER_FILE="/var/lib/luminos-ai-installed"

# Model definitions: name|size|description|command
declare -A MODELS=(
    ["light"]="phi|3.8GB|Fast & lightweight (CPU friendly)|phi"
    ["balanced"]="llama2|4.0GB|Balanced speed & quality|llama2"
    ["advanced"]="llama3|4.7GB|Highest quality & accuracy|llama3"
)

################################################################################
# Utility Functions
################################################################################

log_info() {
    echo -e "${BLUE}[i]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[!]${NC} $*"
}

log_error() {
    echo -e "${RED}[✗]${NC} $*"
}

log_header() {
    echo
    echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  $*"
    echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
    echo
}

################################################################################
# Environment Checks
################################################################################

check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

check_ollama_installed() {
    if [ ! -f "$OLLAMA_BIN" ]; then
        log_error "Ollama not found at $OLLAMA_BIN"
        log_info "Please install Ollama first"
        exit 1
    fi
}

check_ollama_service() {
    if ! systemctl is-enabled ollama.service &>/dev/null; then
        log_error "Ollama service not enabled"
        log_info "Enabling now..."
        systemctl enable ollama.service || exit 1
    fi
}

check_already_installed() {
    if [ -f "$MARKER_FILE" ]; then
        log_info "AI models already installed (marker: $MARKER_FILE)"
        log_info "To reinstall, remove: $MARKER_FILE"
        exit 0
    fi
}

detect_interface() {
    if [ "$INTERFACE" = "auto" ]; then
        if command -v zenity &>/dev/null && [ -n "${DISPLAY:-}" ]; then
            INTERFACE="gui"
        else
            INTERFACE="cli"
        fi
    fi
    log_info "Using interface: $INTERFACE"
}

################################################################################
# CLI Interface
################################################################################

cli_ask_enable_ai() {
    echo
    echo "╔════════════════════════════════════════════╗"
    echo "║  Enable Local AI Assistant?                ║"
    echo "╚════════════════════════════════════════════╝"
    echo
    echo "LuminOS includes Ollama for running local AI models."
    echo "Models are downloaded and stored locally on your system."
    echo
    
    while true; do
        read -p "Enable Local AI? (yes/no): " -r response
        case "$response" in
            [yY][eE][sS]|[yY])
                return 0
                ;;
            [nN][oO]|[nN])
                return 1
                ;;
            *)
                echo "Please answer yes or no"
                ;;
        esac
    done
}

cli_show_models() {
    echo
    echo "╔════════════════════════════════════════════╗"
    echo "║  Select AI Model                           ║"
    echo "╚════════════════════════════════════════════╝"
    echo
    echo "Choose which model to install:"
    echo
    echo "1) 🚀 Light      - Phi (3.8GB, fastest, CPU friendly)"
    echo "2) ⚖️  Balanced   - Llama2 (4.0GB, good balance)"
    echo "3) 🧠 Advanced   - Llama3 (4.7GB, best quality)"
    echo "4) ⏭️  Skip       - Don't install now"
    echo
}

cli_select_model() {
    local choice
    
    while true; do
        cli_show_models
        read -p "Enter choice (1-4): " -r choice
        
        case "$choice" in
            1)
                echo "light"
                return 0
                ;;
            2)
                echo "balanced"
                return 0
                ;;
            3)
                echo "advanced"
                return 0
                ;;
            4)
                echo "skip"
                return 0
                ;;
            *)
                log_error "Invalid choice. Please enter 1-4"
                ;;
        esac
    done
}

cli_confirm_model() {
    local model_key="$1"
    local model_info="${MODELS[$model_key]}"
    local size=$(echo "$model_info" | cut -d'|' -f2)
    local description=$(echo "$model_info" | cut -d'|' -f3)
    
    echo
    log_info "Selected: $description"
    log_warning "Download size: $size"
    echo
    
    read -p "Proceed with installation? (yes/no): " -r response
    
    case "$response" in
        [yY][eE][sS]|[yY]) return 0 ;;
        *) return 1 ;;
    esac
}

################################################################################
# GUI Interface (Zenity)
################################################################################

gui_ask_enable_ai() {
    zenity --question \
        --title="LuminOS - Enable Local AI" \
        --text="Do you want to enable Local AI Assistant?\n\nOllama will be installed to run local models.\nModels are stored locally on your system." \
        --width=400 2>/dev/null
    return $?
}

gui_select_model() {
    local choice
    
    choice=$(zenity --list \
        --title="LuminOS - Select AI Model" \
        --text="Choose which model to install:" \
        --column="Model" \
        --column="Size" \
        --column="Description" \
        "Light (Phi)" "3.8GB" "Fast & lightweight, CPU friendly" \
        "Balanced (Llama2)" "4.0GB" "Good balance of speed & quality" \
        "Advanced (Llama3)" "4.7GB" "Best quality & accuracy" \
        "Skip" "-" "Don't install now" \
        --width=600 \
        --height=300 2>/dev/null)
    
    case "$choice" in
        "Light"*) echo "light" ;;
        "Balanced"*) echo "balanced" ;;
        "Advanced"*) echo "advanced" ;;
        "Skip"*) echo "skip" ;;
        *) return 1 ;;
    esac
}

gui_confirm_model() {
    local model_key="$1"
    local model_info="${MODELS[$model_key]}"
    local size=$(echo "$model_info" | cut -d'|' -f2)
    local description=$(echo "$model_info" | cut -d'|' -f3)
    
    zenity --question \
        --title="LuminOS - Confirm Model Installation" \
        --text="Model: $description\nDownload size: $size\n\nThis may take several minutes." \
        --width=400 2>/dev/null
    return $?
}

gui_show_progress() {
    local model_name="$1"
    local model_cmd="$2"
    local result_file
    result_file=$(mktemp) || { log_error "Failed to create temp file"; return 1; }
    echo "1" > "$result_file"

    {
        echo "0"
        echo "# Downloading $model_name model..."
        
        # Run ollama pull and try to estimate progress
        if timeout 3600 runuser -u "$OLLAMA_USER" -- "$OLLAMA_BIN" pull "$model_cmd" 2>&1; then
            echo "0" > "$result_file"
            echo "100"
            echo "# Installation complete!"
        else
            echo "1" > "$result_file"
            echo "100"
            echo "# Installation failed!"
        fi
    } | zenity --progress \
        --title="LuminOS - Installing AI Model" \
        --text="Downloading $model_name model...\nThis may take several minutes." \
        --pulsate \
        --no-cancel \
        --auto-close \
        --width=400 2>/dev/null

    local install_result
    install_result=$(<"$result_file")
    rm -f "$result_file"
    return "$install_result"
}

################################################################################
# Model Installation
################################################################################

install_model() {
    local model_key="$1"
    local model_info="${MODELS[$model_key]}"
    local model_name=$(echo "$model_info" | cut -d'|' -f1)
    local model_cmd=$(echo "$model_info" | cut -d'|' -f4)
    
    log_header "Installing $model_name Model"
    
    # Check if Ollama service is running
    if ! systemctl is-active -q ollama.service; then
        log_info "Starting Ollama service..."
        systemctl start ollama.service
        sleep 3
    fi
    
    # Wait for Ollama to be ready
    local max_retries=30
    local attempt=0
    
    log_info "Waiting for Ollama to be ready..."
    while ! runuser -u "$OLLAMA_USER" -- "$OLLAMA_BIN" list &>/dev/null; do
        attempt=$((attempt + 1))
        if [ $attempt -ge $max_retries ]; then
            log_error "Ollama service failed to start"
            return 1
        fi
        echo -n "."
        sleep 1
    done
    echo
    log_success "Ollama ready"
    
    # Pull the model
    log_info "Pulling $model_name model (this may take 5-15 minutes)..."
    
    if runuser -u "$OLLAMA_USER" -- "$OLLAMA_BIN" pull "$model_cmd"; then
        log_success "Model installed: $model_name"
        return 0
    else
        log_error "Failed to install model: $model_name"
        return 1
    fi
}

create_completion_marker() {
    mkdir -p "$(dirname "$MARKER_FILE")"
    touch "$MARKER_FILE"
    log_success "Installation marker created: $MARKER_FILE"
}

################################################################################
# Main Workflow
################################################################################

main_cli() {
    log_header "LuminOS First-Boot AI Setup"
    
    if ! cli_ask_enable_ai; then
        log_warning "Skipping AI installation"
        create_completion_marker
        echo
        log_info "You can enable AI later with: ollama pull llama3"
        exit 0
    fi
    
    local selected_model
    selected_model=$(cli_select_model)
    
    if [ "$selected_model" = "skip" ]; then
        log_warning "Skipping AI installation"
        create_completion_marker
        exit 0
    fi
    
    if ! cli_confirm_model "$selected_model"; then
        log_warning "Installation cancelled"
        exit 0
    fi
    
    if install_model "$selected_model"; then
        create_completion_marker
        log_success "AI setup complete!"
        log_info "Start using AI with: ollama run llama2"
    else
        log_error "Installation failed"
        exit 1
    fi
}

main_gui() {
    if ! gui_ask_enable_ai; then
        zenity --info \
            --title="LuminOS" \
            --text="Skipping AI installation.\n\nYou can enable AI later by running:\nollama pull llama3" \
            --width=300 2>/dev/null || true
        create_completion_marker
        exit 0
    fi
    
    local selected_model
    selected_model=$(gui_select_model) || {
        zenity --error \
            --title="LuminOS" \
            --text="No model selected." \
            --width=300 2>/dev/null || true
        exit 0
    }
    
    if [ "$selected_model" = "skip" ]; then
        zenity --info \
            --title="LuminOS" \
            --text="Skipping AI installation.\n\nYou can enable AI later by running:\nollama pull llama3" \
            --width=300 2>/dev/null || true
        create_completion_marker
        exit 0
    fi
    
    if ! gui_confirm_model "$selected_model"; then
        zenity --error \
            --title="LuminOS" \
            --text="Installation cancelled." \
            --width=300 2>/dev/null || true
        exit 0
    fi
    
    gui_show_progress "$selected_model"
    
    if [ $? -eq 0 ]; then
        create_completion_marker
        zenity --info \
            --title="LuminOS" \
            --text="AI setup complete!\n\nYou can now use AI with:\nollama run $selected_model" \
            --width=300 2>/dev/null || true
    else
        zenity --error \
            --title="LuminOS" \
            --text="Installation failed.\n\nCheck system logs for details." \
            --width=300 2>/dev/null || true
        exit 1
    fi
}

main() {
    check_root
    check_ollama_installed
    check_ollama_service
    check_already_installed
    detect_interface
    
    case "$INTERFACE" in
        cli)
            main_cli
            ;;
        gui)
            main_gui
            ;;
        *)
            log_error "Unknown interface: $INTERFACE"
            exit 1
            ;;
    esac
}

main "$@"
