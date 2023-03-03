#!/usr/local/bin/bash

dirs=(
    "/Applications"
    "/System/Applications"
    "/System/Applications/Utilities"
    "/System/Library/CoreServices"
    "/System/Library/CoreServices/Applications"
    $(echo "$PATH" | tr ':' ' ')
    "$HOME"
    "$HOME/Documents"
    "$HOME/Desktop"
)

fzf_config=(
    --layout=reverse 
    --scheme=path
    --tiebreak=chunk
    --header='Prefix: $ -> commnad, ? -> browser search, @ -> url/file'
    --bind 'esc:cancel'
    --bind 'tab:replace-query'
)

FIFO=/tmp/bashlauncher_query_buffer.txt
DB=/tmp/bashlauncher_dir_db.txt

EDITOR="alacritty msg create-window -e nvim"

init() {
    # setup query buffer
    if [[ -e $FIFO ]]; then
        rm $FIFO
    fi
    mkfifo $FIFO

    # setup query database
    if [[ -e $DB ]]; then
        rm $DB
    fi
    touch $DB
}

unique() {
    while true; do
        read q
        # filter out empty queries
        if [[ -z "$q" ]]; then
            continue
        fi

        if [[ ! -z $(grep "$q" $DB) ]]; then
            continue # wait for next unique query
        elif [[ ! -e "$q" ]]; then
            continue
        else
            echo "$q" >> $DB
            echo "$q" | sed -E 's/( )/\\\1/g'
        fi
    done
}

finder() {
    tail -f $FIFO |
    unique |
    xargs -n 1 -J % find -L % -mindepth 1 -maxdepth 1 2>/dev/null
}

action(){
    # Mac app
    if [[  ${1##*.} == "app" ]]; then
        open "$1"
        return
    fi
    # executable
    if [[ -x "$1" && ! -d "$1" ]]; then
        "$1"
        return
    fi
    type=$(file -b "$1")
    # text file
    if [[ "$type" =~ "text" ]]; then
        $EDITOR "$1"
        return
    fi
    # just try to open it anyways
    open "$1"
}

fixurl(){
    url="$1"
    if [[ ! ("$url" =~ '^http://' || "$url" =~ '^https://') ]]; then
        url="https://$url"
    fi
    echo "$url"
}

search(){
    open "https://google.com/search?q=$1"
}

query(){
    # filter out empty queries
    if [[ -z "$1" ]]; then
        return
    fi

    head="${1:0:1}"
    tail="${1:1}"
    case $head in
        '$')
            # execute bash command
            echo "> $tail"
            echo "$tail" | $SHELL -s
            echo "Press <enter> to exit"
            head -n 1
            ;;
        '?')
            # browser search
            search "$tail"
            ;;
        '@')
            # try resolve url host
            if [[ "$(host "$tail")" =~ "has address" ]]; then
                open $(fixurl "$tail")
            else
                open "$tail"
            fi
            ;;
    esac
}

generate_files() {
    # removed non existing files from list
    for dir in $@; do
        if [[ -e "$dir" ]]; then
            realpath -m "$dir" > $FIFO
        fi
    done
}

main(){
    init
    generate_files $@ &
    
    # finder keeps reading fifo for new input
    # kill finder when fzf ends
    # https://unix.stackexchange.com/a/404277
    result=$(
        {
            fzf --print-query "${fzf_config[@]}" \
                --bind "change:execute-silent(realpath {q} > $FIFO)" \
                --bind 'enter:accept+abort'
            kill "$!"
        } < <(finder)
    )

    lines=$(echo "$result" | wc -l | xargs)
    # Not matches in fzf prints query only
    # One match in fzf prints query and selection
    # Does not allow multi-selection
    case "$lines" in
        2)
            result=$(echo "$result" | tail -n 1)
            action "$result"
            ;;
        1)
            query "$result"
            ;;
        *)
            ;;
    esac

    # cleanup
    rm $FIFO $DB
    trap "exit" INT TERM
    trap "kill 0" EXIT
}

cd "$HOME"
main ${dirs[@]}
