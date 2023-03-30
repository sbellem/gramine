FROM alpine/git as sgx-driver

RUN git clone \
            --branch sgx_diver_2.14 \
            https://github.com/intel/linux-sgx-driver.git \
            /opt/intel/linux-sgx-driver

FROM python:3.10

RUN apt-get update && apt-get install --yes \
            autoconf \
            bison \
            build-essential \
            gawk \
            git \
            libcurl4-openssl-dev \
            libprotobuf-c-dev \
            libunwind-dev \
            nasm \
            #ninja-build \
            pkg-config \
            protobuf-compiler \
            protobuf-c-compiler \
            vim \
            wget \
            libunwind8 \
            musl-tools \
        && rm -rf /var/lib/apt/lists/*

# to build the patched libgomp library
RUN apt-get update && apt-get install --yes \
            libgmp-dev \
            libmpfr-dev \
            libmpc-dev \
            libisl-dev \
        && rm -rf /var/lib/apt/lists/*

RUN python -m pip install \
            click \
            cryptography \
            jinja2 \
            meson \
            ninja \
            protobuf \
            pyelftools \
            pytest \
            toml \
            tomli \
            tomli-w

ARG branch=master
ARG remote=sbellem
RUN git clone \
            --branch ${branch} \
            https://github.com/${remote}/gramine.git \
            /usr/src/gramine

WORKDIR /usr/src/gramine

# https://gramine.readthedocs.io/en/stable/devel/building.html#install-the-intel-sgx-driver
COPY --from=sgx-driver /opt/intel/linux-sgx-driver /opt/intel/linux-sgx-driver
# NOTE that this is an inadvisable configuration for production systems.
# RUN sysctl vm.mmap_min_addr=0

ARG buildtype=release
ARG direct=enabled
ARG sgx=enabled
ARG sgx_driver=oot
RUN meson setup build/ \
            --buildtype=${buildtype} \
            -Ddirect=${direct} \
            -Dsgx=${sgx} \
            -Dsgx_driver=${sgx_driver} \
            -Dsgx_driver_include_path=/opt/intel/linux-sgx-driver

RUN ninja -C build/
RUN ninja -C build/ install

#RUN gramine-sgx-gen-private-key
RUN mkdir -p ${HOME}/.config/gramine \
        && openssl genrsa -3 -out ${HOME}/.config/gramine/enclave-key.pem 3072

# for the helloworld example
#WORKDIR /usr/src/gramine/LibOS/shim/test/regression
#RUN make SGX=1
#RUN make SGX=1 sgx-tokens

WORKDIR /usr/src/gramine

# workaround
ENV PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION=python
