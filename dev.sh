#!/bin/bash

inotifywait -m posts/ -m public/ -m pages/ -m index.css -m tailwind.config.js -e close_write |
    while read; do
        tailwindcss -i index.css -o _dist/index.css && ruby build.rb
    done
