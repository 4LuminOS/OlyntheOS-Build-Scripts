#!/bin/bash
################################################################################
# Example: Smart AI Setup Script Using RAM Detection
# 
# This shows how to integrate the model recommendation script into
# a larger setup workflow
################################################################################

set -euo pipefail

# Source the recommendation script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/detect-model-recommendation.sh"

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  Smart LuminOS AI Setup                    ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
echo

# 1. Detect system resources
echo -e "${BLUE}[1/4] Detecting system resources...${NC}"
ram_gb=$(get_ram_gb)
echo -e "  RAM: ${CYAN}${ram_gb}GB${NC}"

# 2. Recommend model
echo
echo -e "${BLUE}[2/4] Analyzing recommendation...${NC}"
recommended_model=$(get_recommended_model "$ram_gb")
model_details=$(get_model_details "$recommended_model")
model_name=$(echo "$model_details" | cut -d'|' -f1)
model_size=$(echo "$model_details" | cut -d'|' -f2)

echo -e "  Recommended: ${CYAN}${model_name}${NC} (${model_size})"

# 3. Check dependencies
echo
echo -e "${BLUE}[3/4] Checking dependencies...${NC}"

check_ollama() {
    if command -v ollama &>/dev/null; then
        echo -e "  ${GREEN}✓${NC} Ollama installed"
        return 0
    else
        echo -e "  ${YELLOW}⚠${NC} Ollama not found (will need to be installed)"
        return 1
    fi
}

check_network() {
    if ping -c 1 8.8.8.8 &>/dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} Network connectivity OK"
        return 0
    else
        echo -e "  ${YELLOW}⚠${NC} No internet connection detected"
        return 1
    fi
}

check_disk_space() {
    local available_gb=$(df /usr/share/ollama 2>/dev/null | tail -1 | awk '{printf "%.1f", $4 / 1024 / 1024}' || echo "0")
    local needed_gb=$(echo "$model_size" | grep -oE "[0-9.]+" | head -1)
    
    if (( $(echo "$available_gb >= $needed_gb * 1.5" | bc -l) )); then
        echo -e "  ${GREEN}✓${NC} Disk space OK (${available_gb}GB available)"
        return 0
    else
        echo -e "  ${YELLOW}⚠${NC} Limited disk space (${available_gb}GB available, need ~${needed_gb}GB)"
        return 1
    fi
}

ollama_ok=false
network_ok=false
disk_ok=false

check_ollama && ollama_ok=true
check_network && network_ok=true
check_disk_space && disk_ok=true

# 4. Summary and recommendation
echo
echo -e "${BLUE}[4/4] Setup Summary${NC}"
echo

if [ "$ollama_ok" = true ] && [ "$network_ok" = true ] && [ "$disk_ok" = true ]; then
    echo -e "${GREEN}✓ All checks passed! Ready to install model.${NC}"
    echo
    echo -e "  Command to install:"
    echo -e "  ${CYAN}ollama pull ${recommended_model}${NC}"
    echo
    read -p "Install now? (yes/no): " -r response
    if [[ "$response" =~ ^[Yy] ]]; then
        echo -e "${BLUE}Installing ${model_name}...${NC}"
        if ollama pull "$recommended_model"; then
            echo -e "${GREEN}Installation complete!${NC}"
            echo -e "  Run with: ${CYAN}ollama run ${recommended_model}${NC}"
        else
            echo -e "${YELLOW}Installation failed${NC}"
        fi
    fi
else
    echo -e "${YELLOW}⚠ Some checks failed. Review above before installing.${NC}"
    echo
    
    if [ "$ollama_ok" = false ]; then
        echo "  Install Ollama first: https://ollama.ai"
    fi
    
    if [ "$network_ok" = false ]; then
        echo "  Check network connection for model downloads"
    fi
    
    if [ "$disk_ok" = false ]; then
        echo "  Free up disk space in /usr/share/ollama"
    fi
    
    echo
    echo -e "  Manual install: ${CYAN}ollama pull ${recommended_model}${NC}"
fi
