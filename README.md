# File Download & Upload Automation

GitHub Actions-based system for downloading files from MEGA, Pixeldrain, or direct links, processing them (zip/split), and uploading to multiple file hosting services or creating GitHub Releases.

## Features

- **Multiple download sources**: MEGA, Pixeldrain, direct HTTP links
- **Flexible processing**: Zip, split (>90MB), keep original, or individual processing
- **12 upload destinations**: API-based and browser-automated sites
- **GitHub Releases**: Upload files up to 2GB as release assets (solves 90MB split problem)
- **Artifact storage**: Processed files uploaded as GitHub Artifacts for temporary retrieval
- **Secure**: Inputs passed via environment variables, no secret leakage in logs

## Workflows

| Workflow | Trigger | Description |
|----------|---------|-------------|
| `download_and_upload.yml` | workflow_dispatch / push to main/master | Download from direct link, process, upload to file hosts |
| `download-from-mega.yml` | workflow_dispatch / push to main/master | Download from MEGA or Pixeldrain, save to repo or upload |
| `download-apk.yml` | workflow_dispatch | Download APK from Google Play Store |

### Commit Message Commands (push trigger)

```
github: https://example.com/file.zip           # Download with normal handling
github-zip: https://example.com/files/         # Download and zip all files
mega: https://mega.nz/file/abc                  # Download from MEGA (individual split)
mega-zip: https://mega.nz/file/abc             # Download from MEGA (zip + split)
mega-full: https://mega.nz/file/abc            # Download from MEGA (no split)
pixeldrain: https://pixeldrain.com/u/abc       # Download from Pixeldrain
```

## File Handling Modes

| Mode | Behavior | Output |
|------|----------|--------|
| `normal` | Keep original filenames, split only if >90MB | `downloads/<filename>/<filename>` + merge scripts if split |
| `single_zip_split` | Zip all files into one archive, split if >90MB | `downloads/archive.zip/` + merge scripts |
| `full_file_no_split` | Copy files as-is, no splitting | `downloads/<filename>/<filename>` |
| `individual_split` | Each file in its own folder, split if >90MB | `downloads/<filename>/<filename>` + merge scripts |
| `zip` | Zip all files, split if >90MB | `downloads/archive.zip/` + merge scripts |

## Upload Sites

### API-based (no browser required)

| Site | Type | Auth | Max Size | Retention |
|------|------|------|----------|-----------|
| [gofile.io](https://gofile.io) | Permanent | None | Unlimited | Permanent |
| [pixeldrain.com](https://pixeldrain.com) | Temporary | None | Unlimited | ~90 days |
| [file.io](https://file.io) | Ephemeral | None | Unlimited | Until 1st download |
| [catbox.moe](https://catbox.moe) | Permanent | None | 200MB | Permanent |
| [litterbox.catbox.moe](https://litterbox.catbox.moe) | Temporary | None | 1GB | 72 hours |
| [0x0.st](https://0x0.st) | Anonymous | None | 512MB | ~2 weeks |
| [buzzheavier.com](https://buzzheavier.com) | Permanent | None | Unlimited | Generous |
| [filebin.net](https://filebin.net) | Temporary | None | Unlimited | Temporary |

### Selenium-based (browser automation)

| Site | Type | Auth | Notes |
|------|------|------|-------|
| [erfanzadeh.ir](https://erfanzadeh.ir) | Permanent | Required | Basic Auth credentials needed |
| [krakenfiles.com](https://krakenfiles.com) | Temporary | None | Popular file hosting |
| [1fichier.com](https://1fichier.com) | Permanent | Optional | Supports very large files |
| [mixdrop.co](https://mixdrop.co) | Temporary | None | Video hosting |

## Large File Strategy

GitHub has a 100MB file size limit. This project handles large files in three ways:

1. **Split + Merge Scripts**: Files >90MB are split into parts with `merge.bat`/`merge.sh` scripts for reconstruction
2. **GitHub Releases**: Files up to 2GB can be uploaded as release assets (recommended for files >90MB)
3. **External Upload Sites**: Upload to gofile.io, buzzheavier.com, etc. for unlimited size

### Recommended approach for large files:

```yaml
# In workflow_dispatch, leave target_sites empty to create a GitHub Release:
target_sites: ""  # Creates Release with all files + parts + merge scripts
```

Or upload to external hosts:

```yaml
target_sites: "gofile.io,buzzheavier.com"  # Uploads full file (no split)
upload_mode: "full"
```

## Setup

### Required Secrets

| Secret | Description |
|--------|-------------|
| `SITE_CREDENTIALS` | Upload site credentials (format: `site:username:password` per line) |
| `MEGA_LINK_PASSWORD` | MEGA link password (if protected) |
| `MEGA_FILE_PASSWORD` | MEGA file password (reserved for future use) |

### Example SITE_CREDENTIALS

```
erfanzadeh.ir:myuser:mypassword
gofile.io:guest
```

## Project Structure

```
.github/workflows/
├── _reusable-process.yml    # Core download/process/upload logic
├── download_and_upload.yml  # Direct link workflow
├── download-from-mega.yml   # MEGA/Pixeldrain workflow
└── download-apk.yml         # Google Play APK downloader

upload_to_sites.py           # Upload functions for all 12 sites
requirements.txt             # Python dependencies
.gitignore                   # Git ignore patterns
```

## Local Development

```bash
# Install dependencies
pip install -r requirements.txt

# Test upload to a single site
python upload_to_sites.py --file test.zip --sites "gofile.io"

# Test upload to multiple sites
python upload_to_sites.py --file test.zip --sites "gofile.io,pixeldrain.com"
```

## Security

- **No secrets in logs**: Uses `set -euo pipefail` (not `set -x`) to prevent variable expansion in logs
- **Input validation**: All workflow inputs passed via environment variables to prevent shell injection
- **Credential protection**: Passwords stored in GitHub Secrets, never hardcoded
- **Log sanitization**: Sensitive files removed before commit

## License

MIT
