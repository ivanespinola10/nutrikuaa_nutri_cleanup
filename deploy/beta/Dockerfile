# Build Flutter first in CI and copy its private artifact into this context.
# Deploy only with Cloud Run IAP required and unauthenticated invocations off.
FROM nginx:stable-alpine
COPY build/web/ /usr/share/nginx/html/
COPY deploy/beta/default.conf /etc/nginx/conf.d/default.conf
EXPOSE 8080
