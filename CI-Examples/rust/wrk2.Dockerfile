FROM ubuntu:jammy as wrk2

RUN apt-get update && apt-get install -y \
            git \
            build-essential \
            libssl-dev \
            libz-dev \
            iputils-ping \
        && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src

RUN git clone https://github.com/giltene/wrk2.git
WORKDIR /usr/src/wrk2
RUN make
RUN cp wrk /usr/local/bin

FROM scratch as output
COPY --from=wrk2 /usr/local/bin/wrk .
