#!/bin/bash
################################################################################
# Practical Example: Using detect-model-recommendation.sh in Production
# 
# This demonstrates all the different ways to use the recommendation engine
################################################################################

set -euo pipefail

# Source the recommendation library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/detect-model-recommendation.sh"

echo "═══════════════════════════════════════════════════════════════"
echo "RAM Detection & Model Recommendation - Usage Examples"
echo "═══════════════════════════════════════════════════════════════"

# ─────────────────────────────────────────────────────────────────
# Example 1: Basic detection
# ─────────────────────────────────────────────────────────────────
echo
echo "EXAMPLE 1: Basic Detection"
echo "──────────────────────────"

ram=$(get_ram_gb)
model=$(get_recommended_model "$ram")
echo "Detected: ${ram}GB RAM → Recommended: ${model}"

# ─────────────────────────────────────────────────────────────────
# Example 2: Using in conditional logic
# ─────────────────────────────────────────────────────────────────
echo
echo "EXAMPLE 2: Conditional Logic"
echo "────────────────────────────"

ram=$(get_ram_gb)
if [ "$ram" -lt 4 ]; then
    echo "System is low on RAM - recommending lightweight model"
    model="phi"
elif [ "$ram" -lt 12 ]; then
    echo "System has moderate RAM - recommending balanced model"
    model="llama2"
else
    echo "System has plenty of RAM - recommending advanced model"
    model="llama3"
fi
echo "Selected model: $model"

# ─────────────────────────────────────────────────────────────────
# Example 3: Creating a setup script template
# ─────────────────────────────────────────────────────────────────
echo
echo "EXAMPLE 3: Setup Script Template"
echo "────────────────────────────────"

create_custom_setup() {
    local ram_gb
    ram_gb=$(get_ram_gb)
    
    # Get model details
    local model
    model=$(get_recommended_model "$ram_gb")
    local details
    details=$(get_model_details "$model")
    
    local model_name model_size model_desc model_notes model_cmd
    model_name=$(echo "$details" | cut -d'|' -f1)
    model_size=$(echo "$details" | cut -d'|' -f2)
    model_desc=$(echo "$details" | cut -d'|' -f3)
    model_notes=$(echo "$details" | cut -d'|' -f4)
    model_cmd=$(echo "$details" | cut -d'|' -f5)
    
    cat > /tmp/ai-setup-report.txt <<REPORT
LuminOS AI Setup Report
=======================
Timestamp: $(date)
System RAM: ${ram_gb}GB
Recommended Model: ${model}

Model Details:
  Name: ${model_name}
  Size: ${model_size}
  Description: ${model_desc}
  Notes: ${model_notes}

Installation Command:
  ollama pull ${model_cmd}

Run the model:
  ollama run ${model_cmd}

Estimated download time: 5-15 minutes
Estimated space needed: ${model_size}
REPORT

    cat /tmp/ai-setup-report.txt
}

create_custom_setup

# ─────────────────────────────────────────────────────────────────
# Example 4: Using with arrays and loops
# ─────────────────────────────────────────────────────────────────
echo
echo "EXAMPLE 4: Model Compatibility Check"
echo "────────────────────────────────────"

ram=$(get_ram_gb)

# Define models with their RAM requirements
declare -A model_requirements=(
    ["phi"]="2"
    ["llama2"]="8"
    ["llama3"]="12"
    ["mistral"]="16"
    ["codellama"]="20"
)

echo "Models compatible with ${ram}GB system:"
for model in "${!model_requirements[@]}"; do
    required=${model_requirements[$model]}
    if [ "$ram" -ge "$required" ]; then
        echo "  ✓ $model (requires ${required}GB)"
    else
        echo "  ✗ $model (requires ${required}GB - insufficient)"
    fi
done

# ─────────────────────────────────────────────────────────────────
# Example 5: Integration with system tools
# ─────────────────────────────────────────────────────────────────
echo
echo "EXAMPLE 5: System Integration"
echo "────────────────────────────"

ram=$(get_ram_gb)
model=$(get_recommended_model "$ram")

# Create installation script
cat > /tmp/install-ai-model.sh <<'INSTALL_SCRIPT'
#!/bin/bash
source /usr/local/bin/detect-model-recommendation.sh

ram=$(get_ram_gb)
model=$(get_recommended_model "$ram")

echo "Installing AI model for system with ${ram}GB RAM"
echo "Selected model: $model"

if command -v ollama &>/dev/null; then
    ollama pull "$model"
else
    echo "Error: Ollama not installed"
    exit 1
fi
INSTALL_SCRIPT

chmod +x /tmp/install-ai-model.sh
echo "Created: /tmp/install-ai-model.sh"

# ─────────────────────────────────────────────────────────────────
# Example 6: Creating configuration file
# ─────────────────────────────────────────────────────────────────
echo
echo "EXAMPLE 6: Configuration File Generation"
echo "────────────────────────────────────────"

generate_config() {
    local ram_gb
    ram_gb=$(get_ram_gb)
    local model
    model=$(get_recommended_model "$ram_gb")
    local details
    details=$(get_model_details "$model")
    
    cat > /tmp/ollama.conf <<EOF
# LuminOS Ollama Configuration
# Auto-generated based on system detection

# System Resources
SYSTEM_RAM_GB=${ram_gb}
DETECTED_AT=$(date)

# Model Configuration
AI_MODEL=${model}
MODEL_NAME=$(echo "$details" | cut -d'|' -f1)
MODEL_SIZE=$(echo "$details" | cut -d'|' -f2)

# Ollama Settings
OLLAMA_HOST=0.0.0.0:11434
OLLAMA_MODELS=/usr/share/ollama/.ollama/models

# Resource Limits (scaled to system)
if [ $ram_gb -lt 4 ]; then
    OLLAMA_NUM_PARALLEL=1
    OLLAMA_MAX_LOADED_MODELS=1
elif [ $ram_gb -lt 12 ]; then
    OLLAMA_NUM_PARALLEL=2
    OLLAMA_MAX_LOADED_MODELS=1
else
    OLLAMA_NUM_PARALLEL=4
    OLLAMA_MAX_LOADED_MODELS=2
fi
EOF

    cat /tmp/ollama.conf
}

generate_config

# ─────────────────────────────────────────────────────────────────
# Example 7: Decision tree
# ─────────────────────────────────────────────────────────────────
echo
echo "EXAMPLE 7: Decision Tree"
echo "───────────────────────"

decision_tree() {
    local ram_gb
    ram_gb=$(get_ram_gb)
    
    echo "System has ${ram_gb}GB RAM"
    echo
    
    case "$ram_gb" in
        [0-3])
            echo "⚠️  Very Limited RAM"
            echo "  - Use lightweight models only (Phi, Orca-mini)"
            echo "  - Disable other services"
            echo "  - Consider CPU-only inference"
            ;;
        [4-7])
            echo "✓ Limited RAM"
            echo "  - Use Phi or lightweight models"
            echo "  - Good for basic queries"
            ;;
        [8-15])
            echo "✓✓ Moderate RAM"
            echo "  - Use Llama2 for balanced performance"
            echo "  - Good speed and quality"
            ;;
        *)
            echo "✓✓✓ High RAM"
            echo "  - Use Llama3 for best quality"
            echo "  - Can run multiple models"
            echo "  - Best accuracy and reasoning"
            ;;
    esac
}

decision_tree

# ─────────────────────────────────────────────────────────────────
# Example 8: Automation script
# ─────────────────────────────────────────────────────────────────
echo
echo "EXAMPLE 8: Auto-Install Script"
echo "──────────────────────────────"

auto_install_model() {
    local ram_gb
    ram_gb=$(get_ram_gb)
    local model
    model=$(get_recommended_model "$ram_gb")
    
    echo "Auto-installation for ${ram_gb}GB system"
    echo "Would install: $model"
    
    # Simulate (don't actually install)
    echo "SIMULATED: ollama pull $model"
    echo "SIMULATED: ollama create lumin -f /path/to/Modelfile"
}

auto_install_model

# ─────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────
echo
echo "═══════════════════════════════════════════════════════════════"
echo "Summary of Usage Examples"
echo "═══════════════════════════════════════════════════════════════"
echo
echo "1. ✓ Basic detection with get_ram_gb() and get_recommended_model()"
echo "2. ✓ Conditional logic based on RAM thresholds"
echo "3. ✓ Creating setup reports with get_recommendation()"
echo "4. ✓ Model compatibility checking"
echo "5. ✓ Creating installation scripts"
echo "6. ✓ Generating configuration files"
echo "7. ✓ Decision trees for user guidance"
echo "8. ✓ Automated installation workflows"
echo
echo "All functions are available when sourcing the script:"
echo "  source /usr/local/bin/detect-model-recommendation.sh"
echo
echo "═══════════════════════════════════════════════════════════════"
