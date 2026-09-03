FROM nginx:alpine

COPY . /usr/share/nginx/html/
COPY marya.html /usr/share/nginx/html/index.html

EXPOSE 80
