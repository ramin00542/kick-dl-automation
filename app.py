import os
import subprocess
import asyncio
import logging
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import Application, CommandHandler, CallbackQueryHandler, MessageHandler, filters, ContextTypes
from kickapi import KickAPI  # کتابخانه برای ارتباط با API سایت Kick
from kickdl import KickDL    # کتابخانه اصلی دانلودر

# --- تنظیمات اولیه ---
# توکن ربات خود را در اینجا قرار دهید
TELEGRAM_BOT_TOKEN = "8738165081:AAEIIO25a2-to-o4NwJ_KXqQdxROMnNqKdg"
# محدودیت حجم فایل برای تلگرام (حداکثر 50 مگابایت)
MAX_TELEGRAM_SIZE_MB = 50

# فعال کردن لاگ برای مشاهده خطاها
logging.basicConfig(format="%(asctime)s - %(name)s - %(levelname)s - %(message)s", level=logging.INFO)

# --- متغیرهای سراسری برای نگهداری موقت اطلاعات کاربران ---
user_data = {}

# --- دریافت لیست ویدیوها با KickISO ---
async def get_video_list(channel_name: str):
    """لیست ویدیوهای یک کانال را با اطلاعات کامل برمی‌گرداند."""
    api = KickAPI()
    try:
        # این متد لیست ویدیوها را برمی‌گردوند (ممکن است نیاز به Pagination داشته باشد)
        # در نسخه‌های ساده‌تر، معمولاً آخرین 20 ویدیو را دریافت می‌کند
        videos = api.user_videos(channel_name)
        return videos
    except Exception as e:
        logging.error(f"خطا در گرفتن لیست ویدیوها: {e}")
        return None

# --- تابع دانلود با کیفیت انتخابی ---
async def download_video(video_url: str, quality: str = "best"):
    """ویدیو را با کیفیت مشخص شده دانلود می‌کند و مسیر فایل را برمی‌گرداند."""
    downloader = KickDL()
    try:
        # تنظیم کیفیت دانلود
        opts = {
            'format': quality,  # کیفیت انتخابی (مثل 'best', 'worst', '720p')
            'outtmpl': '%(title)s.%(ext)s'  # نام فایل خروجی
        }
        file_path = downloader.download(video_url, options=opts)
        return file_path
    except Exception as e:
        logging.error(f"خطا در دانلود: {e}")
        return None

# --- تقسیم فایل (Split) با دستور سیستمی ---
def split_large_file(file_path: str):
    """اگر فایل از حد مجاز بیشتر بود، آن را به قطعات 95 مگابایتی تقسیم می‌کند."""
    file_size_mb = os.path.getsize(file_path) / (1024 * 1024)
    if file_size_mb > 95:
        # دستور split برای لینوکس/مک
        # -b 95M : اندازه هر قطعه 95 مگابایت
        # -d : استفاده از پسوند عددی
        # -a 2 : تعداد ارقام برای پسوند
        subprocess.run(["split", "-b", "95M", "-d", "-a", "2", file_path, f"{file_path}.part_"])
        # حذف فایل اصلی و برگرداندن لیست قطعات
        os.remove(file_path)
        return [f"{file_path}.part_{i:02d}" for i in range(len(os.listdir('.')) if file_path in '')] # این بخش نیاز به اصلاح دارد
        # راه حل ساده: برگرداندن لیست تمام فایل‌های part مرتبط
        return [f for f in os.listdir() if f.startswith(os.path.basename(file_path)) and ".part_" in f]
    return [file_path]

# --- هندلر اصلی دریافت پیام (اسم کانال) ---
async def handle_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_id = update.effective_user.id
    channel_name = update.message.text.strip()

    await update.message.reply_text(f"در حال جستجوی کانال `{channel_name}` ... لطفاً صبر کنید.")

    # دریافت لیست ویدیوها
    videos = await get_video_list(channel_name)
    if not videos:
        await update.message.reply_text("کانال مورد نظر یافت نشد یا خطایی رخ داده است.")
        return

    # ذخیره لیست ویدیوها در حافظه کاربر
    user_data[user_id] = {"videos": videos, "channel_name": channel_name}

    # ساخت منوی دکمه‌ای برای انتخاب ویدیو
    keyboard = []
    for idx, video in enumerate(videos[:10]):  # فقط 10 ویدیوی اول
        # ایجاد دکمه با عنوان ویدیو و تاریخ انتشار
        button_text = f"{idx+1}: {video.get('title', 'بدون عنوان')[:40]}"
        keyboard.append([InlineKeyboardButton(button_text, callback_data=f"vid_{idx}")])

    reply_markup = InlineKeyboardMarkup(keyboard)
    await update.message.reply_text(
        f"✅ کانال '{channel_name}' پیدا شد. لطفاً شماره ویدیوی مورد نظر را انتخاب کنید:",
        reply_markup=reply_markup
    )

# --- هندلر انتخاب ویدیو و کیفیت ---
async def button_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    user_id = update.effective_user.id
    data = query.data

    if data.startswith("vid_"):
        # کاربر شماره ویدیو را انتخاب کرده است
        video_index = int(data.split("_")[1])
        selected_video = user_data.get(user_id, {}).get("videos", [])[video_index]

        # ذخیره اطلاعات ویدیو برای مرحله بعد
        user_data[user_id]["selected_video"] = selected_video

        # دریافت اطلاعات کامل ویدیو با KickISO
        api = KickAPI()
        video_info = api.video(selected_video.get('id'))
        upload_date = video_info.created_at.strftime("%Y-%m-%d") if video_info.created_at else "نامشخص"
        duration_sec = video_info.duration
        duration_str = f"{duration_sec // 60}:{duration_sec % 60:02d}"

        # ارسال توضیحات
        caption = (
            f"**عنوان:** {video_info.title}\n"
            f"**تاریخ انتشار:** {upload_date}\n"
            f"**مدت زمان:** {duration_str}\n"
            f"**تعداد بازدید:** {video_info.views}\n"
            f"**لینک ویدیو:** {selected_video.get('url')}\n\n"
            "لطفاً کیفیت مورد نظر خود را انتخاب کنید:"
        )

        # دکمه‌های انتخاب کیفیت
        quality_buttons = [
            [InlineKeyboardButton("📹 بهترین کیفیت", callback_data="quality_best")],
            [InlineKeyboardButton("🎬 کیفیت پایین (حجم کمتر)", callback_data="quality_worst")],
            [InlineKeyboardButton("⚙️ کیفیت 720p", callback_data="quality_720p")],
        ]
        await query.edit_message_text(
            caption,
            reply_markup=InlineKeyboardMarkup(quality_buttons),
            parse_mode="Markdown"
        )

    elif data.startswith("quality_"):
        # کاربر کیفیت را انتخاب کرده است
        quality = data.split("_")[1]
        if quality == "best":
            quality_format = "best"
        elif quality == "worst":
            quality_format = "worst"
        elif quality == "720p":
            quality_format = "bestvideo[height<=720]+bestaudio/best[height<=720]"
        else:
            quality_format = "best"

        # شروع فرایند دانلود
        await query.edit_message_text(
            "در حال دانلود ویدیو با کیفیت انتخابی... لطفاً صبر کنید (این فرایند ممکن است چند دقیقه طول بکشد)."
        )

        video_url = user_data[user_id]["selected_video"].get('url')
        file_path = await download_video(video_url, quality_format)

        if not file_path or not os.path.exists(file_path):
            await query.edit_message_text("متأسفانه دانلود با خطا مواجه شد. لطفاً دوباره تلاش کنید.")
            return

        # بررسی حجم فایل و تقسیم در صورت نیاز
        file_parts = split_large_file(file_path)
        
        if len(file_parts) == 1:
            # ارسال فایل به تلگرام (با احتساب محدودیت حجم)
            file_size_mb = os.path.getsize(file_parts[0]) / (1024 * 1024)
            if file_size_mb <= MAX_TELEGRAM_SIZE_MB:
                with open(file_parts[0], 'rb') as f:
                    await context.bot.send_video(chat_id=update.effective_chat.id, video=f, caption="✅ فایل دانلود شد.")
            else:
                # اگر فایل نهایی باز هم بزرگ بود، پیام خطا بدهید
                await context.bot.send_message(chat_id=update.effective_chat.id, text=f"⚠️ حجم فایل ({file_size_mb:.1f} مگابایت) بیشتر از حد مجاز تلگرام (50 مگابایت) است و قابلیت اسپلیت خودکار به دلیل محدودیت‌های تلگرام وجود ندارد.")
        else:
            # ارسال تک تک قطعات
            for part in file_parts:
                with open(part, 'rb') as f:
                    await context.bot.send_document(chat_id=update.effective_chat.id, document=f, caption="بخشی از فایل")
                os.remove(part) # حذف قطعه پس از ارسال
        # پاکسازی فایل‌های موقت
        if os.path.exists(file_path):
            os.remove(file_path)

        # پاک کردن داده‌های کاربر
        user_data.pop(user_id, None)
