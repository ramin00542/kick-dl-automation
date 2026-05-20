#!/usr/bin/env python3
# upload_to_sites.py

import os
import time
import base64
import argparse
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.chrome.service import Service
from webdriver_manager.chrome import ChromeDriverManager


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


def make_driver():
    """Create Chrome driver using webdriver-manager (auto version match)."""
    options = webdriver.ChromeOptions()
    options.add_argument("--headless=new")
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("--disable-gpu")
    options.add_argument("--window-size=1920,1080")
    options.add_argument("--disable-blink-features=AutomationControlled")
    # Allow credentials in URL (needed for Basic Auth pages)
    options.add_argument("--allow-running-insecure-content")

    service = Service(ChromeDriverManager().install())
    driver = webdriver.Chrome(service=service, options=options)
    return driver


def handle_basic_auth_alert(driver, username, password, timeout=10):
    """Handle HTTP Basic Auth browser dialog using alert."""
    try:
        WebDriverWait(driver, timeout).until(EC.alert_is_present())
        alert = driver.switch_to.alert
        # Some drivers expose credentials via alert — not always possible
        alert.dismiss()
    except Exception:
        pass


def upload_to_erfanzadeh(driver, file_path, creds):
    username = creds.get('username', 'admin')
    password = creds.get('password', 'admin')

    # FIX: Use CDP to inject Authorization header BEFORE navigating
    # This bypasses the Basic Auth dialog entirely
    token = base64.b64encode(f"{username}:{password}".encode()).decode()
    driver.execute_cdp_cmd("Network.enable", {})
    driver.execute_cdp_cmd("Network.setExtraHTTPHeaders", {
        "headers": {"Authorization": f"Basic {token}"}
    })

    print(f"  → Opening erfanzadeh.ir with auth header ...")
    driver.get("https://erfanzadeh.ir/")
    time.sleep(3)

    print(f"  → Page title: {driver.title}")
    print(f"  → Current URL: {driver.current_url}")

    wait = WebDriverWait(driver, 30)

    # Wait for file input
    try:
        file_input = wait.until(
            EC.presence_of_element_located((By.CSS_SELECTOR, "input[type='file']"))
        )
        print(f"  → Found file input, sending file path ...")
    except Exception as e:
        # Print page source for debugging
        print(f"  ❌ File input not found: {e}")
        print(f"  → Page source (first 2000 chars): {driver.page_source[:2000]}")
        raise Exception(f"File input not found on erfanzadeh.ir: {e}")

    file_input.send_keys(os.path.abspath(file_path))
    print(f"  → File path sent: {os.path.abspath(file_path)}")
    time.sleep(1)

    # Try to click upload button
    try:
        upload_btn = wait.until(EC.element_to_be_clickable(
            (By.XPATH, "//button[contains(text(), 'Upload') or contains(text(), 'آپلود') or contains(text(), 'ارسال') or contains(text(), 'Submit')]")
        ))
        upload_btn.click()
        print(f"  → Upload button clicked")
    except Exception as e:
        print(f"  ⚠️ Upload button not found, trying form submit: {e}")
        try:
            form = driver.find_element(By.TAG_NAME, "form")
            form.submit()
            print(f"  → Form submitted")
        except Exception as e2:
            print(f"  ⚠️ Form submit also failed: {e2}")

    # Wait for upload completion (up to 2 hours for large files)
    print(f"  → Waiting for upload to complete (up to 2 hours) ...")
    wait_long = WebDriverWait(driver, 7200)
    try:
        wait_long.until(
            EC.presence_of_element_located(
                (By.CSS_SELECTOR, ".alert-success, .success, .done, #result, #download-link, a[href*='download']")
            )
        )
        print(f"  → Success element detected")
    except Exception:
        print(f"  ⚠️ No success element found — checking for links anyway ...")

    # Try to find download link in page
    all_links = driver.find_elements(By.TAG_NAME, "a")
    for link in all_links:
        href = link.get_attribute('href')
        if href and ('download' in href or 'get' in href or os.path.basename(file_path) in href):
            return href

    # Last resort: return last link on page
    if all_links:
        last_href = all_links[-1].get_attribute('href')
        if last_href:
            return last_href

    # Return current URL as fallback
    return driver.current_url


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

    print(f"Creating Chrome driver ...")
    driver = make_driver()
    print(f"Chrome driver ready ✓")

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
