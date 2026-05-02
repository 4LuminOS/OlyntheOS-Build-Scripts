#!/bin/bash
################################################################################
# RAM-Based AI Model Recommendation Script
# 
# Detects system RAM and recommends appropriate Ollama model
# Can be sourced into other scripts or run standalone
#
# Usage (standalone):
#   ./detect-model-recommendation.sh
#
# Usage (sourced):
#   source ./detect-model-recommendation.sh
#   get_ram_gb          # Returns RAM in GB
#   get_recommended_model # Returns model name
#   print_recommendation  # Prints human-readable recommendation
################################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

################################################################################
# Core Functions
################################################################################

# Detect total system RAM in GB
get_ram_gb() {
    local total_kb
    
    # Try /proc/meminfo first (Linux)
    if [ -f /proc/meminfo ]; then
        total_kb=$(grep "^MemTotal:" /proc/meminfo | awk '{print $2}')
    # Fallback to sysctl (macOS, BSD)
    elif command -v sysctl &>/dev/null; then
        total_kb=$(($(sysctl -n hw.memsize 2>/dev/null || echo 0) / 1024))
    # Fallback to free command
    elif command -v free &>/dev/null; then
        total_kb=$(free | awk '/^Mem:/ {print $2}')
    else
        echo "0" && return 1
    fi
    
    # Convert KB to GB
    echo $((total_kb / 1024 / 1024))
}

# Get recommendation based on RAM
get_recommended_model() {
    local ram_gb="$1"
    
    if [ "$ram_gb" -lt 4 ]; then
        echo "phi"
    elif [ "$ram_gb" -lt 12 ]; then
        echo "llama2"
    else
        echo "llama3"
    fi
}

# Get model details (size, description, ollama command)
get_model_details() {
    local model="$1"
    
    case "$model" in
        phi)
            echo "Phi|3.8GB|Fast & lightweight|CPU-friendly inference|phi"
            ;;
        llama2)
            echo "Llama2|4.0GB|Balanced performance|Good quality responses|llama2"
            ;;
        llama3)
            echo "Llama3|4.7GB|Premium quality|Best accuracy|llama3"
            ;;
        *)
            echo "Unknown||Unknown model||$model"
            ;;
    esac
}

# Get detailed recommendation object
get_recommendation() {
    local ram_gb="$1"
    local model
    local details
    
    model=$(get_recommended_model "$ram_gb")
    details=$(get_model_details "$model")
    
    # Output in key=value format for sourcing
    echo "RAM_GB=$ram_gb"
    echo "RECOMMENDED_MODEL=$model"
    echo "MODEL_NAME=$(echo "$details" | cut -d'|' -f1)"
    echo "MODEL_SIZE=$(echo "$details" | cut -d'|' -f2)"
    echo "MODEL_DESC=$(echo "$details" | cut -d'|' -f3)"
    echo "MODEL_NOTES=$(echo "$details" | cut -d'|' -f4)"
    echo "MODEL_CMD=$(echo "$details" | cut -d'|' -f5)"
}

# Print human-readable recommendation
print_recommendation() {
    local ram_gb="${1:-}"
    
    if [ -z "$ram_gb" ]; then
        ram_gb=$(get_ram_gb)
    fi
    
    local model recommendation_text
    model=$(get_recommended_model "$ram_gb")
    local details="$(get_model_details "$model")"
    
    local name size desc notes
    name=$(echo "$details" | cut -d'|' -f1)
    size=$(echo "$details" | cut -d'|' -f2)
    desc=$(echo "$details" | cut -d'|' -f3)
    notes=$(echo "$details" | cut -d'|' -f4)
    
    echo
    echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  AI Model Recommendation                   ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${BLUE}System RAM:${NC} ${MAGENTA}${ram_gb}GB${NC}"
    echo
    
    case "$model" in
        phi)
            echo -e "Recommended: ${RED}🚀 Light Model${NC}"
            ;;
        llama2)
            echo -e "Recommended: ${YELLOW}⚖️  Balanced Model${NC}"
            ;;
        llama3)
            echo -e "Recommended: ${GREEN}🧠 Advanced Model${NC}"
            ;;
    esac
    
    echo
    echo -e "${BLUE}Model:${NC} $name"
    echo -e "${BLUE}Size:${NC} $size"
    echo -e "${BLUE}Description:${NC} $desc"
    echo -e "${BLUE}Notes:${NC} $notes"
    echo
    echo -e "${GREEN}Install with:${NC} ${CYAN}ollama pull ${model}${NC}"
    echo
}

# For debugging/inspection
print_detailed_info() {
    local ram_gb="$1"
    
    echo
    echo -e "${BLUE}=== Detailed Model Comparison ===${NC}"
    echo
    
    # Create comparison table
    printf "%-12s %-8s %-15s %-20s\n" "Model" "Size" "Best For" "Min RAM"
    printf "%s\n" "$(printf '%-12s %-8s %-15s %-20s' "---" "---" "---" "---")"
    printf "%-12s %-8s %-15s %-20s\n" "Phi" "3.8GB" "Fast" "2GB+"
    printf "%-12s %-8s %-15s %-20s\n" "Llama2" "4.0GB" "Balanced" "8GB+"
    printf "%-12s %-8s %-15s %-20s\n" "Llama3" "4.7GB" "Premium" "16GB+"
    
    echo
    echo -e "${BLUE}Your System:${NC}"
    echo "  Total RAM: ${ram_gb}GB"
    echo "  Recommended: $(get_recommended_model "$ram_gb")"
    
    # Show alternative models
    echo
    echo -e "${YELLOW}Other Available Models:${NC}"
    echo "  - mistral (7.3GB, better reasoning)"
    echo "  - neural-chat (4.5GB, optimized for conversations)"
    echo "  - codellama (6.7GB, code generation)"
    echo "  - orca-mini (3.3GB, ultra-lightweight)"
    echo
}

################################################################################
# Interactive Functions
################################################################################

# Ask user if they want to install
ask_install() {
    local model="$1"
    
    read -p "Install $model now? (yes/no): " -r response
    case "$response" in
        [yY][eE][sS]|[yY]) return 0 ;;
        *) return 1 ;;
    esac
}

# Show recommendation and offer installation
interactive_setup() {
    local ram_gb
    ram_gb=$(get_ram_gb)
    
    print_recommendation "$ram_gb"
    print_detailed_info "$ram_gb"
    
    local model
    model=$(get_recommended_model "$ram_gb")
    
    if ask_install "$model"; then
        install_model "$model"
    else
        echo -e "${YELLOW}Skipped installation${NC}"
        echo "Install later with: ${CYAN}ollama pull ${model}${NC}"
    fi
}

# Install model via Ollama
install_model() {
    local model="$1"
    
    if ! command -v ollama &>/dev/null; then
        echo -e "${RED}Error: Ollama not installed${NC}"
        return 1
    fi
    
    echo -e "${BLUE}Installing $model...${NC}"
    ollama pull "$model"
    echo -e "${GREEN}Installation complete!${NC}"
}

################################################################################
# Export Functions for Sourcing
################################################################################

export -f get_ram_gb
export -f get_recommended_model
export -f get_model_details
export -f get_recommendation
export -f print_recommendation
export -f print_detailed_info
export -f ask_install
export -f install_model

################################################################################
# Main - Run if executed directly
################################################################################

main() {
    local command="${1:-recommend}"
    
    case "$command" in
        recommend)
            local ram_gb
            ram_gb=$(get_ram_gb)
            print_recommendation "$ram_gb"
            ;;
        compare)
            local ram_gb
            ram_gb=$(get_ram_gb)
            print_detailed_info "$ram_gb"
            ;;
        model)
            local ram_gb="${2:-}"
            if [ -z "$ram_gb" ]; then
                ram_gb=$(get_ram_gb)
            fi
            get_recommended_model "$ram_gb"
            ;;
        ram)
            get_ram_gb
            ;;
        info)
            local ram_gb="${2:-}"
            if [ -z "$ram_gb" ]; then
                ram_gb=$(get_ram_gb)
            fi
            get_recommendation "$ram_gb"
            ;;
        json)
            local ram_gb="${2:-}"
            if [ -z "$ram_gb" ]; then
                ram_gb=$(get_ram_gb)
            fi
            local model desc
            model=$(get_recommended_model "$ram_gb")
            desc=$(get_model_details "$model")
            
            cat <<EOF
{
  "ram_gb": $ram_gb,
  "recommended_model": "$model",
  "model_name": "$(echo "$desc" | cut -d'|' -f1)",
  "model_size": "$(echo "$desc" | cut -d'|' -f2)",
  "model_description": "$(echo "$desc" | cut -d'|' -f3)",
  "model_notes": "$(echo "$desc" | cut -d'|' -f4)"
}
EOF
            ;;
        interactive)
            interactive_setup
            ;;
        help|--help|-h)
            cat <<EOF
${CYAN}AI Model Recommendation Script${NC}

${BLUE}Usage:${NC}
  $(basename "$0") [COMMAND] [OPTIONS]

${BLUE}Commands:${NC}
  recommend     Show recommendation (default)
  compare       Show detailed model comparison
  model         Show just the recommended model name
  ram           Show detected RAM in GB
  info          Show detailed info in key=value format
  json          Output as JSON
  interactive   Interactive setup with installation
  help          Show this help message

${BLUE}Examples:${NC}
  $(basename "$0")                    # Show recommendation
  $(basename "$0") model              # Get model name only
  $(basename "$0") ram                # Get RAM in GB
  $(basename "$0") json               # Get JSON output
  $(basename "$0") interactive        # Interactive setup

${BLUE}Sourcing into scripts:${NC}
  source $(basename "$0")
  ram_gb=\$(get_ram_gb)
  model=\$(get_recommended_model \$ram_gb)
  echo "Recommended: \$model"

EOF
            ;;
        *)
            echo -e "${RED}Unknown command: $command${NC}"
            echo "Run '$(basename "$0") help' for usage"
            exit 1
            ;;
    esac
}

# Only run main if script is executed directly, not sourced
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
