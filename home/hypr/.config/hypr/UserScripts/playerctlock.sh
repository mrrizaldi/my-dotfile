#!/bin/bash

if [ $# -eq 0 ]; then
    echo "Usage: $0 --title | --arturl | --artist | --length | --album | --source | --status"
    exit 1
fi

get_metadata() {
    key=$1
    playerctl metadata --format "{{ $key }}" 2>/dev/null
}

get_source_info() {
    trackid=$(get_metadata "mpris:trackid")
    if [[ "$trackid" == *"firefox"* ]]; then
        echo "Firefox"
    elif [[ "$trackid" == *"spotify"* ]]; then
        echo "Spotify"
    elif [[ "$trackid" == *"chromium"* ]]; then
        echo "Chrome"
    else
        echo ""
    fi
}

case "$1" in
    --title)
        title=$(get_metadata "xesam:title")
        [ -z "$title" ] && echo "" || echo "${title:0:30}"
        ;;
    --arturl)
        url=$(get_metadata "mpris:artUrl")
        if [ -z "$url" ]; then
            echo ""
        else
            [[ "$url" == file://* ]] && url=${url#file://}
            echo "$url"
        fi
        ;;
    --artist)
        artist=$(get_metadata "xesam:artist")
        [ -z "$artist" ] && echo "" || echo "${artist:0:28}"
        ;;
    --length)
        length=$(get_metadata "mpris:length")
        [ -z "$length" ] && echo "" || echo "$(echo "scale=2; $length / 1000000 / 60" | bc)m"
        ;;
    --status)
        status=$(playerctl status 2>/dev/null)
        if [[ $status == "Playing" ]]; then
            echo "Playing"
        elif [[ $status == "Paused" ]]; then
            echo "Paused"
        else
            echo ""
        fi
        ;;
    --album)
        album=$(playerctl metadata --format "{{ xesam:album }}" 2>/dev/null)
        [ -n "$album" ] && echo "${album:0:28}" || echo ""
        ;;
    --source)
        get_source_info
        ;;
    *)
        echo "Invalid option: $1"
        exit 1
        ;;
esac
