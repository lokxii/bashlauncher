# Bashlauncher
A mac app launcher written with bash

## Features
- Uses `fzf` for fuzzy finding
- Fast startup time
- Opens url
- Searches the web with query
- Opens text files immediately with configurable editor
- Executes shell command
- Shell-like file browsing with completion

## Dependencies
- `fzf`

## Usage
```sh
./bashlauncher.sh
```
`bashlauncher.sh` does not take any command line arguments

You may want to copy the script to a bin folder in your path (e.g.
`/usr/local/bin/`) and remove the `.sh` extension.

I personally use it with `skhd` to replace spotlight search.

## LICENSE
MIT
