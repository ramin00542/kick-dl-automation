# 🚀 mirror-to-github — Mirror Any File to GitHub

> **Download files from MEGA, Pixeldrain, or direct links — then split, zip, upload to file hosts, or mirror them straight to GitHub Releases — all automatically via GitHub Actions.**

---

## 📋 Overview

**mirror-to-github** is a professional GitHub Actions automation suite that:

1. **Downloads** files from MEGA, Pixeldrain, or direct HTTP links
2. **Processes** them: zip, split into chunks (auto-detect optimal size), or preserve as-is
3. **Publishes** them: upload to file hosting sites **or** create a GitHub Release
4. **Commits** small files back to the repository

---

## 🏗️ Architecture

```
.github/
├── scripts/                  ← Clean, modular bash scripts
│   ├── common.sh             ← Shared utilities (logging, split detection, merge scripts)
│   ├── lib/
│   │   └── handling.sh       ← Handling-mode logic (normalize + full/split/zip strategies)
│   ├── download.sh           ← Download from direct/mega/pixeldrain
│   ├── process.sh            ← Thin orchestrator (dispatches to lib/handling.sh)
│   ├── upload.sh             ← Upload to file hosting sites
│   ├── release.sh            ← Create GitHub Release
│   └── commit.sh             ← Commit small files to repo
│
└── workflows/
    ├── download-and-upload.yml      ← Download + upload to file hosts
    ├── download-from-mega.yml       ← Download from MEGA/Pixeldrain
    ├── download-apk.yml             ← Download Android APKs from Google Play
    └── _reusable-process.yml        ← Thin orchestrator (calls scripts above)
```

**Key design decisions:**
- ✅ **Separation of concerns** — each script has one job
- ✅ **Reusable** — all workflows share `_reusable-process.yml`
- ✅ **Testable** — scripts can run independently
- ✅ **Secure** — all inputs pass through `env:` blocks (no shell injection)
- ✅ **Resilient** — `set -euo pipefail` everywhere, retry logic, safe file handling

---

## 🚦 How to Use

### Option 1: Run from GitHub UI (recommended)

Go to your repository's **Actions** tab → select a workflow → click **Run workflow** → fill in the form.

### Option 2: Push with commit message

| Prefix | Source | Handling |
|--------|--------|----------|
| `github: <url>` | direct | split |
| `github-zip: <url>` | direct | zip_split |
| `mega: <url>` | mega | split |
| `mega-zip: <url>` | mega | zip_split |
| `mega-full: <url>` | mega | full_file |
| `pixeldrain: <url>` | pixeldrain | zip_split |

---

## ⚙️ Handling Modes

There are **3 real strategies** plus a smart `auto` mode. Older mode names are kept as aliases so existing workflows and commit triggers keep working.

| Mode | Description | Split? | `.full` file? | Legacy aliases |
|------|-------------|:------:|:-------------:|----------------|
| `auto` **(default)** | Smart: single file ≤2GB → `full_file`, otherwise `split` | maybe | maybe | — |
| `full_file` | Keep the file whole, **never split** (best for GitHub Releases, up to 2GB) | ❌ | ❌ | `full_file_no_split` |
| `split` | Keep raw file, split into chunks if larger than the limit | ✅ | ✅ | `normal`, `individual_split` |
| `zip_split` | ZIP everything into one archive, split if larger than the limit | ✅ | ✅ | `zip`, `single_zip_split` |

> **Where does my file end up?** Files larger than 100MB are **never** committed into the repo (GitHub blocks that). They are published as **GitHub Release assets** (up to 2GB each) when no `target_sites` are given, or uploaded to file hosts when `target_sites` is set. Look in the repo's **Releases** tab, not the code tree.

> **`split_size` / `split_mode` only apply to `split` and `zip_split`.** In `full_file` (or when `auto` resolves to `full_file`) they are ignored — the file is copied whole.

### 🧠 Auto Split Size Detection

When `split_mode` is set to `auto` (default), mirror-to-github examines the first downloaded file's extension and picks the optimal chunk size:

| File Type | Examples | Chunk Size |
|-----------|----------|:----------:|
| 🎬 Video | mp4, mkv, avi, mov, webm | **200 MB** |
| 📦 Archive | zip, rar, 7z, tar, gz | **150 MB** |
| 🎵 Audio | mp3, flac, wav, ogg | **100 MB** |
| ⚡ Executable | exe, apk, dmg, deb | **100 MB** |
| 📄 Document | pdf, doc, xlsx, epub | **50 MB** |
| 🖼️ Image | jpg, png, gif, webp | **25 MB** |
| ❓ Other | anything else | **90 MB** |

To use a custom size, set `split_mode: custom` and specify `split_size`.

---

## 📤 Upload Sites

Supports **13 file hosting services**:

### API-based (fast, reliable)
- **gofile.io** — No account needed, permanent
- **pixeldrain.com** — No account needed
- **file.io** — Ephemeral (deleted after first download)
- **catbox.moe** — Permanent, max 200MB
- **litterbox.catbox.moe** — Temporary (72h), max 1GB
- **0x0.st** — Anonymous, max 512MB
- **buzzheavier.com** — No file type limits
- **filebin.net** — Temporary bins

### Selenium-based (browser automation)
- **erfanzadeh.ir** — Requires credentials
- **krakenfiles.com** — Requires credentials
- **1fichier.com** — Requires credentials
- **mixdrop.co** — Requires credentials

---

## 🔐 Secrets Setup

In your repository **Settings → Secrets and variables → Actions**:

| Secret | Required for | Description |
|--------|-------------|-------------|
| `SITE_CREDENTIALS` | Upload sites | `site:username:password` per line |
| `MEGA_LINK_PASSWORD` | Password-protected MEGA links | MEGA link decryption password |

---

## 📝 Requirements

- Python 3.7+ (for `upload_to_sites.py`)
- GitHub Actions runner (Ubuntu latest)
- Packages installed automatically: `curl`, `zip`, `unzip`, `wget`, `megatools`, `jq`

---

## 🤝 Contributing

1. **Add a script** → place it in `.github/scripts/`
2. **Add a workflow** → create in `.github/workflows/`
3. **Add an upload site** → add function in `upload_to_sites.py` + register in `UPLOAD_FUNCS`

---
