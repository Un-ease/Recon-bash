#!/bin/bash

echo '''
________       _______                
\______   \ __ \_   _ \  __   __  
 |       // _ \/    \  \/ /  _ \ /    \ 
 |    |   \  ___/\     \___(  <_> )   |  \
 |____|_  /\___  >\______  /\____/|___|  /
        \/     \/        \/            \/ 
                             
'''


recon() {
    DOMAIN=$1
    DIRECTORY=$2

    if [ ! -d "$DIRECTORY" ]; then
        echo "Directory Doesn't Exist"
        exit 1
    fi
    
    echo "[+] Starting Subfinder \n"
    subfinder -d "$DOMAIN" -recursive -silent -o "$DIRECTORY/subdomain1.txt" 
    if [ $? -ne 0 ]; then
        echo "❌ Subfinder failed. Exiting..."
        exit 1
    fi

    echo "[+] Starting Asset Finder..."
    assetfinder -subs-only "$DOMAIN" > "$DIRECTORY/subdomain2.txt"
    if [ $? -ne 0 ]; then
        echo "❌ Assetfinder failed. Exiting..."
        exit 1
    fi
    
    subfinder -d "$DOMAIN" -o "$DIRECTORY/subdomain3.txt"
    if [ $? -ne 0 ]; then
        echo "❌ Subfinder failed. Exiting..."
        exit 1
    fi

    echo '[+] Sorting The Domains'
    sort -u "$DIRECTORY/subdomain1.txt" "$DIRECTORY/subdomain2.txt" "$DIRECTORY/subdomain3.txt" > "$DIRECTORY/all_subs.txt"
    rm "$DIRECTORY/subdomain1.txt" "$DIRECTORY/subdomain2.txt" "$DIRECTORY/subdomain3.txt"
}

dns_resolve(){
    echo '[+] Resolving Dns' 
    dnsx -silent -l $DIRECTORY/all_subs.txt -o $DIRECTORY/resolved.txt  
}


http_probe(){
    echo "[+] Checking For live servers"
    httpx -l $DIRECTORY/resolved.txt -silent -status-code -title -tech-detect -o $DIRECTORY/httpx.txt 

    echo "[+] Total live subdomains: $(wc -l < "$DIRECTORY/httpx.txt")"

    cat "$DIRECTORY/httpx.txt" | sed 's/\x1b\[[0-9;]*m//g' | grep "\[200\]" > "$DIRECTORY/200.txt"
    echo "[+] 200 status code domains: $(wc -l < "$DIRECTORY/200.txt")"

    echo "[+] Taking Screenshots"
    awk '{print $1}' > $DIRECTORY/plain.txt
    cat $DIRECTORY/plain.txt | httpx -screenshot -silent -srd $DIRECTORY > /dev/null 
    echo "[+] Screenshots saved in $DIRECTORY"
}


echo "Enter the Domain (eg. example.com)"
read DOMAIN

echo "Enter the Directory you want to save the file in:"
read DIRECTORY

if [[ -z "$DOMAIN" || -z "$DIRECTORY" ]]; then
    echo " Error: Both domain and directory are required."
    exit 1
fi


recon "$DOMAIN" "$DIRECTORY"
dns_resolve "$DIRECTORY"
http_probe "$DIRECTORY"

echo "✅ Reconnaissance completed successfully!"