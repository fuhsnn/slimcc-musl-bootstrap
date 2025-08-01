### Building
 - Install Bash, GNU make, GNU binutils, and POSIX.1-2008 cc + libc
 - cd to a clean directory, put [slimcc source](https://github.com/fuhsnn/slimcc) in `./slimcc`
 - Run the script, a rootfs will be created, (default name is `./rfs`)
 - `chroot` with your favorite method (I use `systemd-nspawn -D`)
 - Optionally, repeat inside the chroot as stage2 bootstrap

### TL'DR of the bootstrap script
 - build slimcc
 - build musl with the just-built slimcc
 - build the rest of binaries statically linked to the just-built musl, with the just-built slimcc

### What's included?

```
slimcc
musl
toybox
GNU bash
GNU binutils
GNU make
GNU wget
OpenBSD mg
OpenBSD oksh
OpenBSD libtls (for wget https support)
```

The tools chosen may not be as "minimal" as one expected, however it is the minimum requirement to compile `musl` (needs gmake) and `toybox` (needs bash) without rewriting their build process. As I do this from the perspective of a compiler maintainer, modifying projects to fit minimalism does not interest me as much as improving slimcc to be able to compile their dependencies.

`mg` and `oksh` are the text editor and interactive shell of choice. `toybox vi` is also enabled in case anyone prefer it.

### Inspirations
 - https://github.com/oasislinux/oasis
 - https://github.com/JonathanWilbur/punchcardos
 - https://github.com/glaucuslinux/glaucus
