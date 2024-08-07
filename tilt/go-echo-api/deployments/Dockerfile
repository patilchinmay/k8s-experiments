#################### BUILD ###############################

FROM golang:1.22-alpine AS build

LABEL maintainer="patilchinmay01@gmail.com"

WORKDIR /build

# Retrieve application dependencies.
# This allows the container build to reuse cached dependencies.
# Expecting to copy go.mod and if present go.sum.
COPY go.* /build/

# https://github.com/GoogleCloudPlatform/golang-samples/blob/692f934095411b2cc5d4a8ab0c8cc804034c31f6/run/helloworld/Dockerfile#L30
RUN go mod download

COPY . /build/

RUN CGO_ENABLED=0 GOOS=linux go build -o go-echo-api github.com/patilchinmay/k8s-experiments/tilt/go-echo-api

#################### RUN ###############################

FROM gcr.io/distroless/static-debian11:nonroot AS run

LABEL maintainer="patilchinmay01@gmail.com"

USER nonroot:nonroot

WORKDIR /app

COPY --from=build --chown=nonroot:nonroot /build/go-echo-api /app/

CMD ["/app/go-echo-api"]
