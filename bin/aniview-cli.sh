#!/usr/bin/env bash

# ===== ABOUT =====
echo "======================================"
echo " animeview - fjavierl-dev"
echo " Buscador y reproductor de anime CLI"
echo "======================================"
echo ""

QUERY="$*"

if [ -z "$QUERY" ]; then
    read -rp "Buscar en Dailymotion: " QUERY
fi

ENCODED=$(printf '%s' "$QUERY" | jq -sRr @uri)
API_URL="https://api.dailymotion.com/videos?search=$ENCODED&limit=100&fields=title,id"

LIST=$(curl -s "$API_URL" | jq -r '.list[] | "\(.title)|https://www.dailymotion.com/video/\(.id)"' \
| grep -viE 'trailer|amv|asmv|hentai|h3ntai|gameplay|psp|gba|ps3|iso|game|download|preview|impressions|react|reacción|reaccion|minecraft|easter[[:space:]]*egg')

SELECTED=$(echo "$LIST" | fzf --height 20 --border --prompt="Selecciona un video: ")

VIDEO_URL=$(echo "$SELECTED" | cut -d '|' -f2 | xargs)

if [ -n "$VIDEO_URL" ]; then
    mpv "$VIDEO_URL"
else
    echo "Nada seleccionado."
fi
