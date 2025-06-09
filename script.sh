#!/bin/bash

# ==========================
# Advanced Pentest Automation Script
# ==========================

# Input validation
if [ -z "$1" ]; then
  echo "Usage: $0 domain.com"
  exit 1
fi

DOMAIN="$1"
ROOT_DOMAIN=$(echo "$DOMAIN" | awk -F. '{print $(NF-1)"."$NF}')
OUTPUT_DIR="pentest_output_$DOMAIN"
TOOLS=("nuclei" "testssl" "gospider" "dnsrecon" "curl" "naabu" "httpx" "jshunter")

# Check tool dependencies
for tool in "${TOOLS[@]}"; do
  if ! command -v "$tool" &>/dev/null; then
    echo "Error: $tool not found in PATH. Please install it."
    exit 1
  fi
done

# Create output directories
mkdir -p "$OUTPUT_DIR"/{nuclei,ssl,cookies,gospider,dns,ports,tech,jshunter}

echo "[*] Starting pentesting on $DOMAIN"
echo "[*] Output will be saved to $OUTPUT_DIR"

# Function: Check Missing Security Headers
check_missing_headers() {
  echo "[*] Running nuclei (missing headers)..."
  nuclei -u "https://$DOMAIN" > "$OUTPUT_DIR/nuclei/full-scan.txt" 2>/dev/null
  echo "[+] Nuclei (missing headers) complete."
}

# Function: Full Nuclei scan with selected categories
run_nuclei_advanced() {
  echo "[*] Running full nuclei scan with key categories..."
  nuclei -u "https://$DOMAIN" \
    -t exposures/ \
    -t cves/ \
    -t technologies/ \
    -t misconfiguration/ \
    > "$OUTPUT_DIR/nuclei/custom-scan.txt" 2>/dev/null
  echo "[+] Nuclei category scan complete."
}

# Function: testssl
run_testssl() {
  echo "[*] Running testssl..."
  testssl "$DOMAIN" > "$OUTPUT_DIR/ssl/testssl.txt" 2>/dev/null
  echo "[+] testssl complete."
}

# Function: Check Set-Cookie flags
check_cookie_flags() {
  echo "[*] Checking cookie flags..."
  curl -s -I "https://$DOMAIN" | grep -i "Set-Cookie" > "$OUTPUT_DIR/cookies/cookie-flags.txt"
  echo "[+] Cookie flags check complete."
}

# Function: GoSpider crawling
run_gospider() {
  echo "[*] Running GoSpider..."
  gospider -s "https://$DOMAIN" --js -d 2 --sitemap --robots -w -r -t 30 -q \
    | grep -Eo "https?://([a-z0-9]+[.])*$DOMAIN[^\"' >]+" \
    > "$OUTPUT_DIR/gospider/urls.txt" 2>/dev/null
  echo "[+] GoSpider complete."
}

# Function: DNSRecon
run_dnsrecon() {
  echo "[*] Running dnsrecon..."
  dnsrecon -d "$DOMAIN" > "$OUTPUT_DIR/dns/dnsrecon.txt" 2>/dev/null
  echo "[+] DNSRecon complete."
}

# Function: Naabu port scan
run_naabu() {
  echo "[*] Running Naabu..."
  naabu -host "$DOMAIN" > "$OUTPUT_DIR/ports/naabu.txt" 2>/dev/null
  echo "[+] Naabu complete."
}

# Function: HTTPX technology detection
run_httpx() {
  echo "[*] Running HTTPX..."
  httpx -u "$DOMAIN" -td > "$OUTPUT_DIR/tech/technologies.txt" 2>/dev/null
  echo "[+] HTTPX complete."
}

# Function: JSHunter on GoSpider JS URLs
run_jshunter() {
  echo "[*] Running JSHunter on discovered JavaScript files..."
  cat $OUTPUT_DIR/gospider/urls.txt | grep "\.js" | jshunter > $OUTPUT_DIR/jushunter/jshunter.txt
}

# ==========================
# Run All Tasks
# ==========================

# Run GoSpider first to feed JSHunter
run_gospider

# Run JSHunter after GoSpider
run_jshunter &

# Run remaining scans in parallel
check_missing_headers &
run_testssl &
check_cookie_flags &
run_nuclei_advanced &
run_dnsrecon &
run_naabu &
run_httpx &

# Wait for all background tasks
wait

# Final status
echo -e "\n[*] All scans completed."
echo "[*] Organized output saved in: $OUTPUT_DIR"
