ARG PACMAN_KEYRING=archlinux-keyring


FROM scratch AS archlinux-keyring-tmp
ADD --unpack=true --checksum=sha256:3f7644b971e08b5a77b40b84547626783100b01a966ae083f4e3f45255d0bcce \
  https://gitlab.archlinux.org/archlinux/archlinux-keyring/-/releases/20260206/downloads/archlinux-keyring-20260206.tar.gz /
FROM scratch AS archlinux-keyring
# simulate `--strip-components=1`
COPY --from=archlinux-keyring-tmp /* /


FROM scratch AS archlinuxarm-keyring
ADD --checksum=sha256:6ce771e853f04a38a5b533cb33e61f877b9b06b58b6db051eb8a15d737a2332f \
  https://github.com/archlinuxarm/PKGBUILDs/raw/b23ffc3983abdd3435e910bfd6dcce0f13e4f087/core/archlinuxarm-keyring/archlinuxarm.gpg /
ADD --checksum=sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855 \
  https://github.com/archlinuxarm/PKGBUILDs/raw/b23ffc3983abdd3435e910bfd6dcce0f13e4f087/core/archlinuxarm-keyring/archlinuxarm-revoked /
ADD --checksum=sha256:f2a7250f2a2b77542f82f4219b2bae7895f27b3dcfdf350b497e2be306af776d \
  https://github.com/archlinuxarm/PKGBUILDs/raw/b23ffc3983abdd3435e910bfd6dcce0f13e4f087/core/archlinuxarm-keyring/archlinuxarm-trusted /


# variable cannot be used in `--from`, define a new stage as a workaround
FROM $PACMAN_KEYRING AS keyring


FROM alpine:3.24.0@sha256:a2d49ea686c2adfe3c992e47dc3b5e7fa6e6b5055609400dc2acaeb241c829f4 AS rootfs
RUN apk add --no-cache pacman
COPY --link pacman.conf /
ARG PACMAN_ARCH=auto
ARG PACMAN_CONF_EXTRA
ARG PACMAN_PACKAGES=base
RUN --mount=type=bind,from=keyring,target=/usr/share/pacman/keyrings \
  sed -i 's/^#\?\(Architecture\)\s.*$/\1 = '"$PACMAN_ARCH"'/' pacman.conf && \
  echo -n "$PACMAN_CONF_EXTRA" >> pacman.conf && \
  mkdir -m 0755 \
    /rootfs \
    /rootfs/var \
    /rootfs/var/lib \
    /rootfs/var/lib/pacman \
    /rootfs/var/log && \
  pacman-key --init && \
  pacman-key --populate && \
  pacman \
    -Sy \
    --config=/pacman.conf \
    --root /rootfs \
    --disable-sandbox \
    --noconfirm \
    --noprogressbar \
    --noscriptlet \
    $PACMAN_PACKAGES && \
  sed -i -e 's/^root::/root:!:/' /rootfs/etc/shadow && \
  sed -i 's/^#\(en_US\.UTF-8\)/\1/' /rootfs/etc/locale.gen && \
  chroot /rootfs /usr/bin/locale-gen && \
  rm -rf \
    /rootfs/etc/resolv.conf \
    /rootfs/var/lib/pacman/sync/* \
    /rootfs/var/log/pacman.log


FROM scratch AS archlinux
COPY --from=rootfs /rootfs /
ENV LANG=en_US.UTF-8
CMD ["/usr/bin/bash"]
