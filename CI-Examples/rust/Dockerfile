FROM  nixpkgs/nix-flakes AS nix-build
WORKDIR /usr/src/app
COPY flake.lock flake.nix Cargo.lock Cargo.toml rust-toolchain.toml .
COPY src src
RUN nix build

FROM rust:1.75.0 as rust-build
WORKDIR /usr/src/app
COPY Cargo.lock Cargo.toml .
COPY src src
RUN --mount=type=cache,target=/root/.cargo/registry cargo fetch
COPY Makefile .
RUN cargo build --release


FROM gramineproject/gramine:1.7-jammy AS builder

RUN apt-get update && apt-get install -y \
            build-essential \
            jq \
            libclang-dev \
            libssl-dev \
            pkg-config \
            vim \
        && rm -rf /var/lib/apt/lists/*

WORKDIR /workdir

COPY --from=rust-build \
        /usr/src/app/target/release/rust-hyper-http-server \
        /workdir/cargo/rust-hyper-http-server

COPY --from=nix-build \
        /usr/src/app/result/bin/rust-hyper-http-server \
        /workdir/nix/rust-hyper-http-server

RUN gramine-sgx-gen-private-key

ARG SGX=0
ENV SGX=${SGX}
ARG SELF_EXE=nix/rust-hyper-http-server
ENV SELF_EXE=${SELF_EXE}

COPY Makefile rust-hyper-http-server.manifest.template .
RUN make

HEALTHCHECK --interval=5m --timeout=3s \
  CMD curl -f http://localhost:3000 || exit 1

CMD ["gramine-direct", "rust-hyper-http-server"]
