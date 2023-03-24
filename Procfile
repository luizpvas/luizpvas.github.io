css: tailwindcss -i index.css -o _dist/index.css --watch
build: inotifywait -m posts/ -m public/ -m pages/ -m index.css -m tailwind.config.js -e close_write | while read CHANGED; do ruby build.rb; cp -r public/* _dist/; done
web: ruby -run -e httpd _dist -p 8000
