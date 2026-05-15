# Stage 1: Build the controller binary
FROM golang:1.23-alpine AS builder

WORKDIR /workspace

# Cache dependencies first
COPY go.mod go.sum ./
RUN go mod download

# Copy source
COPY main.go main.go
COPY api/ api/
COPY internal/ internal/

# Build a static binary (CGO disabled for scratch/distroless base)
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -a -ldflags '-extldflags "-static"' -o manager main.go

# Stage 2: Minimal runtime image
FROM gcr.io/distroless/static:nonroot
WORKDIR /
COPY --from=builder /workspace/manager .
USER 65532:65532
ENTRYPOINT ["/manager"]
