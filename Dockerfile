FROM ubuntu:xenial as ipxe

# Update the package repository and install applications
RUN apt-get -qq update
RUN apt-get -yqq install \
	git \
	make \
	build-essential \
	curl \
	genisoimage \
	liblzma-dev \
	binutils-dev \
	zlib1g-dev

# Cleanup package repository and applications
RUN apt-get -yqq clean
RUN rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 git://git.ipxe.org/ipxe.git /ipxe_build

WORKDIR /ipxe_build/src

ENTRYPOINT ["make"]

FROM ipxe as netboot

# Copy iPXE config and overrides
COPY ./ipxe/local/* /ipxe_build/src/config/local/

#
COPY ./src/* /ipxe_build/src/
