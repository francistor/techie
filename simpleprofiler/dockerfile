# syntax=docker/dockerfile:1

FROM golang:1.18-alpine AS build

WORKDIR /simpleprofiler

# Copy dependencies...
COPY go.mod ./
COPY go.sum ./
RUN go mod download

COPY cert.pem ./
COPY key.pem ./

# ... and our code
COPY *.go ./
# Avoid linking externally to libc which will give a file not found error when executing
RUN CGO_ENABLED=0 go build -o simpleprofiler

## Deploy
FROM gcr.io/distroless/base-debian11
WORKDIR /

COPY --from=build /simpleprofiler/simpleprofiler /simpleprofiler/simpleprofiler 
COPY --from=build /simpleprofiler/*.pem /simpleprofiler/

USER nonroot:nonroot

ENTRYPOINT ["/simpleprofiler/simpleprofiler"]
