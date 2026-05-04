# First-Boot AI Installation Guide

## Overview

The `luminos-firstboot-ai.sh` script provides an interactive first-boot experience for installing AI models on LuminOS. Users are presented with simple choices to enable/disable local AI and select which model they prefer.

## Files

- **[luminos-firstboot-ai.sh](luminos-firstboot-ai.sh)** - Main first-boot script
- **[luminos-firstboot-ai.service](luminos-firstboot-ai.service)** - Systemd service for automatic execution

## Model Options

| Level | Model | Size | Best For |
|-------|-------|------|----------|
| 🚀 Light | Phi | 3.8GB | Fast inference, CPU-friendly, low memory |
| ⚖️ Balanced | Llama2 | 4.0GB | General use, good speed/quality balance |
| 🧠 Advanced | Llama3 | 4.7GB | Best quality, most accurate responses |

## Interfaces

### CLI Mode
```bash
sudo /usr/local/bin/luminos-firstboot-ai.sh --cli
```
Simple text-based menu (works over SSH, serial console, etc.)

### GUI Mode (Zenity)
```bash
sudo /usr/local/bin/luminos-firstboot-ai.sh --gui
```
User-friendly graphical interface (requires Zenity and X11)

### Auto-Detect (Default)
```bash
sudo /usr/local/bin/luminos-firstboot-ai.sh
```
Automatically selects GUI if available and X11 is running, falls back to CLI

## Integration with Build

### 1. Copy files to build scripts:
```bash
cp luminos-firstboot-ai.sh /home/kyzen7/build/build-scripts/
cp luminos-firstboot-ai.service /home/kyzen7/build/build-scripts/
```

### 2. Add to build.sh installation section:
```bash
# Copy first-boot AI script
cp "${BASE_DIR}/luminos-firstboot-ai.sh" "${CHROOT_DIR}/usr/local/bin/"
cp "${BASE_DIR}/luminos-firstboot-ai.service" "${CHROOT_DIR}/etc/systemd/system/"
chmod +x "${CHROOT_DIR}/usr/local/bin/luminos-firstboot-ai.sh"

# Enable the service
chroot "${CHROOT_DIR}" systemctl enable luminos-firstboot-ai.service
```

### 3. Or add to 05-install-ai.sh:
```bash
# Copy first-boot AI script
cp /tmp/luminos-firstboot-ai.sh /usr/local/bin/
cp /tmp/luminos-firstboot-ai.service /etc/systemd/system/
chmod +x /usr/local/bin/luminos-firstboot-ai.sh

# Enable service
systemctl enable luminos-firstboot-ai.service
```

## How It Works

### First Boot Sequence

1. **Systemd starts** → `luminos-firstboot-ai.service` runs automatically
2. **Checks for marker file** → If `/var/lib/luminos-ai-installed` exists, skips (already ran)
3. **Presents options**:
   - CLI: Text menus
   - GUI: Dialog boxes (Zenity)
4. **User selects**:
   - Yes/No to enable AI
   - Which model to install
   - Confirmation
5. **Model installation**:
   - Starts Ollama service if needed
   - Waits for Ollama to be ready
   - Downloads selected model via `ollama pull`
6. **Completion marker** → Creates `/var/lib/luminos-ai-installed` to prevent re-runs
7. **Service exits** → System ready for user

### Subsequent Boots

- Marker file exists → Service skips immediately
- User can re-run manually: `sudo /usr/local/bin/luminos-firstboot-ai.sh --cli`

## Manual Installation

### If user skips or wants to change models later:

```bash
# View available models
ollama list

# Download a model
ollama pull llama3
ollama pull mistral
ollama pull neural-chat

# Run a model
ollama run llama3

# Remove marker to re-run first-boot script
sudo rm /var/lib/luminos-ai-installed
sudo /usr/local/bin/luminos-firstboot-ai.sh --cli
```

## Customization

### Add More Models

Edit the `MODELS` array in `luminos-firstboot-ai.sh`:

```bash
declare -A MODELS=(
    ["light"]="phi|3.8GB|Fast & lightweight|phi"
    ["balanced"]="llama2|4.0GB|Balanced speed & quality|llama2"
    ["advanced"]="llama3|4.7GB|Highest quality|llama3"
    ["coding"]="codellama|6.7GB|Code generation|codellama"  # Add this
)
```

Then update CLI and GUI selection functions.

### Change Default User Experience

**To force CLI mode:**
```bash
ExecStart=/usr/local/bin/luminos-firstboot-ai.sh --cli
```

**To skip first-boot and require manual installation:**
Remove or disable `luminos-firstboot-ai.service`

## Troubleshooting

### Models not downloading?
```bash
# Check Ollama service
systemctl status ollama

# Check network
ping 8.8.8.8

# Manual test
sudo -u ollama /usr/local/bin/ollama list
```

### Service not running on first boot?
```bash
# Check service status
systemctl status luminos-firstboot-ai.service

# View logs
journalctl -u luminos-firstboot-ai.service -n 50

# Run manually
sudo /usr/local/bin/luminos-firstboot-ai.sh --cli
```

### Reset and try again:
```bash
sudo rm /var/lib/luminos-ai-installed
sudo systemctl restart luminos-firstboot-ai.service
```

## Security Considerations

✅ Runs with root privileges (required for systemd integration)
✅ User validation (yes/no/choice confirmations)
✅ Error handling and graceful failures
✅ Proper file permissions and markers
✅ Logs available via systemd journal

## Performance

- **CLI mode**: Fast, minimal dependencies
- **GUI mode**: Requires Zenity (lightweight, already in KDE Plasma)
- **Download time**: 5-15 minutes depending on model and connection speed
- **Installation**: Non-blocking, user can continue after model downloads start
