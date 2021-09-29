FROM golang:alpine3.14 AS builder
# Install xcaddy to build caddy plugins
RUN go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest

# Build auth plugins for caddy
RUN xcaddy build \
	--with github.com/greenpau/caddy-auth-portal@v1.4.21 \
    --with github.com/greenpau/caddy-auth-jwt@v1.3.15 \
    --output /caddy

FROM nikolaik/python-nodejs:python3.8-nodejs16
RUN npm install -g pm2@latest
COPY --from=builder /caddy /usr/bin/caddy

WORKDIR /app
COPY . /app
RUN pip install --no-cache-dir -r /app/requirements.txt
EXPOSE 5001
ENV PORT=5000

# Run Flask server in the backend using pm2
# Run Caddy in the forefront
CMD ["./run_server.sh"]

# docker build -t eit:1 .
# docker run -ti --rm --entrypoint sh eit:1 -c bash
# docker run -p 5001:5001 eit:1