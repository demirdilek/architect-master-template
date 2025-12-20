# STAGE 1: Build the binary
# We use the official Golang image as a builder
FROM golang:1.24-alpine AS builder

# Set the working directory inside the container
WORKDIR /app

# Copy the module files and download dependencies
COPY go.mod ./
# Note: If you have a go.sum, uncomment the line below
# COPY go.sum ./
RUN go mod download

# Copy the source code
COPY . .

# Compile the application into a static binary called 'probe-agent'
RUN go build -o probe-agent ./cmd/probe/main.go

# STAGE 2: Create the production image
# We use a tiny Alpine Linux image for the final container
FROM alpine:latest

# Add CA certificates (essential for making HTTPS pings)
RUN apk --no-cache add ca-certificates

WORKDIR /root/

# Copy only the compiled binary from the builder stage
COPY --from=builder /app/probe-agent .

# Inform Docker that the container listens on port 8080
EXPOSE 8080

# Run the application
CMD ["./probe-agent"]
