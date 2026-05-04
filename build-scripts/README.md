# 🌌 LuminOS Build Scripts

![Build Status](https://img.shields.io/badge/build-stable-brightgreen)
![Version](https://img.shields.io/badge/version-v0.2.1-blue)
![License](https://img.shields.io/badge/license-GPL--3.0-red)
![Platform](https://img.shields.io/badge/platform-Debian%2013-lightgrey)
![AI](https://img.shields.io/badge/AI-Local%20LLM-purple)
![Privacy](https://img.shields.io/badge/privacy-100%25%20Local-success)

Welcome to the **official build system for LuminOS**.

**LuminOS** is a **privacy-focused AI operating system** built on **Debian 13 (Trixie)** designed for users who want **powerful AI tools running locally without cloud dependency**.

The system integrates **Lumin**, a fully offline AI assistant powered by **Ollama + local LLM models**, while maintaining the transparency and stability of Debian.

---

## 🚀 Vision

The goal of **LuminOS** is simple:

> Build the **first truly transparent AI operating system** where AI runs **locally, securely, and privately**.

No tracking.  
No cloud dependency.  
Just **pure local intelligence**.

---

## 💿 Try LuminOS

### Default Credentials

```
User: liveuser
Password: luminos
```

⚠️ **Keyboard Notice**

The live ISO uses **US (QWERTY)** layout by default.

If you use **AZERTY**, type the password like this:

```
l u , i n o s
```

(the `m` key is on the `,` position)

---

# 📦 Included Software

LuminOS ships with carefully selected software.

### Desktop

• **KDE Plasma (Dark Theme)**  
• Modern UI  
• Lightweight configuration  

### AI Stack

• **Lumin AI Assistant**  
• **Ollama Runtime**  
• **Local LLM models**  
• Fully **offline capable**

### Productivity

• **OnlyOffice Desktop Editors**  
• Word / Excel / PowerPoint compatible  

### Multimedia

• **VLC Media Player**  
• Full codec support (h264, mp3, etc)

### System Tools

• **Timeshift** – system restore  
• **Flatpak** – application store  
• **Firefox** – web browser  

---

# 🏗️ Architecture

LuminOS follows a **transparent build pipeline**.

```
Host System
   │
   ▼
Bootstrap Debian Base
   │
   ▼
Install Core Packages
   │
   ▼
Inject AI Runtime (Ollama)
   │
   ▼
Install Desktop Environment
   │
   ▼
Apply Customization
   │
   ▼
Compress Filesystem (SquashFS)
   │
   ▼
Generate Bootable Hybrid ISO
```

---

# 🛠 Build LuminOS Yourself

### Requirements

```
Host OS: Debian 12+
RAM: 8GB minimum
Disk Space: 30GB+
Privileges: sudo
Docker (optional, for building without root)
```

---

### 1️⃣ Clone Repository

```bash
git clone https://github.com/4LuminOS/build-scripts.git
cd build-scripts
```

---

### 2️⃣ Start Build

```bash
sudo ./build.sh
```

or build inside a docker container to avoid building as root in your system (requires docker)

```bash
./run-build-docker.sh
```

---

### 3️⃣ Retrieve ISO

After completion:

```
LuminOS-0.2.1-amd64.iso
```

will appear in the project directory.

---

# 🤖 AI System

LuminOS integrates **local AI inference**.

```
User
 │
 ▼
Lumin AI Assistant
 │
 ▼
Ollama Runtime
 │
 ▼
Local LLM Model
 │
 ▼
Response
```

Benefits:

• Fully **offline AI**  
• **No data leaves your machine**  
• **No API cost**  
• **Fast inference**

---

# 🛣️ Roadmap

### Upcoming Improvements

• Improve automated build system  
• Add graphical installer  
• Better AI assistant integration  
• Reduce ISO size  
• Improve hardware compatibility  
• GPU acceleration for AI  
• Multi-model AI support  

---

# 🤝 Contributing

Contributions are welcome.

You can help by:

• Improving build scripts  
• Fixing bugs  
• Optimizing ISO generation  
• Improving documentation  
• Adding AI features  

### Steps

```
1 Fork the repository
2 Create a feature branch
3 Commit your changes
4 Open a Pull Request
```

---

# 📜 License

This project is licensed under:

**GPL-3.0 License**

---

# 🌍 LuminOS Mission

LuminOS aims to become a **next-generation AI operating system** where users can run powerful AI tools **locally, privately, and securely**.

The long-term goal is to build a **fully transparent AI ecosystem**.

---

⭐ **If you like the project, consider starring the repository.**

It helps the project grow and reach more developers.

```
Built with ❤️ by the LuminOS Community
```
