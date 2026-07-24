# 📦 File Download & Upload Automation

GitHub Actions-based system for downloading files from various sources, processing them (zip/split), and uploading to multiple file hosting services.

## ✨ Features

- 📥 **Download** from direct URLs, MEGA, and Pixeldrain
- 🔄 **Process** files: zip archives, split into 90MB chunks, generate merge scripts
- 📤 **Upload** to 12 file hosting services
- 📱 **Download APKs** from Google Play Store
- 🔐 **Credential management** via GitHub Secrets
- 📊 **Logging** and result reporting

## 🚀 Workflows

### 1. Download & Upload (`download_and_upload.yml`)

Download files from direct URLs and upload to file hosts.

**Trigger:** Manual dispatch or push with `github:` in commit message

**Parameters:**
- `url` - File URL(s) (space-separated)
- `mode` - `normal` or `zip`
- `link_password` - HTTP Basic Auth password (optional)
- `file_password` - Archive password (optional)
- `target_sites` - Comma-separated upload destinations
- `upload_mode` - `full` (single file) or `parts` (split files)

### 2. Download from MEGA/Pixeldrain (`download-from-mega.yml`)

Download from MEGA or Pixeldrain and save to repository.

**Trigger:** Manual dispatch or push with `mega:`, `mega-zip:`, `mega-full:`, or `pixeldrain:` in commit message

### 3. Download APK (`download-apk.yml`)

Download any Android app from Google Play Store.

**Trigger:** Manual dispatch

**Parameters:**
- `package_name` - App package name or Google Play URL

## 📤 Supported Upload Sites

| Site | Type | Auth Required | Notes |
|------|------|---------------|-------|
| erfanzadeh.ir | Selenium | Yes (Basic Auth) | Private hosting |
| gofile.io | API | No | Permanent storage |
| pixeldrain.com | API | No | ~90 day retention |
| file.io | API | No | Deleted after 1st download |
| catbox.moe | API | No | Permanent, 200MB max |
| litterbox.catbox.moe | API | No | Temporary (72h) |
| 0x0.st | API | No | ~2 week retention |
| buzzheavier.com | API | No | No file type limits |
| filebin.net | API | No | Temporary bins |
| krakenfiles.com | Selenium | No | Popular hosting |
| 1fichier.com | Selenium | Optional | Large file support |
| mixdrop.co | Selenium | No | Video hosting |

## 🔧 Setup

### GitHub Secrets

| Secret | Description | Required |
|--------|-------------|----------|
| `SITE_CREDENTIALS` | Upload site credentials (one per line: `site:username:password`) | For private sites |
| `MEGA_LINK_PASSWORD` | MEGA link password | For password-protected MEGA links |
| `MEGA_FILE_PASSWORD` | MEGA file password | For encrypted MEGA archives |

### Workflow Inputs

| Input | Description | Default |
|-------|-------------|---------|
| `target_sites` | Comma-separated upload destinations | `erfanzadeh.ir` |
| `upload_mode` | `full` or `parts` | `full` |

## 📁 Project Structure

```
├── .github/workflows/
│   ├── download_and_upload.yml    # Main download & upload workflow
│   ├── download-from-mega.yml     # MEGA/Pixeldrain download workflow
│   ├── download-apk.yml           # Google Play APK downloader
│   └── _reusable-process.yml      # Shared download/process/upload logic
├── upload_to_sites.py             # Upload automation script (12 sites)
└── requirements.txt               # Python dependencies
```

## 🛠️ Local Development

```bash
# Install dependencies
pip install -r requirements.txt

# Run upload script
python upload_to_sites.py \
  --file path/to/file.zip \
  --sites "gofile.io,pixeldrain.com" \
  --creds "gofile.io:user:pass"
```

## 📋 File Processing Modes

| Mode | Description |
|------|-------------|
| `normal` / `single_zip_split` | Zip all files, split if >90MB |
| `zip` | Zip all files, split if >90MB |
| `full_file_no_split` | Keep files as-is, no splitting |
| `individual_split` | Split each file individually if >90MB |

### Split Files

When files exceed 90MB, they're split into chunks with merge scripts:
- `merge.bat` - Windows batch file
- `merge.sh` - Linux/macOS shell script
- `merge.command` - macOS double-click script

## ⚠️ Important Notes

- GitHub Actions runners have a 6-hour maximum runtime
- Large file uploads may take significant time
- Some sites have file size limits (check table above)
- Credentials should always be stored in GitHub Secrets, never hardcoded

## 📄 License

MIT License
