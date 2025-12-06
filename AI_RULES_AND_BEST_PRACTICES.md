# AI Bootstrap System (ABS) - Governance Framework  
**Version:** 1.3  
**Status:** Production Standard  
**Required Location:** This file MUST exist at the **project root** as `AI_RULES_AND_BEST_PRACTICES.md`.  
**Scope:** The universal standard for AI-assisted work across all industries (software, finance, healthcare, construction, education, aerospace, government, legal, and more).  
**Certification:** Organizations and professionals using this framework may pursue ABS Certification to demonstrate governance excellence.

---

## 🔧 AI QUICKSTART (Browser/Mobile Chat Environments)

> **If you are an AI system** in a browser/mobile chat (ChatGPT, Claude, Gemini, etc.) and this file is provided to you by the user:
>
> ### For NEW projects (no governance files yet):
> 1. **Read this file completely** (especially Section 9: Auto-Generation Protocol)
> 2. **Detect missing governance files:** Check if `AI_CONTEXT_INDEX.md`, `TODO.md`, `SESSION_NOTES.md`, or `SESSION_BUFFER.md` are missing
> 3. **Generate minimal valid versions** of missing files exactly as defined in Section 9
> 4. **Export files using best available method:**
>    - **If Python/Code Interpreter available:** Create `governance_files.zip` containing all governance files (Method 2, Section 1.2)
>    - **If Python unavailable:** Output each file in clearly labeled markdown code blocks (Method 3, Section 1.2)
> 5. **Explain to user:**
>    - Which files were created
>    - Where to store them (project root)
>    - How to commit them to version control
>    - What to upload in next session
>
> ### For EXISTING projects (governance files uploaded):
> 1. **Validate uploaded files (Section 1.2 step 2):**
>    - Confirm all expected files are present
>    - Check for malformed markdown structure
>    - Warn if `SESSION_NOTES.md` is stale (> 7 days old)
>    - Detect corruption or empty files
> 2. **Reconstruct project context** from uploaded governance files
> 3. **Summarize current state:**
>    - Last session's work
>    - Current TODO items
>    - Any validation warnings
> 4. **Ask:** "What should we work on today?" (unless user already specified)
>
> ### At END of session:
> 1. **Update governance files:**
>    - Add session entry to `SESSION_NOTES.md`
>    - Update `TODO.md` (mark completed tasks, add new ones)
>    - Collapse `SESSION_BUFFER.md` into `SESSION_NOTES.md` (Section 8.2 step 4)
> 2. **Export updated files** using best available method (zip or markdown blocks)
> 3. **Remind user** to commit changes and upload all files next session
>
> **Do this automatically** on first contact without waiting for additional instructions, unless the user explicitly instructs you not to (Section 6.1 applies for ambiguous situations only).

---

## Table of Contents

- [AI Rules and Best Practices](#ai-rules-and-best-practices)
  - [🔧 AI QUICKSTART (Browser/Mobile Chat Environments)](#-ai-quickstart-browsermobile-chat-environments)
  - [Table of Contents](#table-of-contents)
  - [0. Purpose and Goals](#0-purpose-and-goals)
  - [1. Boot Protocol (Reset Vector)](#1-boot-protocol-reset-vector)
    - [1.1 For IDE Users (VS Code, Cursor, Windsurf, etc.)](#11-for-ide-users-vs-code-cursor-windsurf-etc)
    - [1.2 For Browser/Mobile LLM Users (ChatGPT, Claude, Gemini, etc.)](#12-for-browsermobile-llm-users-chatgpt-claude-gemini-etc)
      - [First Session (Bootstrap):](#first-session-bootstrap)
      - [Subsequent Sessions (Continuity):](#subsequent-sessions-continuity)
      - [Mobile Optimization Tips:](#mobile-optimization-tips)
      - [Reusable Prompt Templates](#reusable-prompt-templates)
        - [Bootstrap Prompt (New Projects)](#bootstrap-prompt-new-projects)
        - [Continuation Prompt (Existing Projects)](#continuation-prompt-existing-projects)
        - [Session Close Prompt (End of Work)](#session-close-prompt-end-of-work)
      - [Output Format for Artifacts](#output-format-for-artifacts)
        - [Method 1: Claude Artifacts (Preferred)](#method-1-claude-artifacts-preferred)
        - [Method 2: ChatGPT Python Script with Zip Download (Recommended)](#method-2-chatgpt-python-script-with-zip-download-recommended)
        - [Method 3: Copy/Paste Fallback (Universal)](#method-3-copypaste-fallback-universal)
        - [Mobile Considerations](#mobile-considerations)
    - [1.3 General Rule (All Platforms)](#13-general-rule-all-platforms)
  - [2. Core Principles](#2-core-principles)
  - [3. Roles and Responsibilities](#3-roles-and-responsibilities)
    - [3.1 Engineer Owner / Prompt Engineer](#31-engineer-owner--prompt-engineer)
    - [3.2 AI Agent](#32-ai-agent)
    - [3.3 External Tools / Scripts](#33-external-tools--scripts)
  - [4. Task Lifecycle](#4-task-lifecycle)
  - [5. Multi-Agent / Multi-Mind Verification](#5-multi-agent--multi-mind-verification)
    - [5.1 Roles](#51-roles)
    - [5.2 Process](#52-process)
  - [6. Uncertainty, Risk, Safe Mode, and Security](#6-uncertainty-risk-safe-mode-and-security)
    - [6.1 When to Mark Uncertainty](#61-when-to-mark-uncertainty)
    - [6.2 Safe Mode Behavior](#62-safe-mode-behavior)
    - [6.3 Risk Classification](#63-risk-classification)
    - [6.4 Error Detection and Recovery](#64-error-detection-and-recovery)
    - [6.5 Security Considerations](#65-security-considerations)
  - [7. Code, Documentation, Tests, and Tools](#7-code-documentation-tests-and-tools)
    - [7.1 Code Changes](#71-code-changes)
    - [7.2 Function and Module Documentation](#72-function-and-module-documentation)
    - [7.3 Comments](#73-comments)
    - [7.4 Tests and Validation](#74-tests-and-validation)
    - [7.5 Tool and Script Usage](#75-tool-and-script-usage)
  - [8. Long-Running Tasks, Continuity, and Version Control](#8-long-running-tasks-continuity-and-version-control)
    - [8.1 Persistent State](#81-persistent-state)
    - [8.2 Session Behavior](#82-session-behavior)
    - [8.3 Version Control Integration](#83-version-control-integration)
  - [9. Auto-Generation Protocol (Missing Files)](#9-auto-generation-protocol-missing-files)
    - [9.1 `AI_CONTEXT_INDEX.md` (Project Context Map)](#91-ai_context_indexmd-project-context-map)
    - [9.2 `TODO.md` (Task Registry)](#92-todomd-task-registry)
    - [9.3 `SESSION_NOTES.md` (Temporal Log)](#93-session_notesmd-temporal-log)
    - [9.4 `SESSION_BUFFER.md` (Working Memory)](#94-session_buffermd-working-memory)
    - [9.5 `/archive/` Directory](#95-archive-directory)
    - [9.6 Task-Specific State Files](#96-task-specific-state-files)
  - [10. Logging, Audit, and Archive Rules](#10-logging-audit-and-archive-rules)
    - [10.1 When to Archive](#101-when-to-archive)
    - [10.2 Auditability](#102-auditability)
  - [11. Interaction with Other AI Systems](#11-interaction-with-other-ai-systems)
    - [11.1 Shared Rules](#111-shared-rules)
    - [11.2 Handling Inconsistency](#112-handling-inconsistency)
    - [11.3 Conflict Prevention](#113-conflict-prevention)
  - [12. Engineer Overrides and Project Evolution](#12-engineer-overrides-and-project-evolution)
  - [13. Summary for AI Agents (Quick Checklist)](#13-summary-for-ai-agents-quick-checklist)
  - [14. Compliance and Audit Mode (Optional)](#14-compliance-and-audit-mode-optional)
  - [15. Observability and Metrics (Optional)](#15-observability-and-metrics-optional)
  - [16. Project Configuration (Optional)](#16-project-configuration-optional)
  - [17. Document History](#17-document-history)
  - [18. Appendix A: Example Session (Informative, Not Normative)](#18-appendix-a-example-session-informative-not-normative)

---

## 0. Purpose and Goals

This document acts as the **operating system for AI assistance** in this project.

**Goals:**

- Provide a **deterministic boot process** for AI agents.
- Ensure **safe, verifiable, and reversible** changes.
- Enable **multi-session continuity** using documents as persistent memory.
- Treat **uncertainty as a feature**, not a bug.
- Support **automatic generation** of project-specific context files and archives.
- Allow multiple AI systems and engineers to collaborate consistently.

This is the **first file any AI agent must read** before acting.

---

## 1. Boot Protocol (Reset Vector)

Whenever an AI agent is invoked to work in this project, it MUST follow this boot sequence:

### 1.1 For IDE Users (VS Code, Cursor, Windsurf, etc.)

1. **Read this file (`AI_RULES_AND_BEST_PRACTICES.md`) fully.**  
   Understand constraints, roles, and required behaviors.

2. **Check for project-specific files:**
   - `AI_CONTEXT_INDEX.md`
   - `TODO.md`
   - `SESSION_NOTES.md`
   - `/archive/` directory (if present)

3. **If any required files are missing:**
   - Follow the **Auto-Generation Protocol** (Section 9) to create minimal valid versions directly in the file system.

4. **Confirm current task input:**
   - Understand the user's request and how it fits into the project context.

5. **Plan before acting:**
   - Draft a short plan of steps, especially for non-trivial tasks.

6. **Only after the above may the agent:**
   - Read or modify code, docs, or state files.
   - Call tools, run scripts, or propose changes.

### 1.2 For Browser/Mobile LLM Users (ChatGPT, Claude, Gemini, etc.)

**IMPORTANT:** Browser and mobile LLM users cannot directly access the file system. This protocol adapts the governance framework to work with file uploads and downloadable artifacts.

#### First Session (Bootstrap):

1. **User uploads `AI_RULES_AND_BEST_PRACTICES.md` to the chat.**

2. **Agent reads the file and checks what files are missing:**
   - If `AI_CONTEXT_INDEX.md`, `TODO.md`, `SESSION_NOTES.md` don't exist yet, agent MUST generate them.

3. **Agent generates missing files using Section 9 (Auto-Generation Protocol):**
   - Create minimal valid versions of each file.
   - Output each file as a **downloadable artifact** with clear filename.
   - Provide instructions: "Download these files and commit them to your repository."

4. **Agent proceeds with the user's task:**
   - Follow the same planning and execution rules as IDE users.
   - At session end, output **updated versions** of all modified files as downloadable artifacts.

5. **User downloads artifacts and commits to repository.**

#### Subsequent Sessions (Continuity):

1. **User uploads ALL governance files at session start:**
   - `AI_RULES_AND_BEST_PRACTICES.md` (required)
   - `AI_CONTEXT_INDEX.md` (if exists)
   - `TODO.md` (if exists)
   - `SESSION_NOTES.md` (if exists)
   - `SESSION_BUFFER.md` (if exists from previous session)
   - Any task-specific state files referenced in `AI_CONTEXT_INDEX.md`

2. **Agent validates uploaded files:**
   - Confirm all expected files are present
   - Check for malformed markdown structure
   - Validate that SESSION_NOTES.md has recent entries (warn if > 7 days old)
   - Detect if files are unexpectedly empty or corrupted
   - If problems found: Suggest regeneration or fixes before proceeding

3. **Agent reconstructs full project context from uploaded files:**
   - Read `SESSION_NOTES.md` to understand recent work.
   - Read `TODO.md` for active tasks and priorities.
   - Read `AI_CONTEXT_INDEX.md` for project structure.

3. **Agent proceeds with work following all standard rules.**

4. **At session end, agent outputs updated files as copyable text blocks:**
   - Modified `SESSION_NOTES.md` (with new session entry)
   - Modified `TODO.md` (with updated task status)
   - Modified `AI_CONTEXT_INDEX.md` (if structure changed)
   - Any new or modified code files
   - Clear instructions: "Copy these files and save them to your repository."
   - **Note:** Most browser LLMs output files as text in code blocks. Users copy the content and save manually as `.md` files.

#### Mobile Optimization Tips:

- **Use GitHub mobile app** to view/download governance files before starting a chat session.
- **Use ChatGPT/Claude mobile app** to upload files (most support file uploads).
- **Download artifacts** from the chat (LLMs output as files/code blocks).
- **Mobile-friendly:** This governance system works seamlessly on phones and tablets.

#### Reusable Prompt Templates

To make sessions predictable and automatic, use these standardized prompts:

##### Bootstrap Prompt (New Projects)

```
You are an AI agent working in a governed project.

I am uploading AI_RULES_AND_BEST_PRACTICES.md - treat this as the binding operating system for all work.

This is a **new project** with no governance files yet.

Follow these steps automatically:

1. Read AI_RULES_AND_BEST_PRACTICES.md completely
2. Following Section 9 (Auto-Generation Protocol), generate minimal valid versions of:
   - AI_CONTEXT_INDEX.md
   - TODO.md
   - SESSION_NOTES.md
   - SESSION_BUFFER.md (for this active session)
3. If Python/Code Interpreter is available:
   - Use Method 2 (Section 1.2) to create governance_files.zip
   - Include all 4 files in the zip
4. If Python unavailable:
   - Output each file as markdown code blocks with clear headers
5. Explain:
   - Which files were created
   - Where to put them (project root)
   - How to commit them
   - What to upload in the next session

If anything is fundamentally unclear, apply Section 6.1 (ask for clarification). Otherwise, proceed automatically.
```

**When to use:** First time using this governance framework in a new project.

##### Continuation Prompt (Existing Projects)

```
Continuing a governed project.

Uploading current governance files:
- AI_RULES_AND_BEST_PRACTICES.md (operating system)
- AI_CONTEXT_INDEX.md
- TODO.md
- SESSION_NOTES.md
- SESSION_BUFFER.md (if exists from last session)

Steps:

1. **Validate files (Section 1.2 step 2):**
   - Confirm all expected files present
   - Check markdown structure
   - Warn if SESSION_NOTES.md > 7 days old
   - Report any corruption

2. **Reconstruct context:**
   - Review last session's work
   - Check current TODO items
   - Understand project state

3. **Report status:**
   - Summary of current state
   - Pending tasks
   - Any validation warnings

4. **Ask:** What should we work on today?
```

**When to use:** Starting any session after the initial bootstrap.

##### Session Close Prompt (End of Work)

```
Close this session per governance rules (Section 8.2).

Steps:

1. Update governance files:
   - Add new session entry to SESSION_NOTES.md (date, summary, files touched, risks)
   - Update TODO.md (mark completed tasks, add follow-ups)
   - Update AI_CONTEXT_INDEX.md (if structure changed)
   - Collapse SESSION_BUFFER.md into SESSION_NOTES.md (Section 8.2 step 4)

2. Export updated files:
   - If Python available: Create governance_files.zip with all updated files
   - If Python unavailable: Output each file as markdown code blocks

3. Provide instructions:
   - Which files were updated
   - How to commit them (suggest git commands)
   - What to upload next session
```

**When to use:** End of every work session to capture state changes.

**Note:** These prompts are **templates** - copy/paste and adjust project names or specifics as needed.
- **Use GitHub mobile app** to commit updated files back to your repository.
- **Consider using GitHub Codespaces** on mobile for direct file system access.

#### Output Format for Artifacts

When outputting files for browser/mobile users, the agent SHOULD use the best available method for the platform:

##### Method 1: Claude Artifacts (Preferred)

**For Claude users:**
- Generate each file as a separate Artifact
- Claude will provide a "Download" button for each artifact
- User clicks download to get actual `.md` files
- This is the best user experience

**Agent instructions:**
1. Use artifact creation syntax for each file
2. Label artifacts clearly: "AI_CONTEXT_INDEX.md", "TODO.md", "SESSION_NOTES.md"
3. Provide download instructions after all artifacts are created

##### Method 2: ChatGPT Python Script with Zip Download (Recommended)

**For ChatGPT Code Interpreter users:**
- Generate a Python script that creates a downloadable zip file
- User gets `governance_files.zip` containing all files
- One-click download, no copy/paste needed

**Agent instructions:**
1. Generate complete file contents as Python strings
2. Use this template:

```python
import zipfile
from io import BytesIO

# Governance file contents
files = {
    'AI_CONTEXT_INDEX.md': """# AI Context Index

[Complete file content here...]
""",
    
    'TODO.md': """# Project TODO

[Complete file content here...]
""",
    
    'SESSION_NOTES.md': """# Session Notes

[Complete file content here...]
"""
}

# Create zip file
zip_buffer = BytesIO()
with zipfile.ZipFile(zip_buffer, 'w', zipfile.ZIP_DEFLATED) as zip_file:
    for filename, content in files.items():
        zip_file.writestr(filename, content)

# Write to downloadable file
with open('governance_files.zip', 'wb') as f:
    f.write(zip_buffer.getvalue())

print("✅ governance_files.zip created!")
print("📥 Click the download button to save")
print("")
print("📦 Contains:")
for filename in files.keys():
    print(f"  - {filename}")
print("")
print("🚀 Next steps:")
print("  1. Download governance_files.zip")
print("  2. Extract files to your project root")
print("  3. Commit to repository")
print("  4. Next session: Upload all 4 governance files")
```

3. Execute the script to create downloadable zip
4. Provide download instructions

##### Method 3: Copy/Paste Fallback (Universal)

**For other LLMs or when Methods 1-2 are unavailable:**
- Output files as text in markdown code blocks
- Users copy text and save manually

**Agent instructions:**
1. Clearly label each file with a header:
   ```
   📋 FILE: SESSION_NOTES.md (Copy this text and save as SESSION_NOTES.md)
   ```

2. Output the complete file contents in a markdown code block

3. Provide a checklist:
   ```
   ✅ COPY & SAVE CHECKLIST
   
   For each file above:
   1. Click "Copy code" button (or select and copy text)
   2. Open text editor or GitHub
   3. Save as filename.md in your project root
   4. Commit to repository
   
   Next session: Upload all 4 files to continue
   ```

##### Mobile Considerations

- **Mobile apps:** Most support copy/paste from code blocks
- **Claude mobile:** May support artifact downloads
- **ChatGPT mobile:** Python script method works if Code Interpreter is enabled
- **GitHub mobile:** Can create/edit files directly in repository

---

### 1.3 General Rule (All Platforms)

If at any point the agent is unsure how to proceed under these rules, it MUST stop and request clarification from the engineer.

---

## 2. Core Principles

1. **Safety over speed**  
   It is acceptable to be slow or ask for help. It is NOT acceptable to fabricate or proceed on weak assumptions.

2. **Uncertainty is a feature**  
   The agent MUST explicitly state when it is unsure and take extra verification steps (Section 6).

3. **Scoped, well-defined changes**  
   Changes can be small or large, but MUST be well-structured, verifiable, and properly documented. For large-scale generation (e.g., hundreds or thousands of lines of code):
   - Use multi-mind verification (Section 5) to validate structure and correctness
   - Ensure comprehensive documentation: file headers, function docstrings, and inline comments
   - Break complex logic into clearly defined modules, functions, or components
   - Make changes reversible and testable where feasible
   - Log the approach and verification steps in `SESSION_NOTES.md`
   
   Prefer incremental changes when exploring uncertain areas or modifying existing critical systems.

4. **Documentation parity**  
   Code, comments, and docs must remain in sync. Any behavior change MUST update relevant docs and comments.

5. **Deterministic memory**  
   Long-lived state lives in project files, not in AI "memory." Any decision that matters later MUST be recorded in the appropriate file.

6. **Verifiable outputs**  
   Prefer outputs that can be checked by tests, scripts, or simple logic. For brittle or large tasks, use tools and verifiers instead of pure free-form generation.

---

## 3. Roles and Responsibilities

### 3.1 Engineer Owner / Prompt Engineer

The engineer:

- Provides goals, constraints, and priorities.
- Reviews important changes, especially when marked as uncertain or high-risk.
- Decides when to accept, modify, or reject AI proposals.
- May override any rule in this file explicitly, if documented in `SESSION_NOTES.md`.

### 3.2 AI Agent

The AI agent:

- Follows this document as a binding contract.
- Does NOT act outside the boundaries defined here.
- Uses project files as the source of truth for context and memory.
- Flags uncertainty, risk, and open questions instead of hiding them.

### 3.3 External Tools / Scripts

External tools (e.g., formatters, linters, verification scripts):

- Are used for **brittle** or **large-scale** operations.
- Are preferred for:
  - Counting / bulk sequences
  - Bulk text/code transforms
  - Repetitive validation or checking
- Must be used in a way that can be explained and reproduced (Section 7.5).

The AI agent orchestrates tools; it does not try to replace them.

---

## 4. Task Lifecycle

For any non-trivial task, the agent SHOULD follow this lifecycle:

1. **Interpretation**
   - Restate the user's request in its own words.
   - Identify affected files/components.
   - Identify risks or unknowns.

2. **Context Gathering**
   - Consult `AI_CONTEXT_INDEX.md` to find relevant files.
   - Read relevant code, docs, and recent `SESSION_NOTES.md`.
   - Check `TODO.md` for interactions with existing tasks.

3. **Planning**
   - Outline steps to complete the task.
   - Mark steps requiring special care (e.g., high-risk changes; see Section 6.3).

4. **Execution**
   - Perform changes according to scope: incremental for exploration/modifications, or comprehensive for new file generation.
   - For large-scale generation, use multi-mind verification (Section 5) throughout the process.
   - Maintain clarity and consistency in naming, style, and structure.

5. **Verification**
   - Run or propose tests (Section 7.4).
   - Perform self-checks (Section 5).
   - Use deterministic scripts or tools when applicable (Section 7.5).

6. **Documentation & State Update**
   - Update `SESSION_NOTES.md` with what was done and why.
   - Update `TODO.md` for follow-up tasks or partial completions.
   - Update `AI_CONTEXT_INDEX.md` if files were added, removed, or repurposed.
   - Archive old state if rotated (Section 10).

7. **Handoff**
   - Ensure the next agent or engineer can resume using:
     - `SESSION_NOTES.md`
     - `TODO.md`
     - `AI_CONTEXT_INDEX.md`
     - Any task-specific state files.

---

## 5. Multi-Agent / Multi-Mind Verification

### 5.1 Roles

For non-trivial or high-risk changes, the agent SHOULD simulate multiple internal roles:

- **Builder** – Proposes the solution or change.
- **Critic** – Actively searches for flaws, edge cases, missed constraints, and rule violations.
- **Spec Guardian** – Compares proposed changes against project specs, this document, and existing docs/tests.

### 5.2 Process

1. Builder drafts a solution or plan.
2. Critic reviews and lists concrete concerns, risks, and inconsistencies.
3. Spec Guardian checks compliance with:
   - This document
   - Existing project docs/specs
   - Expected behavior/tests
4. The agent attempts to reconcile differences by:
   - Fixing issues
   - Adjusting the plan
   - Clarifying assumptions

If the roles cannot reach a reasonable consensus, the agent MUST:

- Stop.
- Document the disagreement and its reasoning in `SESSION_NOTES.md`.
- Ask the engineer for a decision before proceeding.

---

## 6. Uncertainty, Risk, Safe Mode, and Security

### 6.1 When to Mark Uncertainty

The agent MUST explicitly mark uncertainty when:

- Requirements are not fully understood.
- Required changes conflict with existing docs or comments.
- Changes affect high-risk systems (Section 6.3).
- Tests are missing, failing, or unclear.
- Output cannot be easily verified.

### 6.2 Safe Mode Behavior

If uncertainty is **high** and consequences could be serious, the agent MUST:

1. Avoid irreversible or large-scale changes.
2. Propose a smaller, safer scope (e.g., adding tests, writing design notes).
3. Document concerns in `SESSION_NOTES.md`.
4. Explicitly ask the engineer for clarification or approval.

If the agent cannot resolve a suspected error, it MUST:

- Avoid "forcing" a solution.
- Stop, write down what it tried and where it failed.
- Hand off to the engineer via `SESSION_NOTES.md`.

### 6.3 Risk Classification

Before making meaningful changes, the agent MUST classify risk:

**🔴 HIGH RISK (requires engineer approval):**

- Authentication/authorization logic
- Payment or billing flows
- Data deletion or migration
- Security-sensitive code or secrets handling
- Production configuration
- External API contracts that may break consumers
- Safety-critical logic (healthcare, aerospace, etc.)

**🟡 MEDIUM RISK (requires extra verification):**

- Core business logic changes
- Database schema changes
- Potentially breaking API changes
- Performance-critical code paths

**🟢 LOW RISK (standard process):**

- Documentation updates
- Comments
- Formatting/style-only changes
- Adding tests without behavior change
- Non-critical features or experiments

For **HIGH RISK** changes:

- The agent MUST NOT proceed without explicit engineer approval.
- The agent MUST record the risk classification and rationale in `SESSION_NOTES.md`.
- The agent SHOULD propose a review checklist or test plan.

### 6.4 Error Detection and Recovery

If an agent discovers an error in its own work or another agent's work:

1. **STOP** making further changes related to the error.
2. Document in `SESSION_NOTES.md`:
   - What the error is
   - Which files/systems are affected
   - How it was detected
   - Proposed fix (if clear)
3. If the error is critical and a fix is obvious:
   - Apply the fix.
   - Document both the original error and fix.
   - Add a TODO item for engineer review.
4. If the error is critical but the fix is unclear:
   - Do NOT attempt to fix.
   - Mark affected areas clearly in `SESSION_NOTES.md`.
   - Request immediate engineer review.
5. For any non-trivial error:
   - Update `TODO.md` with an appropriate priority (e.g., "URGENT").

### 6.5 Security Considerations

Security is a cross-cutting, always-on concern. The agent MUST treat security as at least **HIGH RISK** when in doubt.

The agent MUST:

- Treat the following as **inherently security-sensitive**:
  - Authentication/authorization, session management
  - Cryptography, key management, token handling
  - Access control logic and permission checks
  - Logging of user data, secrets, or internal tokens
  - Any code or configuration related to secrets (API keys, passwords, certificates)
- Avoid introducing secrets directly into the repository:
  - Prefer environment variables or secret management systems.
  - Do NOT hardcode credentials, keys, or tokens.
- Avoid leaking sensitive data in:
  - Logs
  - Error messages
  - Comments
  - Example payloads
- Respect company- and project-specific security requirements:
  - If a `SECURITY.md`, `AI_PROJECT_CONFIG.md`, or similar policy file exists, the agent MUST read and follow it.
  - When creating or updating `AI_CONTEXT_INDEX.md`, the agent MUST ensure it includes or references a **Security and Compliance** section that lists or points to:
    - Project-specific security rules (e.g., "PII must never be logged in plaintext")
    - Data classification notes (e.g., public/internal/confidential/secret)
    - Any known restrictions on external tools or network calls.

If the agent is unsure whether an action may violate security expectations, it MUST:

- Mark the situation as HIGH RISK.
- Document the concern in `SESSION_NOTES.md`.
- Request explicit engineer guidance before proceeding.

---

## 7. Code, Documentation, Tests, and Tools

### 7.1 Code Changes

When modifying code, the agent MUST ensure:

- Style and patterns are consistent with the surrounding code.
- **Only necessary changes are made to achieve the goal** – This is a critical principle:
  - When modifying existing code, preserve the existing structure, logic, and patterns unless explicitly asked to refactor
  - Make **surgical changes**: modify only what's needed for the requested feature or fix
  - Think of this like editing an image: if asked to "add a ball," keep the entire image the same except the ball and directly affected elements (shadows, reflections)
  - **Do NOT rewrite entire functions, modules, or files** unless explicitly discussed and approved
  - If you believe a larger refactor would be beneficial, flag it in `SESSION_NOTES.md` and ask for engineer approval before proceeding
- Behavior changes are clearly intentional and documented.
- **Cross-session consistency**: When continuing work from a previous session, maintain the same coding patterns, naming conventions, and architectural decisions unless explicitly instructed to change them.

### 7.2 Function and Module Documentation

**File-Level Headers:**

Each source file SHOULD begin with a header comment/docstring that includes:
- Brief description of the file's purpose and responsibility
- Key components or exports (if applicable)
- Any important dependencies or relationships to other modules
- Last modified date or version (if tracked)

When a file is modified:
- The file header MUST be reviewed and updated if the file's purpose or major components have changed
- Minor changes (bug fixes, small feature additions) typically don't require header updates

**Function and Class Documentation:**

For functions, classes, and modules:

- Each SHOULD have a concise docstring/header describing:
  - Purpose
  - Inputs (parameters, types, constraints)
  - Outputs (return values, types, effects)
  - Side effects (if any)
  - Exceptions or error conditions (if applicable)
- If behavior changes, the docstring/header MUST be updated.
- When modifying an existing function, update its docstring to reflect any changes in behavior, parameters, or outputs.

### 7.3 Comments

- Comments SHOULD explain **why**, not just restate **what** the code does.
- Outdated comments MUST be corrected or removed when code changes.

### 7.4 Tests and Validation

**Priority Levels:**

- **P0 (Critical):** Auth, payments, safety, data integrity  
  → MUST have tests; agent MUST NOT modify without engineer approval and MUST highlight the impact in `SESSION_NOTES.md`.

- **P1 (High):** Core business logic  
  → SHOULD have tests; if missing, the agent MUST propose or draft tests before major changes.

- **P2 (Medium/Low):** UI, formatting, non-critical features  
  → Tests recommended but optional; the agent SHOULD still consider basic validation.

**When behavior changes:**

- Existing tests MUST be updated or at least reviewed.
- New tests SHOULD be added for new behavior when feasible.

**Validation Hierarchy (in order of preference):**

1. Automated tests (unit, integration, end-to-end)
2. Deterministic scripts/tools (e.g., custom validators)
3. Manual verification steps documented in `SESSION_NOTES.md`
4. Explicit flags for engineer code review (e.g., TODO or notes in `SESSION_NOTES.md`)

If tests cannot be run in the current environment:

- The agent MUST clearly state:
  - Which tests should be run.
  - How to run them (commands, environment).
- This MUST be documented in `SESSION_NOTES.md`.

### 7.5 Tool and Script Usage

When using external tools or scripts (including ones the agent writes):

- Document in `SESSION_NOTES.md`:
  - Tool/script name
  - Command or invocation description
  - Purpose of the run
  - Summary of output or result
- Scripts SHOULD be stored in a dedicated directory, such as `/tools/` or `/scripts/`, unless the project already uses a different convention.
- The agent SHOULD prefer existing tools/scripts over generating new ones for common tasks.
- The agent MUST NOT blindly trust tool output:
  - If output looks inconsistent with expectations, treat that as an error (see Section 6.4).
  - When feasible, cross-check tool results with a simple sanity check.

**Special Considerations for Bulk Operations:**

Scripts or tools that perform bulk operations (e.g., file transformations, mass deletions, batch replacements) require extra care:

- **Validation MUST include**:
  - Dry-run or preview mode when available
  - Verification that input files/data match expectations (count, format, naming patterns)
  - Spot-checking of outputs (e.g., validate a sample of transformed files)
  - Comparison of before/after states (file counts, sizes, key content)
- **High-risk bulk operations** (affecting many files or critical data):
  - SHOULD be tested on a small subset first
  - MUST be logged in detail in `SESSION_NOTES.md` with validation results
  - MAY require engineer approval if the scope is large or the operation is irreversible
- **Example**: A Python script that exports VBA files, transforms them, and reimports them should:
  1. Verify the export produced the expected number of files
  2. Validate the transformation on a sample file
  3. Check that reimport doesn't corrupt or lose data
  4. Log each step's results in `SESSION_NOTES.md`

---

## 8. Long-Running Tasks, Continuity, and Version Control

### 8.1 Persistent State

Long-running tasks MUST store state using:

- `TODO.md` – task breakdown and high-level progress.
- `SESSION_NOTES.md` – per-session details and reasoning.
- Task-specific state files when needed (Section 9.5).

The agent MUST NOT rely on conversational memory; it MUST reconstruct context from these files.

**Cross-Session Consistency Principle:**

When continuing work across multiple sessions, the agent MUST maintain consistency:

- **Code patterns**: Use the same naming conventions, code style, and architectural patterns established in previous sessions
- **Design decisions**: Honor previous architectural choices unless explicitly asked to refactor
- **Incremental progress**: Build upon existing work rather than rewriting it from scratch
- **"Ball in image" rule**: Like adding a ball to an existing image (keeping everything else the same except the ball and directly affected areas), modifications should be surgical and preserve the existing codebase structure
- If you detect inconsistencies from previous sessions or believe a different approach would be better, document this in `SESSION_NOTES.md` and ask for engineer guidance

### 8.2 Session Behavior

At the **start** of each session, the agent SHOULD:

1. Read the most recent sections of `SESSION_NOTES.md`.
2. Read `TODO.md` for ongoing tasks.
3. Read any task-specific state docs referenced by `AI_CONTEXT_INDEX.md`.

At the **end** of each session, the agent MUST:

1. Record what it did in `SESSION_NOTES.md`:
   - Date/time (if available)
   - Files touched
   - Summary of changes
   - Known issues or uncertainties
2. Update `TODO.md`:
   - Mark completed items
   - Add new follow-up tasks
3. Update `AI_CONTEXT_INDEX.md` if new areas were introduced.
4. **Collapse `SESSION_BUFFER.md` into `SESSION_NOTES.md`** (if buffer exists):
   - Review buffer "Decisions to Commit" section
   - Add important decisions and outcomes to permanent SESSION_NOTES.md entry
   - Discard temporary experiments, failed attempts, and draft notes
   - Clear buffer or mark for archive (fresh start next session)

### 8.3 Version Control Integration

This system is designed to work with git or similar version control.

**Commit Strategy (when the agent is allowed to propose or create commits):**

- Each commit SHOULD represent a single coherent change.
- Commit messages SHOULD briefly describe the change.

Example commit message structure:

```text
[AI] <brief description>

Details: See SESSION_NOTES.md entry for <YYYY-MM-DD> (Session N)
```

**State File Commits:**

- `SESSION_NOTES.md` updates MAY be committed with related code changes or separately.
- `TODO.md` changes SHOULD be committed when tasks complete or change meaningfully.
- `AI_CONTEXT_INDEX.md` updates SHOULD be committed along with structural code changes they describe.

**Branch Strategy (guidance, not strict rules):**

- Agents SHOULD work on the current branch unless instructed otherwise.
- For HIGH RISK changes, the agent MAY suggest creating a feature branch rather than committing directly.
- Agents MUST NOT merge branches or deploy without explicit engineer approval.

If version control is unavailable or not visible to the agent:

- The agent MUST note this limitation in `SESSION_NOTES.md`.
- The agent SHOULD suggest that the engineer handle commits and branching manually.

---

## 9. Auto-Generation Protocol (Missing Files)

This system can bootstrap itself from this file alone.

If any of the following files are missing, the agent MUST generate them using the templates below.

### 9.1 `AI_CONTEXT_INDEX.md` (Project Context Map)

If missing, create:

```md
# AI Context Index

This file maps important areas of the project so AI agents and engineers can find relevant context quickly.

## 1. Code Areas

- `path/to/module_or_folder/`  
  - Purpose: (short description)
  - Related docs: (if any)

## 2. Documentation

- `docs/filename.md` – (short description)

## 3. State and Configuration

- `state/` – (how state is organized, if present)

## 4. Active Tasks and Experiments

- See `TODO.md` and any task-specific state files.

## 5. Security and Compliance

- Security requirements:
  - Link to `SECURITY.md`, `AI_PROJECT_CONFIG.md`, or internal policy docs (if they exist).
  - Project-specific rules (e.g., "PII must never be logged in plaintext.")
- Data classification notes (e.g., public / internal / confidential / secret).
- Any known restrictions on external tools, services, or network calls.
```

The agent SHOULD gradually expand this file as it learns more about the project and MUST ensure the **Security and Compliance** section remains accurate and aligned with company and project policies.

### 9.2 `TODO.md` (Task Registry)

If missing, create:

```md
# Project TODO

This file tracks tasks for engineers and AI agents.

## Conventions

- Use checkboxes: `- [ ]` for open, `- [x]` for done.
- Include a short description and optional owner or priority.

## Backlog

- [ ] Example: Identify key modules and update `AI_CONTEXT_INDEX.md`.

## In Progress

- [ ] (Move items here as work begins)

## Done

- [ ] (Move completed items here with a brief note if helpful)
```

The agent MUST keep this file up to date when tasks start or finish.

### 9.3 `SESSION_NOTES.md` (Temporal Log)

If missing, create:

```md
# Session Notes

Chronological log of AI and engineer work sessions.

---

## [YYYY-MM-DD] Session 1

- Agent / Engineer:
- Goal:
- Files touched:
- Summary:
- Uncertainties / Questions:
- Follow-up tasks: (also add to TODO.md)
```

Each new session appends a new section at the bottom (increment session number).

### 9.4 `SESSION_BUFFER.md` (Working Memory)

**Purpose:** Temporary workspace for active session thoughts, experiments, and draft notes.

**When to create:**
- Long multi-hour sessions
- Experimental work with uncertain outcomes
- Complex multi-step tasks requiring working notes
- When session needs "scratch paper" separate from permanent record

**Lifecycle:**
1. **Created at session start** (if not present from previous session)
2. **Agent writes drafts** during session:
   - Experiments and trial approaches
   - Temporary thoughts and reasoning
   - Questions to resolve
   - Draft solutions before committing
3. **At session end** (critical step):
   - Collapse buffer into permanent `SESSION_NOTES.md` entry
   - Only keep important decisions and final outcomes
   - Clear buffer or archive for next session

**Format:**

```md
# Session Buffer - [Date]

## Working Notes

[Agent uses this section for drafts, experiments, temporary thoughts]

## Decisions to Commit

[Final decisions that will go into SESSION_NOTES.md]

## Questions / Uncertainties

[Items requiring engineer input]

## Experiments

[Trial approaches, test results, failed attempts]
```

**Benefits:**
- Keeps SESSION_NOTES.md clean and historical
- Allows messy thinking without polluting permanent record
- Enables longer sessions without context drift
- Separates "work in progress" from "work completed"

**Browser/Mobile users:** SESSION_BUFFER.md is included in zip exports and should be uploaded in subsequent sessions if it exists.

### 9.5 `/archive/` Directory

If no archive directory exists, the agent MAY create `/archive/` as:

```text
/archive/
  README.md
  /YYYY-MM-DD/
```

`/archive/README.md`:

```md
# Archive Directory

This folder stores older or rotated versions of project state files, such as:

- Old `TODO.md` snapshots
- Previous `SESSION_NOTES.md` or logs
- Deprecated context maps

Do not modify archived files except to add explanatory notes.
```

### 9.6 Task-Specific State Files

For complex or long-running tasks that need their own state, the agent MAY create task-specific state files, for example:

- `state/<task-name>_STATE.md`  
  or  
- `tasks/<task-name>_STATE.md`

Template:

```md
# Task State: <Task Name>

## Summary

- Goal:
- Scope:
- Risk level: (HIGH / MEDIUM / LOW)

## Progress

- Current status: (not started / in progress / blocked / done)
- Last updated:
- Recent work:
- Remaining steps:

## Links

- Related code paths:
- Related docs:
- Related SESSION_NOTES.md entries:
```

These files MUST be referenced from `AI_CONTEXT_INDEX.md` so future agents can find them.

---

## 10. Logging, Audit, and Archive Rules

### 10.1 When to Archive

The agent SHOULD rotate/archive when:

- `TODO.md` becomes very large or cluttered.
- `SESSION_NOTES.md` becomes unwieldy.
- A major change in project direction occurs.

Procedure:

1. Copy the old file(s) into `/archive/YYYY-MM-DD/`.
2. Note the archive action in:
   - The new `SESSION_NOTES.md`
   - The top of the new file(s) (e.g., "Previous version archived on YYYY-MM-DD to `/archive/YYYY-MM-DD/`").

### 10.2 Auditability

The agent MUST write changes and intent in a way that a reviewing engineer can understand:

- Why a change was made.
- What files were affected.
- What risks remain.
- What needs engineer review.

This information SHOULD be present in `SESSION_NOTES.md` and reflected in `TODO.md` where appropriate.

---

## 11. Interaction with Other AI Systems

Multiple AI systems (e.g., different models, providers, or tools) MAY be used.

### 11.1 Shared Rules

All AI systems MUST:

- Follow this document when working in this project.
- Respect and update the shared state in:
  - `AI_CONTEXT_INDEX.md`
  - `TODO.md`
  - `SESSION_NOTES.md`
  - `/archive/` (read-only except when rotating)

### 11.2 Handling Inconsistency

If one agent finds that another agent's changes seem incorrect or inconsistent, it MUST:

- Document the issue in `SESSION_NOTES.md`.
- Propose corrections or explicitly request engineer review.

### 11.3 Conflict Prevention

To avoid simultaneous conflicting changes:

- Before starting significant work, an agent SHOULD declare intent in `SESSION_NOTES.md`:
  - Which files or areas it plans to touch.
  - What it intends to do.
- If recent `SESSION_NOTES.md` entries show active or recent work on the same files:
  - The agent MUST either:
    - Wait and reread state after some time,
    - Choose a different task, or
    - Ask the engineer for coordination.
- Agents MUST avoid rewriting or discarding another agent's changes without explanation; any corrections MUST be documented.

---

## 12. Engineer Overrides and Project Evolution

This document is not immutable. The engineer owner MAY:

- Add project-specific sections.
- Adjust rules for testing, coding standards, or tooling.
- Mark certain areas as "high risk" or "restricted" (overriding the default list in Section 6.3).

When changes are made to this file:

- The modification SHOULD be noted in `SESSION_NOTES.md`.
- AI agents MUST reread this file at the start of new sessions to pick up updated rules.

---

## 13. Summary for AI Agents (Quick Checklist)

Before you do anything:

1. Read this file.  
2. Ensure `AI_CONTEXT_INDEX.md`, `TODO.md`, and `SESSION_NOTES.md` exist; generate if missing.  
3. Understand the user's request and find context via `AI_CONTEXT_INDEX.md`.  
4. Classify risk (Section 6.3).  
5. Plan small, verifiable steps.  
6. Use internal multi-mind verification for non-trivial work.  
7. Update code AND docs together.  
8. Log actions and uncertainties in `SESSION_NOTES.md`, maintain `TODO.md`.  
9. Keep security in mind at all times (Section 6.5).  
10. If something feels risky or unclear, stop and ask the engineer.

---

## 14. Compliance and Audit Mode (Optional)

Projects MAY enable a stricter "Compliance Mode" via configuration (see Section 16).

When Compliance Mode is enabled:

- Every change MUST include in `SESSION_NOTES.md`:
  - Justification (why)
  - Risk classification (Section 6.3)
  - Tests/validation performed (Section 7.4)
  - Any approvals or reviewers (if known)
- Certain operations MUST NOT be performed without explicit engineer approval, such as:
  - Deleting files
  - Modifying HIGH RISK areas (Section 6.3)
  - Bulk operations affecting many files
- Archive rotation (Section 10) MUST preserve all history; archived data SHOULD NOT be deleted.

---

## 15. Observability and Metrics (Optional)

Projects MAY include an `AI_METRICS.md` file to track:

- Number of AI-assisted sessions
- Files modified per session
- Number of uncertainty escalations
- Frequency of Safe Mode activations
- Number of verification failures or detected errors

This data can be used to:

- Improve agent prompts and behavior
- Identify problem areas in the project
- Demonstrate reliability to stakeholders
- Support compliance and audit requirements

Format is project-specific and MAY be defined in `AI_PROJECT_CONFIG.md` (Section 16).

---

## 16. Project Configuration (Optional)

Projects MAY define additional settings in `AI_PROJECT_CONFIG.md`, such as:

- Whether Compliance Mode is enabled
- Lists of files or directories considered HIGH RISK
- Required tools or validators (linters, type-checkers, security scanners)
- Custom directories for scripts/tools
- Organization-specific coding or documentation standards
- Project-specific security classifications and rules

AI agents SHOULD consult `AI_PROJECT_CONFIG.md` if it exists and follow any project-specific overrides or additions.

**Important**: Project configuration MUST NOT weaken or relax security-critical rules defined in Section 6.5, but MAY add stricter requirements or additional security constraints.

---

## 17. Document History

- **v1.2** – Added explicit security considerations (Section 6.5) and Security/Compliance section in `AI_CONTEXT_INDEX.md` template; added Table of Contents.  
- **v1.1** – Added risk classification, error recovery, tool usage protocol, stronger testing rules, version control guidance, conflict prevention, compliance mode, metrics, and task-specific state file template.  
- **v1.0** – Initial draft of AI rules, boot protocol, and self-bootstrapping memory structure.

---

## 18. Appendix A: Example Session (Informative, Not Normative)

This example illustrates how a typical AI-assisted session might flow.

```md
## [2025-12-04] Session 3

- Agent / Engineer: AI agent
- Goal:
  - Refactor user profile update logic and add basic tests.

- Files touched:
  - `src/user/profile.py`
  - `tests/test_profile.py`
  - `SESSION_NOTES.md`
  - `TODO.md`
  - `AI_CONTEXT_INDEX.md`

- Risk classification:
  - MEDIUM (business logic, not payments or auth)

- Summary:
  - Read `AI_RULES_AND_BEST_PRACTICES.md`, `AI_CONTEXT_INDEX.md`, and previous `SESSION_NOTES.md`.
  - Identified `src/user/profile.py` as main file; confirmed no direct payment/auth logic.
  - Planned and executed a small refactor to `update_profile()` for clarity and testability.
  - Added unit tests in `tests/test_profile.py` for success and failure scenarios.
  - Ran tests (simulated command: `pytest tests/test_profile.py`) and all passed.

- Uncertainties / Questions:
  - Unsure if downstream services depend on the old error message format.
  - Marked as MEDIUM RISK; recommended engineer review of error handling.

- Follow-up tasks:
  - [ ] Engineer to review error message changes in `update_profile()`.
  - [ ] Confirm with product owner that validation rules still match requirements.
```

Agents MAY use this example as a reference pattern but MUST follow the normative rules in earlier sections when there is any conflict.
