# aniview-cli

A tool to watch anime from the terminal on Arch Linux.

## Features

- Interactive selection with fzf
- Play video directly with mpv
- Lightweight and simple

## Dependencies

Make sure you have installed:

```bash
sudo pacman -S --needed jq curl fzf mpv yt-dlp


Usage:

Run the script with a search query for an anime episode. The script automatically handles different ways to specify episodes:

./bin/aniview-cli.sh "Another capitulo 1"


You can use “capitulo”, “episodio”, "sub", or “EP” interchangeably.

If the anime has a saga or arc, include it in the search query, e.g.:

./bin/aniview-cli.sh "Dragon Ball Saga Name EP3"


The script will automatically add “capitulo” if no episode keyword is provided.

Filters and deduplication ensure only relevant episodes appear in the list.

