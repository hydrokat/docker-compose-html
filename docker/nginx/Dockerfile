FROM nginx:1.27-alpine

COPY docker/nginx/nginx.conf /etc/nginx/nginx.conf
COPY docker/nginx/certs/ /etc/nginx/certs/
COPY www/ /usr/share/nginx/html/

EXPOSE 80 443
