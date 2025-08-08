FROM golang:1.22 AS builder

WORKDIR /src

# Mod dosyalarını kopyala ve bağımlılıkları indir
COPY go.mod ./
RUN --mount=type=cache,target=/go/pkg/mod go mod download

# Kaynak kodu kopyala ve derle
COPY . .
# Ensure go.sum is generated from imports
RUN --mount=type=cache,target=/go/pkg/mod go mod tidy
RUN --mount=type=cache,target=/go/pkg/mod \
    CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath -ldflags "-s -w" -o /out/api ./main.go

# Minimal runtime image
FROM gcr.io/distroless/static:nonroot

WORKDIR /
COPY --from=builder /out/api /api

EXPOSE 8000
USER nonroot:nonroot
ENTRYPOINT ["/api"]