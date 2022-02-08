FROM ubuntu:focal-20220105 as builder
ARG UBOOT_VERSION=2022.01
ARG CUSTOM=0
ARG MAKE_JOBS=10

RUN apt-get -y update && apt-get install -y \
    build-essential \
    gcc-aarch64-linux-gnu \
    git wget bison flex libssl-dev bc python2 python3

RUN cd / \
    && git clone https://github.com/angerman/meson64-tools.git \
    && cd /meson64-tools \
    && make -j ${MAKE_JOBS} PREFIX=/tools/ install \
    && cd / && rm -rf /meson64-tools

RUN mkdir -p /build /build/artifacts /build/sources /build/out

RUN cd /build/sources \
    && wget https://ftp.denx.de/pub/u-boot/u-boot-${UBOOT_VERSION}.tar.bz2

COPY assets/ /build/assets/
RUN cd /build \
    && tar xvf sources/u-boot-${UBOOT_VERSION}.tar.bz2 \
    && mv u-boot-${UBOOT_VERSION} u-boot \
    && cd u-boot \
    && cp /build/assets/*_defconfig configs/ \
    && DEFCFG=x88_pro_mini_defconfig \
    && if [ "x${CUSTOM}" = "x1" ];then\
         DEFCFG=x88_pro_mini_custom_defconfig; \
         patch -p1 < /build/assets/custom.patch; \
       fi \
    && make ${DEFCFG} \
    && make -j ${MAKE_JOBS} CROSS_COMPILE=aarch64-linux-gnu- \
    && cp /build/u-boot/u-boot-dtb.bin /build/artifacts/ \
    && cp /build/u-boot/u-boot.bin /build/artifacts/ \
    && cd / && rm -rf /build/u-boot 

RUN cd /build \
    && git clone https://github.com/LibreELEC/amlogic-boot-fip.git \
    && rm amlogic-boot-fip/khadas-vim3l/acs.bin \
    && cp -r amlogic-boot-fip/khadas-vim3l/* artifacts/ \
    && cp /build/assets/acs-x96-air-2-16.bin.gz /build/artifacts/acs.bin.gz \ 
    && gunzip /build/artifacts/acs.bin.gz \
    && cd / && rm -rf /build/amlogic-boot-fip

RUN cd /build/artifacts \
    && /tools/pkg --type bl30 --output bl30.pkg bl30.bin bl301.bin \
    && /tools/pkg --type bl2 --output bl2.pkg bl2.bin acs.bin \
    && /tools/bl30sig --input bl30.pkg --output bl30.30sig \
    && /tools/bl3sig --input bl30.30sig --output bl30.3sig \
    && /tools/bl3sig --input bl31.img --output bl31.3sig \
    && /tools/bl2sig --input bl2.pkg --output bl2.2sig \
    && /tools/bl3sig --input u-boot-dtb.bin --output bl33.3sig \
    && /tools/bootmk \
      --output /build/out/u-boot.bin.sd.bin \
      --bl2 bl2.2sig \
      --bl30 bl30.3sig \
      --bl31 bl31.3sig \
      --bl33 bl33.3sig \
      --ddrfw1 ddr4_1d.fw \
      --ddrfw2 ddr4_2d.fw \
      --ddrfw3 ddr3_1d.fw \
      --ddrfw4 piei.fw \
      --ddrfw5 lpddr4_1d.fw \
      --ddrfw6 lpddr4_2d.fw \
      --ddrfw7 diag_lpddr4.fw \
      --ddrfw8 lpddr3_1d.fw \
      --ddrfw9 aml_ddr.fw

FROM scratch
COPY --from=builder /build/out/ /

