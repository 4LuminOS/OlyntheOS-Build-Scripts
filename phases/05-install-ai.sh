#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

echo "--> Setting up Ollama AI runtime (lightweight, no models bundled)..."

# --- Create Ollama system user ---
useradd -r -s /bin/false -m -d /usr/share/ollama ollama 2>/dev/null || true
chown -R ollama:ollama /usr/share/ollama

# --- Create Modelfile template directory ---
mkdir -p /usr/local/share/lumin/ai
MODELFILE="/usr/local/share/lumin/ai/Modelfile"
cat > "${MODELFILE}" << 'EOF'
FROM llama3
SYSTEM """You are Lumin, the integrated assistant for the LuminOS operating system. 
You are calm, clear, kind, and respectful.
You help users with tasks, answer questions, and provide guidance."""
EOF
chown root:root "${MODELFILE}"
chmod 444 "${MODELFILE}"

# --- Ollama systemd service ---
cat > /etc/systemd/system/ollama.service << 'SERVICE'
[Unit]
Description=Ollama API Server
Documentation=https://ollama.ai
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=ollama
Group=ollama
WorkingDirectory=/usr/share/ollama

Environment="OLLAMA_HOST=127.0.0.1:11434"
Environment="OLLAMA_MODELS=/usr/share/ollama/.ollama/models"
Environment="OLLAMA_NUM_PARALLEL=4"
Environment="OLLAMA_MAX_LOADED_MODELS=1"

ExecStart=/usr/local/bin/ollama serve
Restart=always
RestartSec=5

# Security
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=/usr/share/ollama

# Resource limits
LimitNOFILE=65535
LimitNPROC=512

[Install]
WantedBy=multi-user.target
SERVICE

# --- First-boot initialization service (optional) ---
cat > /etc/systemd/system/ollama-init.service << 'SERVICE'
[Unit]
Description=Ollama First-Boot Setup
After=ollama.service
Requires=ollama.service
ConditionPathExists=!/var/lib/ollama-initialized

[Service]
Type=oneshot
User=ollama
ExecStartPre=/bin/sleep 5
ExecStart=/bin/sh -c 'echo "Ollama ready for model installation"'
ExecStartPost=/usr/bin/touch /var/lib/ollama-initialized
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
SERVICE

# --- Enable services ---
systemctl enable ollama.service
systemctl enable ollama-init.service

echo "--> Ollama installation complete"
echo "--> Models must be installed on first boot:"
echo "    ollama pull llama3"
echo "    ollama pull mistral"
echo "    etc..."
