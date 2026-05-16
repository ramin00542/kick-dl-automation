#!/usr/bin/env python3
# upload_to_sites.py

import os
import sys
import time
import argparse
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC

def parse_credentials(creds_str, target_sites_list):
    """
    تبدیل رشته credentials به دیکشنری {site: {'username': u, 'password': p} یا {'guest': True}}
    """
    creds_dict = {}
    if not creds_str:
        return creds_dict
    for line in creds_str.strip().split('\n'):
        line = line.strip()
        if not line:
            continue
        parts = line.split(':')
        if len(parts) == 2 and parts[1].lower() == 'guest':
            creds_dict[parts[0]] = {'guest': True}
        elif len(parts) == 3:
            site, user, pwd = parts
            creds_dict[site] = {'username': user, 'password': pwd}
        else:
            print(f"⚠️ Invalid credentials line: {line}")
    # برای سایت‌هایی که creds ندارند، حالت مهمان پیش‌فرض
    for site in target_sites_list:
        if site not in creds_dict:
            creds_dict[site] = {'guest': True}
    return creds_dict

# ------------------------------------------------------------
# توابع آپلود اختصاصی هر سایت
# ------------------------------------------------------------

def upload_to_nixfile(driver, file_path, creds):
    """آپلود به nixfile.com (با پشتیبانی از لاگین و مهمان)"""
    driver.get("https://nixfile.com/")
    if not creds.get('guest', False):
        # کلیک روی دکمه ورود
        try:
            login_btn = driver.find_element(By.LINK_TEXT, "ورود")
            login_btn.click()
        except:
            login_btn = driver.find_element(By.LINK_TEXT, "Login")
            login_btn.click()
        WebDriverWait(driver, 10).until(EC.presence_of_element_located((By.NAME, "username")))
        driver.find_element(By.NAME, "username").send_keys(creds['username'])
        driver.find_element(By.NAME, "password").send_keys(creds['password'])
        driver.find_element(By.CSS_SELECTOR, "button[type='submit']").click()
        time.sleep(3)
    # پیدا کردن input فایل
    upload_input = driver.find_element(By.CSS_SELECTOR, "input[type='file']")
    upload_input.send_keys(os.path.abspath(file_path))
    # ممکن است آپلود خودکار شروع شود، وگرنه کلیک روی دکمه آپلود
    time.sleep(2)
    try:
        upload_btn = driver.find_element(By.XPATH, "//button[contains(text(), 'Upload')]")
        upload_btn.click()
    except:
        pass
    # منتظر لینک دانلود
    wait = WebDriverWait(driver, 120)
    link_elem = wait.until(EC.presence_of_element_located((By.CSS_SELECTOR, "a.download-link")))
    return link_elem.get_attribute("href")

def upload_to_starupload(driver, file_path, creds):
    # مثال: starupload.lol (اگر فعال شود)
    raise NotImplementedError("starupload.lol is currently not implemented")

def upload_to_uplod_ir(driver, file_path, creds):
    # uplod.ir (فعلاً down است)
    raise NotImplementedError("uplod.ir is not available")

def upload_to_generic(driver, file_path, creds, site_name):
    return f"Unsupported site: {site_name}"

# نگاشت نام سایت به تابع
UPLOAD_FUNCS = {
    "nixfile.com": upload_to_nixfile,
    "starupload.lol": upload_to_starupload,
    "uplod.ir": upload_to_uplod_ir,
    # سایر سایت‌ها را به همین ترتیب اضافه کنید
}

def main():
    parser = argparse.ArgumentParser(description="Upload file to selected hosting sites using Selenium")
    parser.add_argument("--file", required=True, help="Path to the file to upload")
    parser.add_argument("--sites", required=True, help="Comma-separated list of target sites (e.g., nixfile.com,starupload.lol)")
    parser.add_argument("--creds", default="", help="Credentials string: site:username:password or site:guest per line")
    args = parser.parse_args()

    sites = [s.strip() for s in args.sites.split(",")]
    creds_dict = parse_credentials(args.creds, sites)

    # راه‌اندازی مرورگر بی‌سر (headless)
    options = webdriver.ChromeOptions()
    options.add_argument("--headless")
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    driver = webdriver.Chrome(options=options)

    results = {}
    for site in sites:
        print(f"\n📤 Uploading to {site} ...")
        func = UPLOAD_FUNCS.get(site, upload_to_generic)
        try:
            if func == upload_to_generic:
                link = func(driver, args.file, creds_dict.get(site, {'guest': True}), site)
            else:
                link = func(driver, args.file, creds_dict.get(site, {'guest': True}))
            results[site] = link
            print(f"✅ {site} -> {link}")
        except Exception as e:
            results[site] = f"Error: {str(e)}"
            print(f"❌ {site} failed: {e}")

    driver.quit()

    # ذخیره نتایج در فایل
    with open("upload_results.txt", "w", encoding="utf-8") as f:
        for site, link in results.items():
            f.write(f"{site}: {link}\n")

    print("\n📝 Results saved to upload_results.txt")

if __name__ == "__main__":
    main()
