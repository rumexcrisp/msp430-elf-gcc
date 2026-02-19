{ pkgs ? import <nixpkgs> {} }:

let
  target = "msp430-elf";

  binutils = pkgs.stdenv.mkDerivation {
    pname = "${target}-binutils";
    version = "2.45";

    src = pkgs.fetchurl {
      url = "https://ftp.gnu.org/gnu/binutils/binutils-2.45.tar.xz";
      sha256 = "c50c0e7f9cb188980e2cc97e4537626b1672441815587f1eab69d2a1bfbef5d2";
    };

    nativeBuildInputs = [
      pkgs.gnumake
      pkgs.bison
      pkgs.flex
      pkgs.texinfo
    ];

    buildInputs = [
      pkgs.zlib
    ];

    configurePhase = ''
      runHook preConfigure

      buildRoot="$NIX_BUILD_TOP/$sourceRoot"
      buildDir="$buildRoot/build"
      mkdir -p "$buildDir"
      cd "$buildDir"
      "$buildRoot"/configure \
        --target=${target} \
        --prefix=$out \
        --disable-nls \
        --program-prefix=${target}- \
        --enable-multilib \
        --disable-werror \
        --with-sysroot=$out/${target} \
        --disable-shared \
        --enable-lto \
        --with-system-zlib \
        --enable-plugins

      runHook postConfigure
    '';

    buildPhase = ''
      runHook preBuild
      buildRoot="$NIX_BUILD_TOP/$sourceRoot"
      buildDir="$buildRoot/build"
      mkdir -p "$buildDir"
      cd "$buildDir"
      make
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      buildRoot="$NIX_BUILD_TOP/$sourceRoot"
      buildDir="$buildRoot/build"
      mkdir -p "$buildDir"
      cd "$buildDir"
      make install

      rm -f "$out"/bin/{ar,as,ld,nm,objdump,ranlib,strip,objcopy}
      rm -f "$out"/lib/libiberty.a
      rm -rf "$out"/share/info

      runHook postInstall
    '';

    doCheck = false;
    enableParallelBuilding = true;
  };

  gccStage1 = pkgs.stdenv.mkDerivation {
    pname = "${target}-gcc-stage1";
    version = "15.2.0";

    src = pkgs.fetchurl {
      url = "https://gcc.gnu.org/pub/gcc/releases/gcc-15.2.0/gcc-15.2.0.tar.xz";
      sha256 = "438fd996826b0c82485a29da03a72d71d6e3541a83ec702df4271f6fe025d24e";
    };

    nativeBuildInputs = [
      pkgs.gnumake
      pkgs.bison
      pkgs.flex
      pkgs.perl
      pkgs.python3
      pkgs.texinfo
    ];

    buildInputs = [
      binutils
      pkgs.gmp
      pkgs.mpfr
      pkgs.libmpc
      pkgs.isl
      pkgs.zlib
      pkgs.elfutils
    ];

    configurePhase = ''
      runHook preConfigure

      export CFLAGS="-O2 -pipe -Wno-error=format-security"
      export CXXFLAGS="-O2 -pipe -Wno-error=format-security"
      export CFLAGS_FOR_TARGET="-Os -pipe"
      export CXXFLAGS_FOR_TARGET="-Os -pipe"

      buildRoot="$NIX_BUILD_TOP/$sourceRoot"
      buildDir="$buildRoot/build"
      mkdir -p "$buildDir"
      cd "$buildDir"

      "$buildRoot"/configure \
        --prefix=$out \
        --program-prefix=${target}- \
        --target=${target} \
        --enable-shared \
        --disable-nls \
        --disable-threads \
        --enable-languages=c \
        --enable-multilib \
        --disable-werror \
        --with-system-zlib \
        --with-isl \
        --with-local-prefix=$out/${target} \
        --with-sysroot=$out/${target} \
        --with-as=${binutils}/bin/${target}-as \
        --with-ld=${binutils}/bin/${target}-ld \
        --disable-libgomp \
        --disable-libssp \
        --enable-interwork \
        --enable-lto \
        --disable-fixincludes \
        --without-headers

      runHook postConfigure
    '';

    buildPhase = ''
      runHook preBuild
      buildRoot="$NIX_BUILD_TOP/$sourceRoot"
      buildDir="$buildRoot/build"
      mkdir -p "$buildDir"
      cd "$buildDir"
      make all-gcc
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      buildRoot="$NIX_BUILD_TOP/$sourceRoot"
      buildDir="$buildRoot/build"
      mkdir -p "$buildDir"
      cd "$buildDir"
      make install-gcc

      rm -rf "$out"/share/info
      rm -rf "$out"/share/man/man7

      if [ -d "$out/libexec" ]; then
        mkdir -p "$out/lib"
        cp -r "$out"/libexec/* "$out"/lib/
        rm -rf "$out"/libexec
      fi

      runHook postInstall
    '';

    doCheck = false;
    enableParallelBuilding = true;
  };

  newlib = pkgs.stdenv.mkDerivation {
    pname = "${target}-newlib";
    version = "4.5.0.20241231";

    src = pkgs.fetchurl {
      url = "ftp://sourceware.org/pub/newlib/newlib-4.5.0.20241231.tar.gz";
      sha256 = "33f12605e0054965996c25c1382b3e463b0af91799001f5bb8c0630f2ec8c852";
    };

    nativeBuildInputs = [
      pkgs.gnumake
      gccStage1
      binutils
    ];

    configurePhase = ''
      runHook preConfigure

      export CFLAGS_FOR_TARGET="-Os -g -ffunction-sections -fdata-sections"

      buildRoot="$NIX_BUILD_TOP/$sourceRoot"
      buildDir="$buildRoot/build"
      mkdir -p "$buildDir"
      cd "$buildDir"

      "$buildRoot"/configure \
        --prefix=$out \
        --target=${target} \
        --disable-newlib-supplied-syscalls \
        --enable-newlib-reent-small \
        --disable-newlib-fseek-optimization \
        --disable-newlib-wide-orient \
        --enable-newlib-nano-formatted-io \
        --disable-newlib-io-float \
        --enable-newlib-nano-malloc \
        --disable-newlib-unbuf-stream-opt \
        --enable-lite-exit \
        --enable-newlib-global-atexit \
        --disable-nls

      runHook postConfigure
    '';

    buildPhase = ''
      runHook preBuild
      buildRoot="$NIX_BUILD_TOP/$sourceRoot"
      buildDir="$buildRoot/build"
      mkdir -p "$buildDir"
      cd "$buildDir"
      make -j1
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      buildRoot="$NIX_BUILD_TOP/$sourceRoot"
      buildDir="$buildRoot/build"
      mkdir -p "$buildDir"
      cd "$buildDir"
      make install

      rm -rf "$out"/share

      install -d -m755 "$out/${target}/usr"
      ln -s ../lib "$out/${target}/usr/lib"
      ln -s ../include "$out/${target}/usr/include"

      runHook postInstall
    '';

    doCheck = false;
    enableParallelBuilding = false;
  };

  gcc = pkgs.stdenv.mkDerivation {
    pname = "${target}-gcc";
    version = "15.2.0";

    src = pkgs.fetchurl {
      url = "https://gcc.gnu.org/pub/gcc/releases/gcc-15.2.0/gcc-15.2.0.tar.xz";
      sha256 = "438fd996826b0c82485a29da03a72d71d6e3541a83ec702df4271f6fe025d24e";
    };

    nativeBuildInputs = [
      pkgs.gnumake
      pkgs.bison
      pkgs.flex
      pkgs.perl
      pkgs.python3
      pkgs.texinfo
    ];

    buildInputs = [
      binutils
      newlib
      pkgs.gmp
      pkgs.mpfr
      pkgs.libmpc
      pkgs.isl
      pkgs.zlib
      pkgs.elfutils
    ];

    configurePhase = ''
      runHook preConfigure

      export CFLAGS="-O2 -pipe -Wno-error=format-security"
      export CXXFLAGS="-O2 -pipe -Wno-error=format-security"
      export CFLAGS_FOR_TARGET="-Os -pipe"
      export CXXFLAGS_FOR_TARGET="-Os -pipe"

      buildRoot="$NIX_BUILD_TOP/$sourceRoot"
      buildDir="$buildRoot/build"
      mkdir -p "$buildDir"
      cd "$buildDir"

      "$buildRoot"/configure \
        --prefix=$out \
        --program-prefix=${target}- \
        --target=${target} \
        --enable-shared \
        --disable-nls \
        --disable-threads \
        --enable-languages=c,c++ \
        --enable-multilib \
        --disable-werror \
        --with-system-zlib \
        --with-isl \
        --with-local-prefix=${newlib}/${target} \
        --with-sysroot=${newlib}/${target} \
        --with-as=${binutils}/bin/${target}-as \
        --with-ld=${binutils}/bin/${target}-ld \
        --disable-libgomp \
        --disable-libssp \
        --enable-interwork \
        --enable-addons \
        --enable-lto

      runHook postConfigure
    '';

    buildPhase = ''
      runHook preBuild
      buildRoot="$NIX_BUILD_TOP/$sourceRoot"
      buildDir="$buildRoot/build"
      mkdir -p "$buildDir"
      cd "$buildDir"
      make all-gcc all-target-libgcc
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      buildRoot="$NIX_BUILD_TOP/$sourceRoot"
      buildDir="$buildRoot/build"
      mkdir -p "$buildDir"
      cd "$buildDir"
      make install-gcc install-target-libgcc

      rm -rf "$out"/share/info
      rm -rf "$out"/share/man/man7

      if [ -d "$out/libexec" ]; then
        mkdir -p "$out/lib"
        cp -r "$out"/libexec/* "$out"/lib/
        rm -rf "$out"/libexec
      fi

      runHook postInstall
    '';

    doCheck = false;
    enableParallelBuilding = true;
  };

  libstdcxx = pkgs.stdenv.mkDerivation {
    pname = "${target}-libstdc++";
    version = "12.2.0";

    src = pkgs.fetchurl {
      url = "https://ftpmirror.gnu.org/gcc/gcc-12.2.0/gcc-12.2.0.tar.xz";
      sha256 = "e549cf9cf3594a00e27b6589d4322d70e0720cdd213f39beb4181e06926230ff";
    };

    nativeBuildInputs = [
      pkgs.gnumake
      pkgs.bison
      pkgs.flex
      pkgs.perl
      pkgs.python3
      pkgs.texinfo
    ];

    buildInputs = [
      binutils
      newlib
      pkgs.gmp
      pkgs.mpfr
      pkgs.libmpc
      pkgs.zlib
      pkgs.elfutils
    ];

    configurePhase = ''
      runHook preConfigure

      export CFLAGS="-O2 -pipe -Wno-error=format-security"
      export CXXFLAGS="-O2 -pipe -Wno-error=format-security"
      export CFLAGS_FOR_TARGET="-Os -pipe"
      export CXXFLAGS_FOR_TARGET="-Os -pipe"

      buildRoot="$NIX_BUILD_TOP/$sourceRoot"
      buildDir="$buildRoot/build"
      mkdir -p "$buildDir"
      cd "$buildDir"

      "$buildRoot"/configure \
        --prefix=$out \
        --program-prefix=${target}- \
        --target=${target} \
        --disable-shared \
        --disable-nls \
        --disable-threads \
        --enable-languages=c++ \
        --enable-multilib \
        --disable-werror \
        --with-newlib \
        --with-local-prefix=${newlib}/${target} \
        --with-sysroot=${newlib}/${target} \
        --with-as=${binutils}/bin/${target}-as \
        --with-ld=${binutils}/bin/${target}-ld \
        --enable-interwork \
        --disable-namespaces \
        --disable-libgcc-rebuild

      runHook postConfigure
    '';

    buildPhase = ''
      runHook preBuild
      buildRoot="$NIX_BUILD_TOP/$sourceRoot"
      buildDir="$buildRoot/build"
      mkdir -p "$buildDir"
      cd "$buildDir"
      make all-target-libstdc++-v3
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      buildRoot="$NIX_BUILD_TOP/$sourceRoot"
      buildDir="$buildRoot/build"
      mkdir -p "$buildDir"
      cd "$buildDir"
      make install-target-libstdc++-v3

      rm -rf "$out"/share
      rm -rf "$out"/lib

      runHook postInstall
    '';

    doCheck = false;
    enableParallelBuilding = true;
  };

  tarball = pkgs.stdenv.mkDerivation {
    pname = "${target}-gcc-tarball";
    version = "15.2.0";
    
    src = null;
    phases = ["installPhase"];
    
    nativeBuildInputs = [pkgs.gnutar pkgs.gzip];
    
    installPhase = ''
      mkdir -p $out
      
      # Create toolchain directory
      mkdir -p toolchain/${target}
      
      # Copy all components
      cp -r ${binutils}/* toolchain/${target}/
      cp -r ${gcc}/* toolchain/${target}/
      cp -r ${libstdcxx}/* toolchain/${target}/
      
      # Create tarball
      tar czf $out/msp430-elf-gcc-15.2.0-ubuntu.tar.gz toolchain/
    '';
  };

in {
  inherit target binutils gccStage1 newlib gcc libstdcxx tarball;
}
