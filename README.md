# 🤖 Kick.com Telegram Downloader Bot

A Telegram bot that allows users to search for Kick.com channels, browse their videos, and download them directly to their Telegram chat.

## ✨ Features

- 🔍 Search for any Kick.com channel by username
- 📋 Browse the latest videos of a channel (up to 10 videos)
- 📊 View detailed video information (title, date, duration, views)
- ⬇️ Download videos with progress indication
- 📦 Automatic file splitting for large videos
- 🧹 Automatic cleanup of temporary files

## 🛠️ Setup for GitHub Actions

1. **Create a Telegram Bot**:
   - Open Telegram and search for `@BotFather`
   - Send `/newbot` and follow the instructions
   - Copy the token you receive

2. **Add Bot Token to GitHub Secrets**:
   - Go to your repository → Settings → Secrets and variables → Actions
   - Click "New repository secret"
   - Name: `BOT_TOKEN`
   - Value: (Paste your bot token)

3. **Push the code to GitHub**:
   - The bot will automatically start running via GitHub Actions
   - You can also trigger it manually from the Actions tab

## ⚠️ Important Notes

- GitHub Actions runners have a maximum runtime of 6 hours
- Download and file processing must complete within this time limit
- The bot uses the free GitHub runner, so performance may vary

## 📝 Usage

1. Start the bot with `/start`
2. Send a Kick.com channel username (e.g., `xqc`)
3. Select a video from the list
4. View video details and confirm download
5. Wait for the bot to send the video file

## 🔧 Local Development

1. Clone the repository
2. Create a virtual environment: `python -m venv venv`
3. Activate it: `source venv/bin/activate` (Linux/Mac) or `venv\Scripts\activate` (Windows)
4. Install dependencies: `pip install -r requirements.txt`
5. Create a `.env` file with `BOT_TOKEN=your_token_here`
6. Run: `python bot.py`

## 📦 Dependencies

- `python-telegram-bot==20.7` - Telegram Bot API wrapper
- `KickISO==0.1.2` - Kick.com API client
- `kick-dl==1.0.0` - Video downloader for Kick
- `filesplit==3.0.2` - File splitting utility
- `python-dotenv==1.0.0` - Environment variable management

## 📄 License

MIT License - see LICENSE file for details
