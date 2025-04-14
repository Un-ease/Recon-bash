#!/bin/bash

echo '''
__________       _________                
\______   \ ____ \_   ___ \  ____   ____  
 |       _// __ \/    \  \/ /  _ \ /    \ 
 |    |   \  ___/\     \___(  <_> )   |  \
 |____|_  /\___  >\______  /\____/|___|  /
        \/     \/        \/            \/ 
                             
'''

recon() {
    local DOMAIN=$1
    local DIRECTORY=$2

    if [ ! -d "$DIRECTORY" ]; then
        mkdir -p "$DIRECTORY" || { echo "❌ Failed to create directory"; exit 1; }
    fi
    
    echo "[+] Starting Subfinder"
    subfinder -d "$DOMAIN" -recursive -silent -o "$DIRECTORY/subdomain1.txt" || { echo "❌ Subfinder failed"; exit 1; }

    echo "[+] Starting Asset Finder"
    assetfinder -subs-only "$DOMAIN" > "$DIRECTORY/subdomain2.txt" || { echo "❌ Assetfinder failed"; exit 1; }
    
    echo "[+] Running Subfinder (second pass)"
    subfinder -d "$DOMAIN" -silent -o "$DIRECTORY/subdomain3.txt" || { echo "❌ Subfinder failed"; exit 1; }

    echo '[+] Sorting The Domains'
    sort -u "$DIRECTORY/subdomain1.txt" "$DIRECTORY/subdomain2.txt" "$DIRECTORY/subdomain3.txt" > "$DIRECTORY/all_subs.txt" || { echo "❌ Sorting failed"; exit 1; }
    rm -f "$DIRECTORY/subdomain1.txt" "$DIRECTORY/subdomain2.txt" "$DIRECTORY/subdomain3.txt"
}

dns_resolve() {
    local DIRECTORY=$1
    echo '[+] Resolving DNS' 
    dnsx -silent -l "$DIRECTORY/all_subs.txt" -o "$DIRECTORY/resolved.txt" || { echo "❌ DNS resolution failed"; exit 1; }
}

http_probe() {
    local DIRECTORY=$1
    echo "[+] Checking For live servers"
    httpx-toolkit -l "$DIRECTORY/resolved.txt" -silent -status-code -title -tech-detect -o "$DIRECTORY/httpx-toolkit.txt" || { echo "❌ HTTP probing failed"; exit 1; }

    echo "[+] Total live subdomains: $(wc -l < "$DIRECTORY/httpx-toolkit.txt")"

    # Clean ANSI colors before filtering
    cat "$DIRECTORY/httpx-toolkit.txt" | sed 's/\x1b\[[0-9;]*m//g' | grep "\[200\]" > "$DIRECTORY/200.txt"
    echo "[+] 200 status code domains: $(wc -l < "$DIRECTORY/200.txt")"

    # Extract URLs for screenshots
    awk '{print $1}' "$DIRECTORY/200.txt" > "$DIRECTORY/plain.txt"
    echo "[+] Taking screenshots"
    httpx-toolkit -l "$DIRECTORY/plain.txt" -silent -screenshot -srd "$DIRECTORY" >/dev/null 2>&1
    echo "[+] Screenshots saved in $DIRECTORY"
}

# Main execution
echo "Enter the Domain (eg. example.com)"
read -r DOMAIN

echo "Enter the Directory you want to save the file in:"
read -r DIRECTORY

if [[ -z "$DOMAIN" || -z "$DIRECTORY" ]]; then
    echo "❌ Error: Both domain and directory are required."
    exit 1
fi

recon "$DOMAIN" "$DIRECTORY"
dns_resolve "$DIRECTORY"
http_probe "$DIRECTORY"

echo "✅ Reconnaissance completed successfully!"