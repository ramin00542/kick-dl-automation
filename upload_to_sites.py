#!/usr/bin/env python3
# upload_to_sites.py
# Upload files to various file hosting services
# Supports: erfanzadeh.ir, gofile.io, pixeldrain.com, file.io, catbox.moe,
#           0x0.st, buzzheavier.com, filebin.net, krakenfiles.com, 1fichier.com,
#           litterbox.catbox.moe, mixdrop.co

import os
import time
import json
import base64
import hashlib
import argparse
import requests
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.chrome.service import Service
from webdriver_manager.chrome import ChromeDriverManager


def parse_credentials(creds_str, target_sites_list):
    """Parse credentials from a multi-line string.

    Each line format: site:username:password  OR  site:guest
    Credentials should come from GitHub Secrets, NOT hardcoded values.
    """
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
            print(f"⚠️ Invalid credentials line (format: site:username:password): {line}")
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


# =============================================================================
# SELENIUM-BASED UPLOAD FUNCTIONS
# =============================================================================

def upload_to_erfanzadeh(driver, file_path, creds):
    """Upload to erfanzadeh.ir (requires Basic Auth)."""
    username = creds.get('username', '')
    password = creds.get('password', '')
    if not username or not password:
        print(f"  ⚠️ WARNING: No credentials provided for erfanzadeh.ir — upload may fail!")
        print(f"  → Set SITE_CREDENTIALS in GitHub Secrets (format: site:username:password)")

    # Use CDP to inject Authorization header BEFORE navigating
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

    return driver.current_url


def upload_to_krakenfiles(driver, file_path, creds):
    """Upload to krakenfiles.com using Selenium."""
    print(f"  → Opening krakenfiles.com ...")
    driver.get("https://krakenfiles.com/")
    time.sleep(3)

    print(f"  → Page title: {driver.title}")
    wait = WebDriverWait(driver, 60)

    # Wait for file input
    try:
        file_input = wait.until(
            EC.presence_of_element_located((By.CSS_SELECTOR, "input[type='file']"))
        )
        print(f"  → Found file input, sending file path ...")
    except Exception as e:
        print(f"  ❌ File input not found: {e}")
        print(f"  → Page source (first 2000 chars): {driver.page_source[:2000]}")
        raise Exception(f"File input not found on krakenfiles.com: {e}")

    file_input.send_keys(os.path.abspath(file_path))
    print(f"  → File path sent: {os.path.abspath(file_path)}")
    time.sleep(1)

    # Wait for upload to start and complete
    print(f"  → Waiting for upload to complete (up to 2 hours) ...")
    wait_long = WebDriverWait(driver, 7200)
    try:
        # Wait for upload progress to appear
        wait_long.until(
            EC.presence_of_element_located((By.CSS_SELECTOR, ".upload-progress, .progress, .uploading"))
        )
        print(f"  → Upload in progress ...")
    except Exception:
        print(f"  ⚠️ Progress indicator not found, continuing ...")

    # Wait for success message or download link
    try:
        wait_long.until(
            EC.presence_of_element_located(
                (By.CSS_SELECTOR, ".alert-success, .success, #result, a[href*='download'], .upload-success")
            )
        )
        print(f"  → Upload completed!")
    except Exception:
        print(f"  ⚠️ Success element not found, checking for links ...")

    # Find download link
    all_links = driver.find_elements(By.TAG_NAME, "a")
    for link in all_links:
        href = link.get_attribute('href')
        if href and ('download' in href or 'view' in href):
            return href

    if all_links:
        last_href = all_links[-1].get_attribute('href')
        if last_href:
            return last_href

    return driver.current_url


def upload_to_1fichier(driver, file_path, creds):
    """Upload to 1fichier.com using Selenium."""
    username = creds.get('username', '')
    password = creds.get('password', '')

    print(f"  → Opening 1fichier.com ...")
    driver.get("https://www.1fichier.com/")
    time.sleep(3)

    print(f"  → Page title: {driver.title}")
    wait = WebDriverWait(driver, 60)

    # Login if credentials provided
    if username and password:
        try:
            login_link = wait.until(
                EC.element_to_be_clickable((By.CSS_SELECTOR, "a[href*='login'], a[href*='connexion']"))
            )
            login_link.click()
            time.sleep(2)

            user_input = wait.until(
                EC.presence_of_element_located((By.CSS_SELECTOR, "input[name='email'], input[name='login']"))
            )
            user_input.send_keys(username)

            pass_input = driver.find_element(By.CSS_SELECTOR, "input[name='password']")
            pass_input.send_keys(password)

            submit_btn = driver.find_element(By.CSS_SELECTOR, "input[type='submit'], button[type='submit']")
            submit_btn.click()
            time.sleep(3)
            print(f"  → Logged in successfully")
        except Exception as e:
            print(f"  ⚠️ Login failed: {e}, continuing as guest ...")

    # Navigate to upload page
    driver.get("https://www.1fichier.com/upload.pl")
    time.sleep(3)

    # Wait for file input
    try:
        file_input = wait.until(
            EC.presence_of_element_located((By.CSS_SELECTOR, "input[type='file']"))
        )
        print(f"  → Found file input, sending file path ...")
    except Exception as e:
        print(f"  ❌ File input not found: {e}")
        print(f"  → Page source (first 2000 chars): {driver.page_source[:2000]}")
        raise Exception(f"File input not found on 1fichier.com: {e}")

    file_input.send_keys(os.path.abspath(file_path))
    print(f"  → File path sent: {os.path.abspath(file_path)}")
    time.sleep(1)

    # Click upload button
    try:
        upload_btn = wait.until(EC.element_to_be_clickable(
            (By.CSS_SELECTOR, "input[type='submit'], button[type='submit']")
        ))
        upload_btn.click()
        print(f"  → Upload button clicked")
    except Exception as e:
        print(f"  ⚠️ Upload button not found: {e}")

    # Wait for upload completion (up to 2 hours)
    print(f"  → Waiting for upload to complete (up to 2 hours) ...")
    wait_long = WebDriverWait(driver, 7200)
    try:
        wait_long.until(
            EC.presence_of_element_located(
                (By.CSS_SELECTOR, ".upload-success, .success, a[href*='download'], .result")
            )
        )
        print(f"  → Upload completed!")
    except Exception:
        print(f"  ⚠️ Success element not found, checking for links ...")

    # Find download link
    all_links = driver.find_elements(By.TAG_NAME, "a")
    for link in all_links:
        href = link.get_attribute('href')
        if href and ('download' in href or '1fichier' in href):
            return href

    if all_links:
        last_href = all_links[-1].get_attribute('href')
        if last_href:
            return last_href

    return driver.current_url


def upload_to_mixdrop(driver, file_path, creds):
    """Upload to mixdrop.co using Selenium."""
    print(f"  → Opening mixdrop.co ...")
    driver.get("https://mixdrop.co/")
    time.sleep(3)

    print(f"  → Page title: {driver.title}")
    wait = WebDriverWait(driver, 60)

    # Wait for file input
    try:
        file_input = wait.until(
            EC.presence_of_element_located((By.CSS_SELECTOR, "input[type='file']"))
        )
        print(f"  → Found file input, sending file path ...")
    except Exception as e:
        print(f"  ❌ File input not found: {e}")
        print(f"  → Page source (first 2000 chars): {driver.page_source[:2000]}")
        raise Exception(f"File input not found on mixdrop.co: {e}")

    file_input.send_keys(os.path.abspath(file_path))
    print(f"  → File path sent: {os.path.abspath(file_path)}")
    time.sleep(1)

    # Wait for upload to start
    print(f"  → Waiting for upload to complete (up to 2 hours) ...")
    wait_long = WebDriverWait(driver, 7200)
    try:
        wait_long.until(
            EC.presence_of_element_located(
                (By.CSS_SELECTOR, ".upload-success, .success, #result, a[href*='file'], .file-url")
            )
        )
        print(f"  → Upload completed!")
    except Exception:
        print(f"  ⚠️ Success element not found, checking for links ...")

    # Find download/embed link
    all_links = driver.find_elements(By.TAG_NAME, "a")
    for link in all_links:
        href = link.get_attribute('href')
        if href and ('/file/' in href or 'embed' in href or 'mixdrop' in href):
            return href

    if all_links:
        last_href = all_links[-1].get_attribute('href')
        if last_href:
            return last_href

    return driver.current_url


# =============================================================================
# API-BASED UPLOAD FUNCTIONS (no Selenium needed)
# =============================================================================

def upload_to_gofile(file_path, creds=None):
    """Upload to gofile.io using their API.

    No account required. Files are stored permanently.
    Returns download page URL and direct download link.
    """
    print(f"  → Uploading to gofile.io ...")

    # Step 1: Get best server
    try:
        servers_resp = requests.get("https://api.gofile.io/servers", timeout=30)
        servers_data = servers_resp.json()
        if servers_data.get('status') != 'ok':
            raise Exception(f"Failed to get servers: {servers_data}")
        server = servers_data['data']['servers'][0]['name']
        print(f"  → Using server: {server}")
    except Exception as e:
        print(f"  ⚠️ Failed to get server, using default: {e}")
        server = "store1"

    # Step 2: Upload file
    upload_url = f"https://{server}.gofile.io/contents/uploadfile"
    try:
        with open(file_path, 'rb') as f:
            files = {'file': (os.path.basename(file_path), f)}
            resp = requests.post(upload_url, files=files, timeout=7200)

        data = resp.json()
        if data.get('status') != 'ok':
            raise Exception(f"Upload failed: {data}")

        download_page = data['data']['downloadPage']
        file_id = data['data']['files'][0]['id']
        file_name = data['data']['files'][0]['name']
        direct_link = f"https://{server}.gofile.io/download/web/{file_id}/{file_name}"

        print(f"  → Upload successful!")
        print(f"  → Download page: {download_page}")
        return download_page

    except Exception as e:
        print(f"  ❌ Upload failed: {e}")
        raise


def upload_to_pixeldrain(file_path, creds=None):
    """Upload to pixeldrain.com using their API.

    No account required. Files are stored for ~90 days of inactivity.
    Returns the pixeldrain page URL.
    """
    print(f"  → Uploading to pixeldrain.com ...")

    try:
        with open(file_path, 'rb') as f:
            files = {'file': (os.path.basename(file_path), f)}
            resp = requests.put(
                "https://pixeldrain.com/api/file/",
                files=files,
                timeout=7200
            )

        data = resp.json()
        if data.get('success') != True:
            raise Exception(f"Upload failed: {data}")

        file_id = data['id']
        download_url = f"https://pixeldrain.com/u/{file_id}"
        direct_download = f"https://pixeldrain.com/api/file/{file_id}"

        print(f"  → Upload successful!")
        print(f"  → File ID: {file_id}")
        print(f"  → Page URL: {download_url}")
        return download_url

    except Exception as e:
        print(f"  ❌ Upload failed: {e}")
        raise


def upload_to_fileio(file_path, creds=None):
    """Upload to file.io using their REST API.

    Files are deleted after first download by default.
    Returns download link URL.
    """
    print(f"  → Uploading to file.io ...")

    try:
        with open(file_path, 'rb') as f:
            files = {'file': (os.path.basename(file_path), f)}
            resp = requests.post(
                "https://file.io",
                files=files,
                timeout=7200
            )

        data = resp.json()
        if data.get('success') != True:
            raise Exception(f"Upload failed: {data}")

        download_url = data['link']
        expires = data.get('expires', 'unknown')

        print(f"  → Upload successful!")
        print(f"  → Download link: {download_url}")
        print(f"  → Expires: {expires}")
        return download_url

    except Exception as e:
        print(f"  ❌ Upload failed: {e}")
        raise


def upload_to_catbox(file_path, creds=None):
    """Upload to catbox.moe using their API.

    No account required. Files are permanent (no deletion).
    Max file size: 200MB.
    Returns direct download URL.
    """
    print(f"  → Uploading to catbox.moe ...")

    try:
        with open(file_path, 'rb') as f:
            files = {'fileToUpload': (os.path.basename(file_path), f)}
            data = {
                'reqtype': 'fileupload',
                'userhash': ''
            }
            resp = requests.post(
                "https://catbox.moe/user/api.php",
                files=files,
                data=data,
                timeout=7200
            )

        result = resp.text.strip()
        if not result.startswith('https://'):
            raise Exception(f"Upload failed: {result}")

        download_url = result
        print(f"  → Upload successful!")
        print(f"  → Direct URL: {download_url}")
        return download_url

    except Exception as e:
        print(f"  ❌ Upload failed: {e}")
        raise


def upload_to_litterbox(file_path, creds=None):
    """Upload to litterbox.catbox.moe using their API.

    Temporary file hosting. Files expire after 1 hour to 72 hours.
    No account required. Max file size: 1GB.
    Returns direct download URL.
    """
    print(f"  → Uploading to litterbox.catbox.moe (temporary hosting) ...")

    try:
        with open(file_path, 'rb') as f:
            files = {'fileToUpload': (os.path.basename(file_path), f)}
            data = {
                'reqtype': 'fileupload',
                'time': '72h'  # Keep for 72 hours
            }
            resp = requests.post(
                "https://litterbox.catbox.moe/resources/internals/api.php",
                files=files,
                data=data,
                timeout=7200
            )

        result = resp.text.strip()
        if not result.startswith('https://'):
            raise Exception(f"Upload failed: {result}")

        download_url = result
        print(f"  → Upload successful! (expires in 72h)")
        print(f"  → Direct URL: {download_url}")
        return download_url

    except Exception as e:
        print(f"  ❌ Upload failed: {e}")
        raise


def upload_to_0x0(file_path, creds=None):
    """Upload to 0x0.st using their API.

    No account required. Anonymous file hosting.
    Files expire after ~2 weeks or when downloaded.
    Max file size: 512MB.
    Returns direct download URL.
    """
    print(f"  → Uploading to 0x0.st ...")

    try:
        with open(file_path, 'rb') as f:
            files = {'file': (os.path.basename(file_path), f)}
            resp = requests.post(
                "https://0x0.st",
                files=files,
                timeout=7200
            )

        result = resp.text.strip()
        if not result.startswith('https://'):
            raise Exception(f"Upload failed: {result}")

        download_url = result
        print(f"  → Upload successful!")
        print(f"  → Direct URL: {download_url}")
        return download_url

    except Exception as e:
        print(f"  ❌ Upload failed: {e}")
        raise


def upload_to_buzzheavier(file_path, creds=None):
    """Upload to buzzheavier.com using their API.

    No account required. No file type limits.
    Generous size/retention policies.
    Returns download page URL.
    """
    print(f"  → Uploading to buzzheavier.com ...")

    try:
        with open(file_path, 'rb') as f:
            files = {'file': (os.path.basename(file_path), f)}
            resp = requests.post(
                "https://buzzheavier.com/upload",
                files=files,
                timeout=7200
            )

        data = resp.json()
        if 'download_url' in data:
            download_url = data['download_url']
        elif 'url' in data:
            download_url = data['url']
        elif 'link' in data:
            download_url = data['link']
        else:
            # Try to extract from response
            download_url = resp.text.strip()
            if not download_url.startswith('http'):
                raise Exception(f"Upload failed: {data if isinstance(data, dict) else download_url}")

        print(f"  → Upload successful!")
        print(f"  → Download URL: {download_url}")
        return download_url

    except Exception as e:
        print(f"  ❌ Upload failed: {e}")
        raise


def upload_to_filebin(file_path, creds=None):
    """Upload to filebin.net using their API.

    No account required. "Bins" act as temporary folders.
    Returns direct download URL.
    """
    print(f"  → Uploading to filebin.net ...")

    # Generate a random bin name
    timestamp = str(int(time.time()))
    file_name = os.path.basename(file_path)
    bin_name = hashlib.md5(f"{timestamp}{file_name}".encode()).hexdigest()[:12]

    try:
        with open(file_path, 'rb') as f:
            headers = {
                'Content-Type': 'application/octet-stream',
                'Filename': file_name
            }
            resp = requests.put(
                f"https://filebin.net/{bin_name}/{file_name}",
                data=f,
                headers=headers,
                timeout=7200
            )

        if resp.status_code in [200, 201]:
            download_url = f"https://filebin.net/{bin_name}/{file_name}"
            print(f"  → Upload successful!")
            print(f"  → Direct URL: {download_url}")
            return download_url
        else:
            raise Exception(f"Upload failed with status {resp.status_code}: {resp.text}")

    except Exception as e:
        print(f"  ❌ Upload failed: {e}")
        raise


def upload_to_generic(driver, file_path, creds, site_name):
    """Fallback for unsupported sites."""
    return f"Unsupported site: {site_name}"


# =============================================================================
# SITE REGISTRY
# =============================================================================

# Map site names to their upload functions
# API-based sites use requests library (no Selenium driver needed)
UPLOAD_FUNCS = {
    # Selenium-based sites
    "erfanzadeh.ir": upload_to_erfanzadeh,
    "krakenfiles.com": upload_to_krakenfiles,
    "1fichier.com": upload_to_1fichier,
    "mixdrop.co": upload_to_mixdrop,
    # API-based sites (use requests library)
    "gofile.io": upload_to_gofile,
    "pixeldrain.com": upload_to_pixeldrain,
    "file.io": upload_to_fileio,
    "catbox.moe": upload_to_catbox,
    "litterbox.catbox.moe": upload_to_litterbox,
    "0x0.st": upload_to_0x0,
    "buzzheavier.com": upload_to_buzzheavier,
    "filebin.net": upload_to_filebin,
}

# Sites that require Selenium (browser automation)
SELENIUM_SITES = {
    "erfanzadeh.ir",
    "krakenfiles.com",
    "1fichier.com",
    "mixdrop.co",
}

# Sites that use API (requests library only)
API_SITES = {
    "gofile.io",
    "pixeldrain.com",
    "file.io",
    "catbox.moe",
    "litterbox.catbox.moe",
    "0x0.st",
    "buzzheavier.com",
    "filebin.net",
}


def main():
    parser = argparse.ArgumentParser(description="Upload files to various file hosting services")
    parser.add_argument("--file", required=True, help="Path to the file to upload")
    parser.add_argument("--sites", required=True, help="Comma-separated list of target sites")
    parser.add_argument("--creds", default="", help="Credentials string (site:username:password per line)")
    args = parser.parse_args()

    sites = [s.strip() for s in args.sites.split(",")]
    creds_dict = parse_credentials(args.creds, sites)

    # Determine which sites need Selenium
    selenium_needed = any(site in SELENIUM_SITES for site in sites)
    driver = None

    if selenium_needed:
        print(f"Creating Chrome driver ...")
        driver = make_driver()
        print(f"Chrome driver ready ✓")

    results = {}
    for site in sites:
        print(f"\n📤 Uploading to {site} ...")
        func = UPLOAD_FUNCS.get(site)

        if func is None:
            print(f"⚠️ Unknown site: {site}")
            results[site] = f"Unknown site: {site}"
            continue

        try:
            if site in API_SITES:
                # API-based upload (no Selenium driver needed)
                link = func(args.file, creds_dict.get(site, {'guest': True}))
            else:
                # Selenium-based upload (needs driver)
                if driver is None:
                    driver = make_driver()
                link = func(driver, args.file, creds_dict.get(site, {'guest': True}))

            results[site] = link
            print(f"✅ {site} -> {link}")
        except Exception as e:
            results[site] = f"Error: {str(e)}"
            print(f"❌ {site} failed: {e}")

    if driver:
        driver.quit()

    # Save results to file
    with open("upload_results.txt", "w", encoding="utf-8") as f:
        for site, link in results.items():
            f.write(f"{site}: {link}\n")

    # Also output results as JSON for programmatic use
    with open("upload_results.json", "w", encoding="utf-8") as f:
        json.dump(results, f, indent=2, ensure_ascii=False)

    print(f"\n📝 Results saved to upload_results.txt and upload_results.json")

    # Print summary
    print(f"\n📊 Upload Summary:")
    print(f"{'─' * 50}")
    for site, link in results.items():
        status = "✅" if not link.startswith("Error") else "❌"
        print(f"  {status} {site}: {link[:80]}{'...' if len(link) > 80 else ''}")


if __name__ == "__main__":
    main()
