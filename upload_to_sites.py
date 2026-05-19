#!/usr/bin/env python3
# upload_to_sites.py

import os
import time
import argparse
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC


def parse_credentials(creds_str, target_sites_list):
    creds_dict = {}
    if not creds_str:
        for site in target_sites_list:
            creds_dict[site] = {'guest': True}
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
    for site in target_sites_list:
        if site not in creds_dict:
            creds_dict[site] = {'guest': True}
    return creds_dict


def upload_to_erfanzadeh(driver, file_path, creds):
    # FIX: guest mode should NOT use admin:admin
    if creds.get('guest', False):
        # No auth - open site normally
        driver.get("https://erfanzadeh.ir/")
    else:
        username = creds.get('username', '')
        password = creds.get('password', '')
        driver.get(f"https://{username}:{password}@erfanzadeh.ir/")

    wait = WebDriverWait(driver, 30)

    # Wait for file input to appear
    file_input = wait.until(
        EC.presence_of_element_located((By.CSS_SELECTOR, "input[type='file']"))
    )
    file_input.send_keys(os.path.abspath(file_path))

    # Try to click upload button
    try:
        upload_btn = driver.find_element(
            By.XPATH,
            "//button[contains(text(), 'Upload') or contains(text(), 'آپلود') or contains(text(), 'ارسال')]"
        )
        upload_btn.click()
    except Exception:
        pass

    # Wait up to 2 hours for large file uploads
    wait_long = WebDriverWait(driver, 7200)
    try:
        wait_long.until(
            EC.presence_of_element_located(
                (By.CSS_SELECTOR, ".alert-success, .success, .done, #result")
            )
        )
    except Exception:
        pass

    # Try to find download link in page
    all_links = driver.find_elements(By.TAG_NAME, "a")
    for link in all_links:
        href = link.get_attribute('href')
        if href and ('download' in href or 'get' in href or os.path.basename(file_path) in href):
            return href

    if all_links:
        return all_links[-1].get_attribute('href')

    raise Exception("No download link found after upload")


def upload_to_generic(driver, file_path, creds, site_name):
    return f"Unsupported site: {site_name}"


UPLOAD_FUNCS = {
    "erfanzadeh.ir": upload_to_erfanzadeh,
}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--file", required=True)
    parser.add_argument("--sites", required=True)
    parser.add_argument("--creds", default="")
    args = parser.parse_args()

    sites = [s.strip() for s in args.sites.split(",")]
    creds_dict = parse_credentials(args.creds, sites)

    options = webdriver.ChromeOptions()
    options.add_argument("--headless")
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("--disable-gpu")
    options.add_argument("--window-size=1920,1080")
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

    with open("upload_results.txt", "w", encoding="utf-8") as f:
        for site, link in results.items():
            f.write(f"{site}: {link}\n")

    print("\n📝 Results saved to upload_results.txt")


if __name__ == "__main__":
    main()
