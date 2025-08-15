# Build stage
FROM rust:1.75-slim as builder

WORKDIR /app

RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

COPY Cargo.toml Cargo.lock ./
COPY build.rs ./
COPY src ./src
COPY migrations ./migrations

RUN cargo build --release

# Runtime stage
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y \
    ca-certificates \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=builder /app/target/release/conclave_api /app/conclave_api
COPY --from=builder /app/migrations ./migrations

ENV PORT=8080
ENV DATABASE_URL=/data/conclave.db

EXPOSE 8080

CMD ["./conclave_api"]