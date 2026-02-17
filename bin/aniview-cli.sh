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
if ! [[ "$QUERY_LOWER" =~ (ep|episode|episodio|capitulo|capitulos) ]]; then
    QUERY_LOWER="$QUERY_LOWER capitulo"
fi

# ===== Normalización de episodios =====
for i in {1..99}; do
    padded=$(printf "%02d" $i)
    QUERY_LOWER=$(echo "$QUERY_LOWER" | sed -E "s/ep$i/episode $padded/g")
done
ENCODED=$(printf '%s' "$QUERY_LOWER" | jq -sRr @uri)

# ===== Función de normalización de acentos =====
normalize() {
    echo "$1" | iconv -f UTF-8 -t ASCII//TRANSLIT
}

# ===== Función de filtros =====
filter_results() {
    while read -r line; do
        normalized=$(normalize "$line")
        echo "$normalized" | grep -viE 'trailer|amv|asmv|hentai|h3ntai|gameplay|psp|gba|ps3|ps2|iso|game|download|preview|impressions|react|reaccion|minecraft|easter[[:space:]]*egg|review|clip|cover|teaser|curiosidades|avance|opening|ending|op|intro|oficial|edit|ED1|cutscenes|ncg|playthrough|title|musique|Musique|OST|Jugando|juego|resumen|photo(s)?|karaoke|KARAOKE|tribute|Tribute|moment(s)?|switch|teorias|fandub|spoiler(s)?|XXX|sex|porn|porno|legal|illegal|wallpaper|cinematic|xbox|teoria|annuncio|P3ndeja' && echo "$line"
    done
}

# ===== Archivos temporales =====
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

DM_LIST=$(cat "$DM_FILE")
YT_LIST=$(cat "$YT_FILE")
rm "$DM_FILE" "$YT_FILE"

# ===== Combinar y deduplicar =====
COMBINED=$(printf "%s\n%s\n" "$DM_LIST" "$YT_LIST" | awk -F '|' '{ if(!seen[tolower($1)]++) print $0 }')

# ===== Prioridad de episodios =====
PRIORITY_KEYWORDS='EP|Episode|Episodio|CAPITULO|Capitulo|capitulos'
PRIORITY_LIST=$(echo "$COMBINED" | grep -E "$PRIORITY_KEYWORDS")
NORMAL_LIST=$(echo "$COMBINED" | grep -v -E "$PRIORITY_KEYWORDS")
LIST="$PRIORITY_LIST"$'\n'"$NORMAL_LIST"

# ===== Construir mapa título → URL limpio =====
declare -A MAP_TITLE_URL
DISPLAY_LIST=""
while IFS='|' read -r title url; do
    [[ -z "$title" || -z "$url" ]] && continue
    title=$(echo "$title" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    url=$(echo "$url" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    MAP_TITLE_URL["$title"]="$url"
    DISPLAY_LIST+="$title"$'\n'
done <<< "$LIST"

# ===== Selección con fzf =====
SELECTED_TITLE=$(echo "$DISPLAY_LIST" | fzf --height 20 --border --prompt="Selecciona un video: ")

# ===== Extraer URL correcto =====
VIDEO_URL="${MAP_TITLE_URL[$SELECTED_TITLE]}"

# ===== Reproducir =====
if [ -n "$VIDEO_URL" ]; then
    mpv "$VIDEO_URL"
else
    echo "Nada seleccionado."
fi
