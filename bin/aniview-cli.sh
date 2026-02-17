#!/usr/bin/env bash

echo "======================================"
echo " animeview - fjavierl-dev"
echo " Buscador y reproductor de anime CLI PRO"
echo "======================================"
echo ""

QUERY="$*"
if [ -z "$QUERY" ]; then
    read -rp "Buscar anime: " QUERY
fi

# ===== Alias =====
declare -A ALIAS
QUERY_LOWER=$(echo "$QUERY" | tr '[:upper:]' '[:lower:]')

if [[ -n "${ALIAS[$QUERY_LOWER]}" ]]; then
    echo "Reproduciendo alias conocido: $QUERY"
    mpv "${ALIAS[$QUERY_LOWER]}"
    exit 0
fi

# ===== Si no hay indicio de episodio, añadir "capitulo" automáticamente =====
if ! [[ "$QUERY_LOWER" =~ (ep|episode|capitulo|capitulos) ]]; then
    QUERY_LOWER="$QUERY_LOWER capitulo"
fi

# ===== Normalización episodios =====
for i in {1..99}; do
    padded=$(printf "%02d" $i)
    QUERY_LOWER=$(echo "$QUERY_LOWER" | sed -E "s/ep$i/episode $padded/g")
done
ENCODED=$(printf '%s' "$QUERY_LOWER" | jq -sRr @uri)

# ===== Función de filtros =====
filter_results() {
    grep -viE 'trailer|traíler|amv|asmv|hentai|h3ntai|gameplay|psp|gba|ps3|ps2|iso|game|download|preview|impressions|react|reacción|reaccion|minecraft|easter[[:space:]]*egg|review|clip|cover|teaser|curiosidades|avance|opening|ending|op|intro|oficial|edit|ED1|cutscenes|ncg|playthrough|title|musique|Musique|OST|Jugando|juego|resumen|moments'
}

# ===== Archivos temporales para paralelo =====
DM_FILE=$(mktemp)
YT_FILE=$(mktemp)

# ===== Dailymotion =====
DM_API="https://api.dailymotion.com/videos?search=$ENCODED&limit=100&fields=title,id"
curl -s "$DM_API" \
    | jq -r '.list[] | "[DM] \(.title)|https://www.dailymotion.com/video/\(.id)"' \
    | filter_results > "$DM_FILE" &

# ===== YouTube =====
timeout 5 yt-dlp "ytsearch15:$QUERY_LOWER" \
    --flat-playlist \
    --skip-download \
    --print "[YT] %(title)s|%(webpage_url)s" 2>/dev/null \
    | filter_results > "$YT_FILE" &

wait

# ===== Leer resultados =====
DM_LIST=$(cat "$DM_FILE")
YT_LIST=$(cat "$YT_FILE")

rm "$DM_FILE" "$YT_FILE"

# ===== Combinar y deduplicar =====
COMBINED=$(printf "%s\n%s\n" "$DM_LIST" "$YT_LIST" | awk -F '|' '{ if(!seen[tolower($1)]++) print $0 }')

# ===== Filtrar solo títulos con episodio =====
FILTERED="$COMBINED"  # Ya añadimos "capitulo" a la búsqueda si no existía

# ===== Prioridad =====
PRIORITY_KEYWORDS='EP|Episode|Episodio|CAPITULO|Capitulo|capitulos'
PRIORITY_LIST=$(echo "$FILTERED" | grep -E "$PRIORITY_KEYWORDS")
NORMAL_LIST=$(echo "$FILTERED" | grep -v -E "$PRIORITY_KEYWORDS")
LIST="$PRIORITY_LIST"$'\n'"$NORMAL_LIST"

# ===== Ocultar URLs para mostrar solo títulos en fzf =====
DISPLAY_LIST=$(echo "$LIST" | awk -F '|' '{print $1}')

# ===== Selección con fzf =====
SELECTED_TITLE=$(echo "$DISPLAY_LIST" | fzf --height 20 --border --prompt="Selecciona un video: ")

# ===== Recuperar URL correspondiente =====
VIDEO_URL=$(echo "$LIST" | grep -i "^$SELECTED_TITLE|" | cut -d '|' -f2 | xargs)

# ===== Reproducir =====
if [ -n "$VIDEO_URL" ]; then
    mpv "$VIDEO_URL"
else
    echo "Nada seleccionado."
fi
