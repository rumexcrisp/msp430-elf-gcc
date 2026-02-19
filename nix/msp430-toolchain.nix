{ pkgs ? import <nixpkgs> {}
, disableBootstrap ? true  # Set to false for full 3-stage bootstrap (slower but more verification)
}:

let
  target = "msp430-elf";

  # Static overrides for host-side dependencies.
  # Statically linking these into GCC/binutils eliminates the need to bundle
  # shared libraries and patch RPATH, making the tarball fully portable.
  staticGmp = pkgs.gmp.override { withStatic = true; };
  staticMpfr = (pkgs.mpfr.override { gmp = staticGmp; }).overrideAttrs (old: {
    dontDisableStatic = true;
    configureFlags = (old.configureFlags or []) ++ [ "--enable-static" "--disable-shared" ];
  });
  staticLibmpc = (pkgs.libmpc.override { gmp = staticGmp; mpfr = staticMpfr; }).overrideAttrs (old: {
    dontDisableStatic = true;
    configureFlags = (old.configureFlags or []) ++ [ "--enable-static" "--disable-shared" ];
  });
  staticIsl = (pkgs.isl.override { gmp = staticGmp; }).overrideAttrs (old: {
    dontDisableStatic = true;
    configureFlags = (old.configureFlags or []) ++ [ "--enable-static" "--disable-shared" ];
  });
  staticZlib = pkgs.zlib.override { shared = false; };

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
      staticZlib
    ];

    configurePhase = ''
      runHook preConfigure

      export LDFLAGS="-static-libgcc -static-libstdc++"

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
        --enable-plugins \
        --disable-gdb

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

    # gccStage1 is only a build dependency — its output never ends up in the
    # tarball.  Keeping --with-as/--with-ld and binutils in buildInputs is safe
    # because the embedded Nix store paths only live in this intermediate
    # derivation, not in the portable tarball.
    buildInputs = [
      binutils
      staticGmp
      staticMpfr
      staticLibmpc
      staticIsl
      staticZlib
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
        --with-gmp=${staticGmp} \
        --with-mpfr=${staticMpfr} \
        --with-mpc=${staticLibmpc} \
        --with-isl=${staticIsl} \
        --with-local-prefix=$out/${target} \
        --with-sysroot=$out/${target} \
        --with-as=${binutils}/bin/${target}-as \
        --with-ld=${binutils}/bin/${target}-ld \
        --disable-libgomp \
        --disable-libssp \
        --enable-interwork \
        --enable-lto \
        --disable-fixincludes \
        --without-headers \
        ${pkgs.lib.optionalString disableBootstrap "--disable-bootstrap"} \
        --disable-libsanitizer

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
      pkgs.texinfo
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
        --disable-nls \
        --disable-doc

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

      rm -rf "$out"/share

      install -d -m755 "$out/${target}/usr"
      ln -s ../lib "$out/${target}/usr/lib"
      ln -s ../include "$out/${target}/usr/include"

      runHook postInstall
    '';

    doCheck = false;
    enableParallelBuilding = true;
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
      binutils  # build tool, not a link-time dep
    ];

    buildInputs = [
      newlib
      staticGmp
      staticMpfr
      staticLibmpc
      staticIsl
      staticZlib
      pkgs.elfutils
    ];

    configurePhase = ''
      runHook preConfigure

      export CFLAGS="-O2 -pipe -Wno-error=format-security"
      export CXXFLAGS="-O2 -pipe -Wno-error=format-security"
      export CFLAGS_FOR_TARGET="-Os -pipe"
      export CXXFLAGS_FOR_TARGET="-Os -pipe"
      export LDFLAGS="-static-libgcc -static-libstdc++"

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
        --enable-languages=c,c++ \
        --enable-multilib \
        --disable-werror \
        --with-system-zlib \
        --with-gmp=${staticGmp} \
        --with-mpfr=${staticMpfr} \
        --with-mpc=${staticLibmpc} \
        --with-isl=${staticIsl} \
        --with-local-prefix=$out/${target} \
        --with-sysroot=$out/${target} \
        --with-build-sysroot=${newlib}/${target} \
        --with-build-time-tools=${binutils}/${target}/bin \
        --with-native-system-header-dir=/include \
        --disable-libgomp \
        --disable-libssp \
        --enable-interwork \
        --enable-addons \
        --enable-lto \
        ${pkgs.lib.optionalString disableBootstrap "--disable-bootstrap"} \
        --disable-libsanitizer

      runHook postConfigure
    '';

    buildPhase = ''
      runHook preBuild
      buildRoot="$NIX_BUILD_TOP/$sourceRoot"
      buildDir="$buildRoot/build"
      mkdir -p "$buildDir"
      cd "$buildDir"
      make all-gcc all-target-libgcc
      
      # Configure libstdc++ to generate headers (but don't build the library to avoid link tests)
      echo "Configuring libstdc++ to generate headers..."
      make configure-target-libstdc++-v3 || true
      
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      buildRoot="$NIX_BUILD_TOP/$sourceRoot"
      buildDir="$buildRoot/build"
      mkdir -p "$buildDir"
      cd "$buildDir"
      make install-gcc install-target-libgcc

      # Install libstdc++ headers (configured but not built to avoid link test failures)
      echo "Installing libstdc++ headers..."
      
      # Try to install just the headers from the configured libstdc++
      if [ -d "$buildDir/${target}/libstdc++-v3" ]; then
        cd "$buildDir/${target}/libstdc++-v3"
        make install-headers DESTDIR="" || echo "Warning: Some headers may not have been installed"
        cd "$buildDir"
      fi

      rm -rf "$out"/share/info
      rm -rf "$out"/share/man/man7

      runHook postInstall
    '';

    doCheck = false;
    enableParallelBuilding = true;
  };

  libstdcxx = pkgs.stdenv.mkDerivation {
    pname = "${target}-libstdc++-headers";
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
      gcc
    ];

    # libstdcxx only produces headers — no binaries end up in the tarball.
    # Keeping binutils + --with-as/--with-ld is safe here (same as gccStage1).
    buildInputs = [
      binutils
      newlib
      staticGmp
      staticMpfr
      staticLibmpc
      staticIsl
      staticZlib
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
        --with-system-zlib \
        --with-gmp=${staticGmp} \
        --with-mpfr=${staticMpfr} \
        --with-mpc=${staticLibmpc} \
        --with-isl=${staticIsl} \
        --with-local-prefix=${newlib}/${target} \
        --with-sysroot=${newlib}/${target} \
        --with-native-system-header-dir=/include \
        --with-as=${binutils}/bin/${target}-as \
        --with-ld=${binutils}/bin/${target}-ld \
        --enable-interwork \
        --disable-libgomp \
        --disable-libssp \
        ${pkgs.lib.optionalString disableBootstrap "--disable-bootstrap"} \
        --disable-libsanitizer

      runHook postConfigure
    '';

    buildPhase = ''
      runHook preBuild
      buildRoot="$NIX_BUILD_TOP/$sourceRoot"
      buildDir="$buildRoot/build"
      mkdir -p "$buildDir"
      cd "$buildDir"

      # Only configure libstdc++ (generates headers like bits/c++config.h)
      # Do NOT build the full library — GCC 15.2.0 has an ICE in the MSP430
      # backend when compiling C++17 filesystem code (fs_path.lo).
      # For embedded use with -fno-exceptions -fno-rtti, only headers are needed.
      #
      # configure-target-libstdc++-v3 only handles the default multilib.
      # We must also configure sub-multilibs (430, no-exceptions, etc.) so
      # that target-specific generated headers (bits/c++config.h) are created
      # for every multilib variant GCC might select.
      make configure-target-libstdc++-v3

      # Configure multilib variants so their headers are generated.
      # GCC places multilib build dirs under $buildDir/${target}/<multilib>/
      for mdir in "$buildDir"/${target}/*/libstdc++-v3 "$buildDir"/${target}/*/*/libstdc++-v3; do
        if [ -d "$mdir" ] && [ -f "$mdir/Makefile" ]; then
          echo "Configuring multilib libstdc++ headers in: $mdir"
          cd "$mdir"
          make configure-host || echo "Warning: configure-host failed in $mdir"
          cd "$buildDir"
        fi
      done

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      buildRoot="$NIX_BUILD_TOP/$sourceRoot"
      buildDir="$buildRoot/build"
      cd "$buildDir"

      # Install headers from the include subdirectory (that's where the install-headers target lives)
      cd "$buildDir/${target}/libstdc++-v3/include"
      make install

      # Also install generated headers from multilib variants
      # Use both single-level and two-level globs to catch nested multilibs
      # like 430/no-exceptions, large/no-exceptions, etc.
      for dir in "$buildDir"/${target}/*/libstdc++-v3/include "$buildDir"/${target}/*/*/libstdc++-v3/include; do
        if [ -d "$dir" ] && [ "$dir" != "$buildDir/${target}/libstdc++-v3/include" ]; then
          echo "Installing headers from multilib: $dir"
          cd "$dir"
          make install || echo "Warning: headers from $dir may be incomplete"
        fi
      done

      rm -rf "$out"/share
      rm -rf "$out"/lib

      runHook postInstall
    '';

    doCheck = false;
    enableParallelBuilding = true;
  };

  tiSupportFiles = pkgs.stdenv.mkDerivation {
    pname = "${target}-ti-support-files";
    version = "1.212";

    src = pkgs.fetchurl {
      url = "https://dr-download.ti.com/software-development/ide-configuration-compiler-or-debugger/MD-LlCjWuAbzH/9.3.1.2/msp430-gcc-support-files-1.212.zip";
      sha256 = "1mmqn1gql4sv369nks1v05jw1x6fpqssqq3yfvxzwk9l1bqkj6iv";
    };

    nativeBuildInputs = [ pkgs.unzip ];

    phases = [ "unpackPhase" "installPhase" ];

    unpackPhase = ''
      unzip $src
    '';

    installPhase = ''
      runHook preInstall

      supportDir="msp430-gcc-support-files"

      # Install device headers into the sysroot include directory
      install -d -m755 "$out/${target}/include"
      cp -v "$supportDir"/include/*.h "$out/${target}/include/"

      # Install linker scripts into the sysroot lib directory
      install -d -m755 "$out/${target}/lib"
      cp -v "$supportDir"/include/*.ld "$out/${target}/lib/"

      runHook postInstall
    '';
  };

  tarball = pkgs.stdenv.mkDerivation {
    pname = "${target}-gcc-tarball";
    version = "15.2.0";
    
    src = null;
    phases = ["installPhase"];
    
    nativeBuildInputs = [pkgs.gnutar pkgs.gzip pkgs.rsync pkgs.patchelf pkgs.findutils];
    
    installPhase = ''
      runHook preInstall

      set -euo pipefail

      # Ensure $out exists
      mkdir -p "$out"

      # Create a temporary directory to merge all packages
      tmpDir=$(mktemp -d)
      mkdir -p "$tmpDir"
      
      echo "=== Merging packages ==="
      # Copy all packages to the temp directory, merging them with rsync
      for p in ${binutils} ${newlib} ${gcc} ${libstdcxx} ${tiSupportFiles}; do
        rsync -a "$p"/ "$tmpDir"/
      done
      
      # Make everything writable (files from nix store are read-only)
      chmod -R u+w "$tmpDir"

      echo "=== Ensuring multilib C++ headers exist ==="
      # GCC resolves target-specific C++ headers via the multilib directory
      # (e.g. msp430-elf/430/no-exceptions/bits/c++config.h).  If the
      # libstdcxx build didn't produce headers for a combined multilib like
      # 430/no-exceptions, create symlinks to the nearest parent variant.
      cxxIncBase="$tmpDir/${target}/include/c++/15.2.0/${target}"
      for multilib in 430/no-exceptions large/no-exceptions large/full-memory-range; do
        if [ ! -d "$cxxIncBase/$multilib/bits" ]; then
          parent="''${multilib%/*}"
          if [ -d "$cxxIncBase/$parent/bits" ]; then
            echo "  Symlinking missing multilib C++ headers: $multilib -> $parent"
            mkdir -p "$cxxIncBase/$multilib"
            # Symlink from <parent>/<variant>/ up to <parent>/ contents
            ln -s "../bits" "$cxxIncBase/$multilib/bits"
            [ -d "$cxxIncBase/$parent/ext" ] && ln -s "../ext" "$cxxIncBase/$multilib/ext"
          elif [ -d "$cxxIncBase/bits" ]; then
            echo "  Symlinking missing multilib C++ headers: $multilib -> base"
            mkdir -p "$cxxIncBase/$multilib"
            # Calculate relative path back to base (two levels up for x/y)
            ln -s "../../bits" "$cxxIncBase/$multilib/bits"
            [ -d "$cxxIncBase/ext" ] && ln -s "../../ext" "$cxxIncBase/$multilib/ext"
          fi
        fi
      done

      echo "=== Generating clean GCC specs file ==="
      # Dump GCC's compiled-in specs and strip any Nix store paths.
      # When GCC reads a specs file, it overrides its compiled-in defaults.
      specsFile="$tmpDir/lib/gcc/${target}/15.2.0/specs"
      "$tmpDir/bin/${target}-gcc" -dumpspecs > "$specsFile"
      
      # Replace /nix/store/HASH-name paths so the specs file is clean.
      sed -i 's|/nix/store/[a-z0-9]\{32\}-[^/ ]*||g' "$specsFile"
      
      echo "  Specs file written to lib/gcc/${target}/15.2.0/specs"

      echo "=== Fixing text files with Nix store paths ==="
      # Fix shebangs in scripts (e.g. fixinc.sh references /nix/store/.../bash)
      find "$tmpDir" -type f \( -name "*.sh" -o -name "mkheaders" \) | while read -r script; do
        if head -1 "$script" | grep -q "/nix/store/"; then
          echo "  Fixing shebang in $(basename "$script")..."
          sed -i '1s|#!.*/bin/\(bash\|sh\)|#!/usr/bin/env \1|' "$script"
        fi
      done

      # install-tools/ contains scripts (mkheaders, fixinc.sh, mkheaders.conf)
      # used only when *installing* GCC itself — not needed for cross-compilation.
      # They embed Nix store paths in their bodies that can't be meaningfully
      # relocated, so remove the entire directory.
      find "$tmpDir" -type d -name "install-tools" -exec rm -rf {} + 2>/dev/null || true
      echo "  Removed install-tools directories (not needed for cross-compilation)"

      # Remove .la files — libtool archive files embed libdir paths and are
      # not needed at runtime for cross compilation.
      find "$tmpDir" -name '*.la' -type f -delete
      echo "  Removed .la files"

      echo "=== Patching ELF binaries ==="
      # Fix interpreter to standard FHS path and strip Nix RPATH entries.
      # GCC/binutils have a built-in prefix relocation mechanism
      # (make_relative_prefix) that computes library/include/tool paths
      # relative to the binary's actual location at runtime. The compiled-in
      # --prefix paths that remain as dead strings in the ELF data section
      # are fallbacks that simply won't resolve on Ubuntu — GCC ignores them
      # and uses the relocated paths instead. This is the standard mechanism
      # used by all vendor cross-compiler tarballs (ARM, RISC-V, etc.).
      
      patch_elf() {
        local exe="$1"
        if file "$exe" | grep -q "ELF"; then
          patchelf --set-interpreter /lib64/ld-linux-x86-64.so.2 "$exe" 2>/dev/null || true
          patchelf --remove-rpath "$exe" 2>/dev/null || true
        fi
      }
      
      # Patch executables in bin/
      find "$tmpDir/bin" -type f -executable | while read -r exe; do
        echo "  Patching $(basename "$exe")..."
        patch_elf "$exe"
      done
      
      # Patch cross-tools in the sysroot bin/ (as, ld, ar, etc.)
      # GCC invokes these internally via the sysroot path.
      find "$tmpDir/${target}/bin" -type f -executable 2>/dev/null | while read -r exe; do
        echo "  Patching sysroot tool $(basename "$exe")..."
        patch_elf "$exe"
      done
      
      # Patch internal GCC executables (cc1, cc1plus, collect2, lto-wrapper, etc.)
      find "$tmpDir/libexec" -type f -executable 2>/dev/null | while read -r exe; do
        echo "  Patching internal tool $(basename "$exe")..."
        patch_elf "$exe"
      done
      
      # Also patch any shared objects in libexec (e.g. liblto_plugin.so)
      find "$tmpDir/libexec" -type f -name '*.so*' 2>/dev/null | while read -r so; do
        echo "  Patching shared object $(basename "$so")..."
        patchelf --remove-rpath "$so" 2>/dev/null || true
      done
      
      # Remove any bundled .so files carried over from individual packages
      find "$tmpDir/lib" -maxdepth 1 -name '*.so*' -type f -delete 2>/dev/null || true
      
      echo "=== Auditing for Nix store paths ==="
      # Two categories of checks:
      #
      # 1. RPATH/RUNPATH and interpreter in ELF binaries — these MUST be clean
      #    because the dynamic linker uses them directly. Compiled-in strings
      #    (search paths, prefix) are NOT checked because GCC/binutils relocate
      #    them relative to the binary location at runtime.
      #
      # 2. Text/script files — shebangs, config files, specs must not reference
      #    /nix/store/ since there's no relocation mechanism for plain text.
      
      nixPathsFound=0
      
      # Check ELF RPATH/RUNPATH and interpreter via patchelf
      while IFS= read -r -d "" binfile; do
        if file "$binfile" | grep -q "ELF"; then
          rpath=$(patchelf --print-rpath "$binfile" 2>/dev/null || true)
          if echo "$rpath" | grep -q "/nix/store/"; then
            echo "ERROR: RPATH contains Nix store path in: $binfile"
            echo "  RPATH: $rpath"
            nixPathsFound=1
          fi
          interp=$(patchelf --print-interpreter "$binfile" 2>/dev/null || true)
          if echo "$interp" | grep -q "/nix/store/"; then
            echo "ERROR: Interpreter is Nix store path in: $binfile"
            echo "  Interpreter: $interp"
            nixPathsFound=1
          fi
        fi
      done < <(find "$tmpDir/bin" "$tmpDir/${target}/bin" "$tmpDir/libexec" -type f \( -executable -o -name '*.so*' \) -print0 2>/dev/null)
      
      # Check ALL text files for /nix/store/ references
      while IFS= read -r -d "" textfile; do
        # Only check files that 'file' identifies as text/script
        if file "$textfile" | grep -qiE "text|script|ASCII"; then
          matches=$(grep -c "/nix/store/" "$textfile" || true)
          if [ "$matches" -gt 0 ]; then
            echo "ERROR: Found $matches Nix store path(s) in text file: $textfile"
            grep "/nix/store/" "$textfile" | head -5
            nixPathsFound=1
          fi
        fi
      done < <(find "$tmpDir" -type f \( -name "*.specs" -o -name "specs" -o -name "*.la" \
        -o -name "*.cfg" -o -name "*.sh" -o -name "*.py" -o -name "mkheaders" \
        -o -name "fixinc.sh" -o -name "*.conf" \) -print0 2>/dev/null)
      
      # Explicitly verify the generated specs file
      if grep -q "/nix/store/" "$specsFile" 2>/dev/null; then
        echo "ERROR: Specs file still contains Nix store paths!"
        grep "/nix/store/" "$specsFile"
        nixPathsFound=1
      fi
      
      if [ "$nixPathsFound" -eq 1 ]; then
        echo ""
        echo "========================================="
        echo "FATAL: Nix store paths found in tarball!"
        echo "The tarball would be broken on Ubuntu."
        echo "========================================="
        exit 1
      fi
      echo "  Audit passed: no Nix store paths in RPATH, interpreter, or text files."

      echo "=== Creating tarball ==="
      tar --numeric-owner -C "$tmpDir" -czf "$out/msp430-elf-gcc-15.2.0-ubuntu.tar.gz" \
        --transform="s,^,toolchain/${target}/," .

      echo "Cleaning up..."
      chmod -R u+w "$tmpDir"
      rm -rf "$tmpDir"
      
      echo "Tarball created successfully: $out/msp430-elf-gcc-15.2.0-ubuntu.tar.gz"

      runHook postInstall
    '';
  };

in {
  inherit target binutils gccStage1 newlib gcc libstdcxx tiSupportFiles tarball;
}
