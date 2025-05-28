set -e -u

STAGE1CC=$PWD/slimcc/slimcc
ROOTFS=$PWD/rfs

get_src() {
 wget "$1" -O "$2".tar.gz
 mkdir "$2"
 tar -xf "$2".tar.gz --strip-components=1 -C "$2"
 rm "$2".tar.gz
}

fix_configure() {
 find . -name 'configure' -exec sed -i 's/^\s*lt_prog_compiler_wl=$/lt_prog_compiler_wl=-Wl,/g' {} +
 find . -name 'configure' -exec sed -i 's/^\s*lt_prog_compiler_pic=$/lt_prog_compiler_pic=-fPIC/g' {} +
 find . -name 'configure' -exec sed -i 's/^\s*lt_prog_compiler_static=$/lt_prog_compiler_static=-static/g' {} +
}

configure_gnu_static() {
 fix_configure
 CC="$STAGE1CC" sh ./configure LDFLAGS=--static --build=x86_64-linux-musl --disable-nls $@
}

build_bootstrap_cc() {
(
 cd slimcc
 mkdir -p "$ROOTFS"/lib/slimcc/
 cp -r ./slimcc_headers/include "$ROOTFS"/lib/slimcc/
 sed 's|ROOT_DIR|'\"$ROOTFS\"'|g' platform/linux-musl-bootstrap.c > platform.c
 STAGE1_BUILD_CMD=make
 $STAGE1_BUILD_CMD
)
}

build_cc() {
(
 cd slimcc
 sed 's|ROOT_DIR|'\"\"'|g' platform/linux-musl-bootstrap.c > platform.c
 mkdir -p "$ROOTFS"/bin
 "$STAGE1CC" *.c -static -o "$ROOTFS"/bin/cc
)
}

build_musl() {
get_src https://github.com/bminor/musl/archive/refs/tags/v1.2.5.tar.gz musl_src
(
 cd musl_src
 rm -r src/complex/ include/complex.h
 CC="$STAGE1CC" AR=ar RANLIB=ranlib sh ./configure --target=x86_64-linux-musl --prefix="$ROOTFS" --includedir="$ROOTFS"/usr/include --syslibdir=/dev/null
 make
 make install
)
}

build_linux_headers() {
get_src https://github.com/sabotage-linux/kernel-headers/archive/refs/tags/v4.19.88-2.tar.gz kernel_hdr_src
(
 cd kernel_hdr_src
 make ARCH=x86_64 prefix= DESTDIR="$ROOTFS"/usr install
)
}

build_binutils() {
get_src https://ftpmirror.gnu.org/gnu/binutils/binutils-2.44.tar.gz binutils_src
(
 cd binutils_src
 configure_gnu_static --without-mmap --without-zstd --prefix="$ROOTFS" --includedir="$ROOTFS"/usr/include
 make
 make install
)
}

build_bash() {
get_src https://ftpmirror.gnu.org/gnu/bash/bash-5.3-rc1.tar.gz bash_src
(
 cd bash_src
 configure_gnu_static --enable-static-link --disable-readline --without-bash-malloc
 make
 cp ./bash "$ROOTFS"/bin/
)
}

build_gmake() {
get_src https://ftpmirror.gnu.org/gnu/make/make-4.4.1.tar.gz gmake_src
(
 cd gmake_src
 configure_gnu_static MAKEINFO=true --prefix="$ROOTFS"
 make install
)
}

build_mg() {
# a mirror was used to workaround toybox wget not working with github releases
get_src https://www.mirrorservice.org/sites/download.salixos.org/x86_64/extra-15.0/source/development/mg-troglobit/mg-3.5.tar.gz mg_src
(
 cd mg_src
 configure_gnu_static --without-curses
 make
 cp ./src/mg "$ROOTFS"/bin/
)
}

build_oksh() {
get_src https://github.com/ibara/oksh/archive/refs/tags/oksh-7.7.tar.gz oksh_src
(
 cd oksh_src
 sh ./configure --cc="$STAGE1CC" --enable-static --prefix="$ROOTFS"
 make
 cp ./oksh "$ROOTFS"/bin/sh
)
}

build_toybox() {
get_src https://ftp.openbsd.org/pub/OpenBSD/LibreSSL/libressl-4.1.0.tar.gz libtls_src
(
 cd libtls_src
 sed -i 's|#if defined(__GNUC__)|#if 1|g' crypto/bn/arch/amd64/bn_arch.h
 configure_gnu_static --with-openssldir=/etc/ssl --enable-libtls-only --disable-shared
 make
 mkdir -p "$ROOTFS"/etc/ssl
 cp ./cert.pem "$ROOTFS"/etc/ssl/
 cp ./openssl.cnf "$ROOTFS"/etc/ssl/
 cp ./x509v3.cnf "$ROOTFS"/etc/ssl/
)
get_src https://github.com/landley/toybox/archive/refs/tags/0.8.12.tar.gz toybox_src
(
 cd toybox_src
 sed -i 's/^#define QUIET$/#define QUIET = 0/g' lib/portability.h
 sed -i 's/^  default n$/  default y/g' toys/net/wget.c
 sed -i 's/^  default n$/  default y/g' toys/pending/awk.c
 sed -i 's/^  default n$/  default y/g' toys/pending/expr.c
 sed -i 's/^  default n$/  default y/g' toys/pending/diff.c
 sed -i 's/^  default n$/  default y/g' toys/pending/tr.c
 sed -i 's/^  default n$/  default y/g' toys/pending/vi.c
 sed -i 's/^  default y$/  default n/g' toys/other/readelf.c
 sed -i 's/^  default y$/  default n/g' toys/posix/strings.c
 sed -i '111s/.*/\tdefault n/' Config.in # disable TOYBOX_ZHELP

 make CC="$STAGE1CC" HOSTCC="$STAGE1CC" CFLAGS='-I'"$PWD"'/../libtls_src/include' LDFLAGS='--static '"$PWD"'/../libtls_src/tls/.libs/libtls.a' defconfig toybox
 make CC="$STAGE1CC" HOSTCC="$STAGE1CC" PREFIX="$ROOTFS"/bin install_flat
)
}

build_bootstrap_cc
build_musl
build_linux_headers
build_cc
build_binutils
build_bash
build_gmake
build_mg
build_oksh
build_toybox
