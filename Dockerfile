FROM nginx:alpine

COPY marya.html /usr/share/nginx/html/index.html
COPY 2.jpg 3.jpg /usr/share/nginx/html/

EXPOSE 80
