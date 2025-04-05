FROM golang:alpine AS builder
WORKDIR /app
COPY go.mod go.sum /app/
RUN go mod download
COPY . .
RUN go build -o /wireguard-go .

FROM alpine AS image
RUN apk add --no-cache iptables ip6tables wireguard-tools
COPY --from=builder /wireguard-go /usr/local/bin/wireguard-go
