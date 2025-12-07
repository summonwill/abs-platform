# ABS Platform

**End-to-End AI Project Development. Any Industry. Any Platform. Governed.**

[![MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Pro Tier](https://img.shields.io/badge/tier-Pro%20%2419%2Fmo-green.svg)](https://aibootstrapsystems.com/#pricing)

> **ABS Platform** is the governance framework for AI-assisted project development. Not just code — any project, any industry. From ideation to delivery, with AI agents that follow YOUR rules.

---

## 🎯 What Is This?

**The problem**: AI tools help with pieces — code completion here, document drafting there. But who governs the AI across your entire project? Who ensures consistency, tracks decisions, maintains context?

**The solution**: ABS Platform. A unified environment where AI agents work on your projects end-to-end, governed by rules YOU define.

### Works For Any Industry

| Industry | Project Types | AI Helps With |
|----------|---------------|---------------|
| **Software** | Apps, APIs, websites | Code, testing, deployment |
| **Finance** | Models, reports, analysis | Excel, VBA, data processing |
| **Marketing** | Campaigns, content, analytics | Copy, strategy, reporting |
| **Consulting** | Deliverables, presentations | Research, documents, decks |
| **Legal** | Contracts, compliance, reviews | Drafting, analysis, tracking |
| **Research** | Papers, data, experiments | Analysis, writing, citations |
| **Operations** | Processes, SOPs, workflows | Documentation, automation |
| **Any Project** | Your workflow | Your rules, your way |

### Multi-Platform

Start on your desktop. Continue on your phone. Pick up on your tablet.

- ✅ **Windows** (available now)
- ✅ **macOS** (available now)
- 🔜 **Linux** (coming soon)
- 🔜 **iOS** (coming soon)
- 🔜 **Android** (coming soon)
- 🔜 **Web** (coming soon)

---

## ✨ Core Features

### 🏛️ Governance — Your Rules, Always Followed

Every project gets governance files that ALL AI agents obey:

| File | Purpose |
|------|---------|
| `AI_RULES_AND_BEST_PRACTICES.md` | Your standards, constraints, preferences |
| `AI_CONTEXT_INDEX.md` | Domain knowledge, project structure |
| `TODO.md` | Prioritized task tracking |
| `SESSION_NOTES.md` | Automatic session documentation |

**The AI can't go rogue.** It reads your rules before every action.

### 🤖 Bring Your Own AI

Not locked to any provider. Use what works for you:

| Provider | Type | Status |
|----------|------|--------|
| **OpenAI** (GPT-4) | Cloud | ✅ Available |
| **Anthropic** (Claude) | Cloud | ✅ Available |
| **Google** (Gemini) | Cloud | ✅ Available |
| **Ollama** | Local/Free | 🔜 Coming |
| **OpenRouter** | Multi-model | 🔜 Coming |

Your API keys. Your data stays yours.

### 📁 Full Project Management

Not just chat — full project control:

- **File Explorer**: Navigate, create, edit, delete
- **AI File Operations**: AI can CREATE, UPDATE, DELETE files (with your permission)
- **Live Updates**: See changes as they happen
- **Multi-Window**: Chat + file editor side by side

### 📝 Session Intelligence

Every work session is tracked:

- **Auto-documentation**: AI summarizes what was accomplished
- **Topic tracking**: Tag discussions with `#topic:auth`
- **Smart updates**: Only logs meaningful progress
- **Full history**: Search across all sessions

### 🔮 Future: Multi-Agent Teams

Coming soon — multiple AI agents working in parallel:

- **Specialized agents**: UI Agent, API Agent, Test Agent, Docs Agent
- **Coordinated work**: Agents pass tasks to each other
- **All governed**: Every agent follows your rules
- **Human oversight**: You see everything, control everything

---

## 🚀 Quick Start

### Download & Run

1. **Download** the latest release for your platform
2. **Launch** ABS Platform
3. **Add API Key** (Settings → API Keys → paste your key)
4. **Create Project** (or open existing folder)
5. **Start Session** → AI chat opens with your project context loaded

### For Developers (Build from Source)

```bash
git clone https://github.com/summonwill/abs-platform.git
cd abs-platform
flutter pub get
flutter run -d windows  # or macos, linux
```

---

## 🔑 AI Provider Setup

| Provider | Get API Key | Cost |
|----------|-------------|------|
| **OpenAI** | [platform.openai.com](https://platform.openai.com) | Pay per use |
| **Anthropic** | [console.anthropic.com](https://console.anthropic.com) | Pay per use |
| **Google** | [aistudio.google.com](https://aistudio.google.com) | Free tier available |
| **Ollama** | [ollama.ai](https://ollama.ai) | Free (runs locally) |

---

## 📁 Governance Files Explained

These files are the "constitution" for AI behavior in your project:

### AI_RULES_AND_BEST_PRACTICES.md
```markdown
# Rules for AI in This Project

## Code Standards
- Use TypeScript strict mode
- All functions must have JSDoc comments
- No console.log in production code

## Behavior
- Never delete files without explicit confirmation
- Always explain changes before making them
- Ask clarifying questions when requirements are ambiguous
```

### AI_CONTEXT_INDEX.md
```markdown
# Project Context

## Overview
This is an e-commerce platform for selling handmade crafts.

## Key Technologies
- Frontend: Next.js 14
- Backend: Node.js + PostgreSQL
- Payments: Stripe

## Domain Terms
- "Artisan" = seller on our platform
- "Collection" = group of related products
```

### TODO.md
```markdown
# Project Tasks

## In Progress
- [ ] Implement checkout flow
- [ ] Add product search

## Completed
- [x] User authentication
- [x] Product listing page
```

### SESSION_NOTES.md
```markdown
# Session History

## Session 5: Dec 7, 2025 - Checkout Implementation ✅

### Summary
Implemented the checkout flow with Stripe integration.

### Key Decisions
- Using Stripe Checkout (hosted) for v1
- Will add custom checkout in v2

### Files Modified
- `pages/checkout.tsx`
- `lib/stripe.ts`
```

---

## 💰 Pricing

| Tier | Price | Best For |
|------|-------|----------|
| **Open Source** | Free | DIY governance (files only) |
| **Pro** | $19/mo | Individual professionals |
| **Team** | $299/mo | Small teams, shared governance |
| **Enterprise** | Custom | Large orgs, compliance needs |

[View Full Pricing →](https://aibootstrapsystems.com/#pricing)

---

## 🗺️ Roadmap

### Available Now ✅
- Multi-provider AI chat (OpenAI, Anthropic, Gemini)
- Governance files auto-loaded into every session
- Full file management with AI operations
- Session tracking with auto-documentation
- Smart session notes (AI-decided updates)
- Topic tracking
- Windows & macOS support

### Coming Soon 🔜
- **Python/Script Execution** — Run scripts, automate Excel
- **Ollama Integration** — Free local AI
- **Mobile Apps** — iOS & Android
- **Web Version** — Use from any browser

### Future Vision 🚀

#### Phase 1: Multi-Session Windows
- Multiple sessions running simultaneously
- Work on different aspects in parallel

#### Phase 2: Multi-Agent Architecture
- Specialized AI agents (UI, API, Testing, Docs)
- Agent-to-agent coordination via PASSDOWN.md
- Task queue with dependency tracking

#### Phase 3: Governed Agent Teams
- Full multi-agent orchestration
- All agents follow your governance files
- Human dashboard with complete oversight
- "Build me X" → agents coordinate to deliver

---

## 🏢 Use Cases

### Software Development Agency
> "We use ABS Platform for all client projects. The governance files ensure every developer AND every AI follows the same standards. Session notes give clients visibility into progress."

### Financial Analyst
> "I manage Excel models and reports. The AI helps me write VBA macros, analyze data, and document my process — all while following my firm's compliance rules."

### Solo Entrepreneur
> "I'm building a SaaS product alone. ABS Platform is like having a junior dev team that never forgets context and always follows my coding standards."

### Consulting Firm
> "Each engagement gets its own project with tailored governance. The AI helps with research, drafting, and documentation while respecting client confidentiality rules."

---

## 📚 Resources

- **Website**: [aibootstrapsystems.com](https://aibootstrapsystems.com)
- **Whitepaper**: [Deterministic AI Development](https://aibootstrapsystems.com/AI-Bootstrap-Systems-Determinism-Whitepaper.pdf)
- **Framework**: [AI Bootstrap Framework (GitHub)](https://github.com/summonwill/AI-Bootstrap-Framework)

---

## 📄 License

MIT License — Open source, enterprise-friendly.

---

**ABS Platform** — End-to-End AI Project Development. Any Industry. Any Platform. Governed.

*Built by [AI Bootstrap Systems](https://aibootstrapsystems.com)*
