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

# ===== Map de alias para videos que la API no devuelve =====
# Ejemplo: ALIAS["dragon ball ep1"]="url_del_video"
declare -A ALIAS
# Añade aquí episodios problemáticos que la API no devuelve
# ALIAS["nombre del anime epX"]="URL del video"

# Convertir búsqueda a minúsculas
QUERY_LOWER=$(echo "$QUERY" | tr '[:upper:]' '[:lower:]')

# Si existe un alias, reproducir directamente
if [[ -n "${ALIAS[$QUERY_LOWER]}" ]]; then
    echo "Reproduciendo alias conocido: $QUERY"
    mpv "${ALIAS[$QUERY_LOWER]}"
    exit 0
fi

# ===== Normalización de episodios para la búsqueda API =====
for i in {1..99}; do
    padded=$(printf "%02d" $i)
    QUERY_LOWER=$(echo "$QUERY_LOWER" | sed -E "s/ep$i/episode $padded/g")
done

# Escapar para URL
ENCODED=$(printf '%s' "$QUERY_LOWER" | jq -sRr @uri)
API_URL="https://api.dailymotion.com/videos?search=$ENCODED&limit=100&fields=title,id"

# ===== Obtener lista de resultados =====
RAW_LIST=$(curl -s "$API_URL" | jq -r '.list[] | "\(.title)|https://www.dailymotion.com/video/\(.id)"' \
| grep -viE 'trailer|traíler|amv|asmv|hentai|h3ntai|gameplay|psp|gba|ps3|iso|game|download|preview|impressions|react|reacción|reaccion|minecraft|easter[[:space:]]*egg|review|clip|cover|teaser|curiosidades|avance|opening|ending|op|intro|oficial|edit|ED1')

# ===== Separar y priorizar títulos con palabras clave de episodio =====
PRIORITY_KEYWORDS='EP|Episode|Episodio|CAPITULO|Capitulo|capitulos'

PRIORITY_LIST=$(echo "$RAW_LIST" | grep -E "$PRIORITY_KEYWORDS")
NORMAL_LIST=$(echo "$RAW_LIST" | grep -v -E "$PRIORITY_KEYWORDS")

# Lista final, prioritaria primero
LIST="$PRIORITY_LIST"$'\n'"$NORMAL_LIST"

# ===== Seleccionar con fzf =====
SELECTED=$(echo "$LIST" | fzf --height 20 --border --prompt="Selecciona un video: ")

VIDEO_URL=$(echo "$SELECTED" | cut -d '|' -f2 | xargs)

# ===== Reproducir =====
if [ -n "$VIDEO_URL" ]; then
    mpv "$VIDEO_URL"
else
    echo "Nada seleccionado."
fi
