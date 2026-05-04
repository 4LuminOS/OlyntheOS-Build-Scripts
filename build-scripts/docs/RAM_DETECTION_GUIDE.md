# RAM-Based AI Model Recommendation System

## Overview

The `detect-model-recommendation.sh` script intelligently detects available system RAM and recommends the most appropriate Ollama AI model based on hardware capabilities.

### Model Recommendations

| RAM | Recommended | Model | Size | Best For |
|-----|-------------|-------|------|----------|
| 2-4GB | 🚀 Light | Phi | 3.8GB | Fast inference, CPU-friendly |
| 4-12GB | ⚖️ Balanced | Llama2 | 4.0GB | General use, good balance |
| 12GB+ | 🧠 Advanced | Llama3 | 4.7GB | Best quality, most accurate |

## Files

- **[detect-model-recommendation.sh](detect-model-recommendation.sh)** - Core detection and recommendation engine
- **[example-smart-ai-setup.sh](example-smart-ai-setup.sh)** - Integration example with full checks

## Quick Start

### Standalone Usage

```bash
# Show recommendation (default)
./detect-model-recommendation.sh recommend

# Get just the model name
./detect-model-recommendation.sh model

# Show detailed comparison
./detect-model-recommendation.sh compare

# Get RAM amount in GB
./detect-model-recommendation.sh ram

# Output as JSON
./detect-model-recommendation.sh json

# Interactive setup with installation
./detect-model-recommendation.sh interactive

# Show help
./detect-model-recommendation.sh help
```

### Output Examples

#### Recommendation Display
```bash
$ ./detect-model-recommendation.sh recommend
╔════════════════════════════════════════════╗
║  AI Model Recommendation                   ║
╚════════════════════════════════════════════╝

System RAM: 16GB

Recommended: 🧠 Advanced Model

Model: Llama3
Size: 4.7GB
Description: Premium quality
Notes: Best accuracy

Install with: ollama pull llama3
```

#### JSON Output
```bash
$ ./detect-model-recommendation.sh json
{
  "ram_gb": 16,
  "recommended_model": "llama3",
  "model_name": "Llama3",
  "model_size": "4.7GB",
  "model_description": "Premium quality",
  "model_notes": "Best accuracy"
}
```

## Integration into Build Scripts

### Method 1: Call Directly in Build Process

In `build.sh`:

```bash
# Install recommendation engine
cp "${BASE_DIR}/detect-model-recommendation.sh" "${CHROOT_DIR}/usr/local/bin/"
chmod +x "${CHROOT_DIR}/usr/local/bin/detect-model-recommendation.sh"

# During first-boot, detect and recommend model
echo "--> Installing model recommendation engine..."
chroot "${CHROOT_DIR}" /usr/local/bin/detect-model-recommendation.sh recommend
```

### Method 2: Source into Custom Setup Script

Create a setup script:

```bash
#!/bin/bash
source /usr/local/bin/detect-model-recommendation.sh

# Get RAM and recommended model
ram_gb=$(get_ram_gb)
model=$(get_recommended_model "$ram_gb")
size=$(get_model_details "$model" | cut -d'|' -f2)

echo "System has ${ram_gb}GB RAM"
echo "Recommending: $model (${size})"

# Install
ollama pull "$model"
```

### Method 3: Integrate with First-Boot Script

Modify `luminos-firstboot-ai.sh`:

```bash
source /usr/local/bin/detect-model-recommendation.sh

# Auto-suggest model based on RAM
ram_gb=$(get_ram_gb)
default_model=$(get_recommended_model "$ram_gb")

echo "Based on your ${ram_gb}GB RAM, we recommend: $default_model"
# ... proceed with user confirmation
```

## Sourcing as Library

Use the script's functions in your own shell scripts:

```bash
#!/bin/bash
source ./detect-model-recommendation.sh

# Get system RAM
ram=$(get_ram_gb)
echo "Available RAM: ${ram}GB"

# Get recommended model
model=$(get_recommended_model "$ram")
echo "Recommended model: $model"

# Get model details
details=$(get_model_details "$model")
name=$(echo "$details" | cut -d'|' -f1)
size=$(echo "$details" | cut -d'|' -f2)
echo "Model: $name ($size)"

# Get complete recommendation
eval "$(get_recommendation "$ram")"
echo "Model command: $MODEL_CMD"
```

### Available Functions

```bash
# Get system RAM in GB
get_ram_gb
# Returns: 16

# Get recommended model name
get_recommended_model <ram_gb>
# Returns: llama3

# Get model details (pipe-separated)
get_model_details <model>
# Returns: Name|Size|Description|Notes|Command

# Get all recommendation data (key=value format)
get_recommendation <ram_gb>
# Exports: RAM_GB, RECOMMENDED_MODEL, MODEL_NAME, MODEL_SIZE, MODEL_DESC, MODEL_NOTES, MODEL_CMD

# Print human-readable recommendation
print_recommendation [ram_gb]

# Show detailed comparison table
print_detailed_info <ram_gb>

# Ask user for confirmation
ask_install <model>

# Install model via Ollama
install_model <model>
```

## Example: Smart Setup with Checks

The provided `example-smart-ai-setup.sh` demonstrates:

1. **System Detection**
   - Available RAM
   - Ollama installation status
   - Network connectivity
   - Disk space availability

2. **Intelligent Recommendation**
   - Suggests model based on RAM
   - Checks compatibility

3. **Pre-flight Checks**
   - Validates Ollama is installed
   - Verifies internet connection
   - Ensures sufficient disk space

4. **Interactive Installation**
   - Shows recommendation
   - Asks for user confirmation
   - Proceeds with installation

### Run Example

```bash
sudo ./example-smart-ai-setup.sh
```

## Advanced: Custom Model Definitions

To add or modify model recommendations, edit the `MODELS` array in `detect-model-recommendation.sh`:

```bash
declare -A MODELS=(
    ["light"]="phi|3.8GB|Fast & lightweight|CPU-friendly inference|phi"
    ["balanced"]="llama2|4.0GB|Balanced performance|Good quality responses|llama2"
    ["advanced"]="llama3|4.7GB|Premium quality|Best accuracy|llama3"
    ["custom"]="mistral|7.3GB|Advanced reasoning|Better logic|mistral"  # Add this
)
```

Then update selection logic in `get_recommended_model()` to add thresholds:

```bash
get_recommended_model() {
    local ram_gb="$1"
    
    if [ "$ram_gb" -lt 4 ]; then
        echo "light"
    elif [ "$ram_gb" -lt 8 ]; then
        echo "balanced"
    elif [ "$ram_gb" -lt 20 ]; then
        echo "advanced"
    else
        echo "custom"  # For systems with 20GB+ RAM
    fi
}
```

## Technical Details

### RAM Detection

The script uses multiple detection methods in order of preference:

1. **Linux**: `/proc/meminfo` (most accurate)
2. **macOS/BSD**: `sysctl hw.memsize`
3. **Fallback**: `free` command

```bash
get_ram_gb  # Returns total RAM in GB
```

### Recommendation Logic

```
if RAM < 4GB   → Phi (3.8GB)     - Light
if RAM < 12GB  → Llama2 (4.0GB)  - Balanced
if RAM >= 12GB → Llama3 (4.7GB)  - Advanced
```

### Output Formats

- **Human-readable**: Colored terminal output
- **Plain text**: Key=value format for scripting
- **JSON**: For integration with other tools
- **CSV**: Comparison table format

## Integration with LuminOS Build

### Full Integration Example

```bash
#!/bin/bash
# In build.sh, during customization phase:

echo "--> Installing AI recommendation engine..."
cp "${BASE_DIR}/detect-model-recommendation.sh" "${CHROOT_DIR}/usr/local/bin/"
cp "${BASE_DIR}/example-smart-ai-setup.sh" "${CHROOT_DIR}/usr/local/bin/"
chmod +x "${CHROOT_DIR}/usr/local/bin/detect-model-recommendation.sh"
chmod +x "${CHROOT_DIR}/usr/local/bin/example-smart-ai-setup.sh"

# Create a symlink for easy access
ln -s /usr/local/bin/detect-model-recommendation.sh "${CHROOT_DIR}/usr/local/bin/recommend-model"
```

### First-Boot Execution

The script can be called during first-boot to automatically suggest models:

```bash
#!/bin/bash
# In luminos-firstboot-ai.sh

source /usr/local/bin/detect-model-recommendation.sh

# Auto-detect and suggest
ram_gb=$(get_ram_gb)
suggested_model=$(get_recommended_model "$ram_gb")

echo "Your system has ${ram_gb}GB RAM"
echo "We recommend installing: $suggested_model"

# Let user confirm
read -p "Install $suggested_model? (yes/no): " choice
[ "$choice" = "yes" ] && ollama pull "$suggested_model"
```

## Troubleshooting

### Script returns 0GB RAM

This might happen if:
- Running in unusual environment (container without /proc/meminfo)
- Permissions issue reading /proc/meminfo

**Fix**: Ensure script runs as root or with appropriate permissions

```bash
sudo ./detect-model-recommendation.sh ram
```

### JSON output not valid

If JSON parsing fails in other scripts, check:
- RAM value is a number
- All variables are properly quoted

**Debug**:
```bash
./detect-model-recommendation.sh json | jq .
```

### Model recommendation doesn't match expectations

Check the recommendation logic in `get_recommended_model()`:
- 0-4GB → Phi
- 4-12GB → Llama2
- 12GB+ → Llama3

Modify thresholds as needed for your distribution.

## Performance

- **Detection**: <100ms (reads from /proc)
- **Recommendation**: <50ms (simple logic)
- **Total startup**: <200ms

Safe to call frequently without performance impact.

## Security

✅ Only reads system information
✅ No external network calls (recommendation is local)
✅ Can be run with or without root
✅ Safe to integrate into automated builds
