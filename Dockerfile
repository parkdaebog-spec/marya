FROM nginx:alpine

COPY marya.html /usr/share/nginx/html/index.html
COPY 1.jpg 2.jpg 3.jpg 4.jpg 5.jpg /usr/share/nginx/html/

EXPOSE 80
