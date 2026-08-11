FROM nginx:alpine

COPY marya.html /usr/share/nginx/html/index.html

EXPOSE 80
