# ABS Studio

**The Governance Framework with a GUI** — AI Bootstrap Systems in an app.

[![MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Pro Tier](https://img.shields.io/badge/tier-Pro%20%2419%2Fmo-green.svg)](https://aibootstrapsystems.com/#pricing)

> **ABS Studio** is the desktop companion for [AI Bootstrap Systems](https://aibootstrapsystems.com). It's the governance framework you know — with automation, a visual interface, and seamless AI integration built in.

---

## 🎯 What Is This?

**Free Tier (Manual):** Download governance files, copy/paste into projects, manually manage sessions.

**Pro Tier (This App):** Everything is automated. Open a project, start a session, talk to AI — governance happens automatically.

| Manual (Free) | ABS Studio (Pro) |
|---------------|------------------|
| Create SESSION_NOTES.md by hand | ✅ Auto-generated per session |
| Copy/paste AI_RULES into prompts | ✅ Rules loaded automatically |
| Track TODO.md manually | ✅ Integrated task management |
| No session history | ✅ Full chat history saved |
| No file context | ✅ Project files in sidebar |
| Manual everything | ✅ Python execution, automation |

---

## ✨ Features

### Governance — Built In
- **AI_RULES_AND_BEST_PRACTICES.md** automatically loaded into every AI session
- **SESSION_NOTES.md** auto-generated and maintained per session
- **TODO.md** and **AI_CONTEXT_INDEX.md** integrated into workflow
- Deterministic, auditable AI behavior — no manual setup required

### AI Chat — Your Way
- **Bring Your Own Key**: OpenAI, Anthropic, Google Gemini
- **Free Options** (coming soon): Ollama (local), OpenRouter (free tier)
- **Business/Enterprise**: Bulk API keys managed on backend
- Seamless switching between providers

### Project Management
- Create and organize projects with governance files auto-initialized
- File explorer with full CRUD operations
- AI can CREATE, UPDATE, DELETE files directly
- Live file refresh — see changes as they happen

### Multi-Window Workflow
- Separate floating windows for AI chat and file editing
- Work across multiple monitors
- Session state persists across window closes

### Automation (Coming Soon)
- Python script execution in project context
- Excel/VBA automation via Python
- CLI integration with `abs check` and `abs determinism`

---

## 🚀 Quick Start

### For Pro/Team/Enterprise Users

1. **Download** the latest release from your dashboard
2. **Launch** ABS Studio
3. **Configure** your AI provider (Settings → API Keys)
4. **Create** a new project or open existing
5. **Start** an AI session — governance files auto-load

### For Developers (Building from Source)

```bash
git clone https://github.com/summonwill/abs-platform.git
cd abs-platform
flutter pub get
flutter run -d windows
```

**Prerequisites:**
- Flutter SDK 3.10.3+
- Windows 10/11, macOS, or Linux

---

## 🔑 AI Provider Options

| Provider | Type | Setup |
|----------|------|-------|
| **OpenAI** | Bring Your Own Key | Add key in Settings |
| **Anthropic** | Bring Your Own Key | Add key in Settings |
| **Google Gemini** | Bring Your Own Key | Add key in Settings |
| **Ollama** | Free (Local) | Install Ollama, runs locally |
| **OpenRouter** | Free Tier Available | One key, many models |
| **Enterprise** | Managed | Keys configured by admin |

---

## 📁 Governance Files (Auto-Managed)

These files are the core of the AI Bootstrap System. In ABS Studio, they're created and maintained automatically:

| File | Purpose | In App |
|------|---------|--------|
| `AI_RULES_AND_BEST_PRACTICES.md` | AI behavior governance | Auto-loaded into sessions |
| `AI_CONTEXT_INDEX.md` | Project context map | Auto-generated |
| `TODO.md` | Task tracking | Integrated UI |
| `SESSION_NOTES.md` | Session history log | Auto-maintained |
| `SESSION_BUFFER.md` | Working memory | Auto-collapsed |

---

## 🏗️ Architecture

```
lib/
├── main.dart                 # App entry, window routing
├── models/
│   └── project.dart          # Project and Session models
├── providers/
│   ├── ai_provider.dart      # AI configuration state
│   └── project_provider.dart # Project CRUD operations
├── screens/
│   ├── ai_chat_screen.dart   # AI chat with governance
│   ├── project_detail_screen.dart # Project view
│   ├── projects_screen.dart  # Project list
│   └── settings_screen.dart  # API key management
├── services/
│   ├── ai_service.dart       # Multi-provider AI client
│   └── file_service.dart     # File I/O operations
└── windows/
    ├── ai_chat_window.dart   # Floating AI chat window
    └── file_editor_window.dart # Floating file editor
```

**Tech Stack:**
- Flutter 3.10.3 (cross-platform desktop)
- Riverpod (state management)
- Hive (local storage)
- desktop_multi_window (separate window processes)

---

## 💰 Pricing

| Tier | Price | What You Get |
|------|-------|--------------|
| **Open Source** | Free | Governance files only (DIY) |
| **Pro** | $19/mo | ABS Studio + CLI + GitHub Action |
| **Team** | $299/mo | Multi-user + Dashboard + Shared Policies |
| **Enterprise** | Custom | SSO + Compliance + Certification |

[View Full Pricing →](https://aibootstrapsystems.com/#pricing)

---

## 🗺️ Roadmap

- [x] Multi-provider AI chat (OpenAI, Anthropic, Gemini)
- [x] Governance files auto-loaded
- [x] File management with AI operations
- [x] Session persistence and history
- [ ] Ollama integration (free local AI)
- [ ] OpenRouter integration (free tier models)
- [ ] Python script execution
- [ ] Excel/VBA automation
- [ ] CLI integration (`abs check`, `abs determinism`)
- [ ] VS Code extension

---

## 📚 Resources

- **Website**: [aibootstrapsystems.com](https://aibootstrapsystems.com)
- **Whitepaper**: [Deterministic AI Development](https://aibootstrapsystems.com/AI-Bootstrap-Systems-Determinism-Whitepaper.pdf)
- **Framework**: [AI Bootstrap Framework (GitHub)](https://github.com/summonwill/AI-Bootstrap-Framework)
- **Discord**: Coming soon

---

## 📄 License

MIT License — Open source, enterprise-friendly.

See [LICENSE](LICENSE) for details.

---

**ABS Studio** — The Governance OS for Safe, Predictable AI Development.

*Built by [AI Bootstrap Systems](https://aibootstrapsystems.com)*
