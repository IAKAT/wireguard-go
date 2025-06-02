final: prev: {
  # First build the maybenot Rust library
  maybenot-ffi = prev.rustPlatform.buildRustPackage rec {
    pname = "maybenot-ffi";
    version = "0.0.20230223-daita";

    src = prev.fetchFromGitHub {
      owner = "iakat";
      repo = "wireguard-go";
      rev = "mullvad";
      sha256 = "sha256-2xld9kREAKLVJgqAQYIav3aqPDlRjXcjIUkyeviAr3I=";
    };

    sourceRoot = "source/maybenot-ffi";

    cargoHash = "sha256-fQTDA6NRirkw5G3lyqJRig4U2jitFQusSbWZCAZ6rdU=";

    nativeBuildInputs = with prev; [ pkg-config ];
    buildInputs = with prev; [ ];

    # Build as a shared library
    cargoBuildFlags = [ "--lib" ];

    # Skip tests since we only need the library
    doCheck = false;

    # Custom install phase to copy the shared library
    postInstall = ''
      # Check what files are created
      echo "Checking target directory contents:"
      find target -name "*.so" -o -name "*.dylib" -o -name "*.a" -o -name "libmaybenot*" | head -10

      # Create lib directory
      mkdir -p $out/lib
    '' + prev.lib.optionalString prev.stdenv.isDarwin ''
      # Find and copy the shared library on Darwin
      DYLIB_FILE=$(find target -name "libmaybenot_ffi*.dylib" | head -1)
      if [ -n "$DYLIB_FILE" ]; then
        cp "$DYLIB_FILE" $out/lib/libmaybenot.dylib
        echo "Copied $DYLIB_FILE to $out/lib/libmaybenot.dylib"
      else
        echo "No .dylib file found on Darwin, listing all files:"
        find target -type f | head -20
        exit 1
      fi
    '' + prev.lib.optionalString prev.stdenv.isLinux ''
      # Find and copy the shared library on Linux
      SO_FILE=$(find target -name "libmaybenot_ffi*.so" | head -1)
      if [ -n "$SO_FILE" ]; then
        cp "$SO_FILE" $out/lib/libmaybenot.so
        echo "Copied $SO_FILE to $out/lib/libmaybenot.so"
      else
        echo "No .so file found, listing all files:"
        find target -type f | head -20
        exit 1
      fi
    '';

    meta = with prev.lib; {
      description = "FFI library for maybenot traffic analysis protection";
    };
  };

  wireguard-go-daita = prev.buildGoModule rec {
    pname = "wireguard-go-daita";
    version = "0.0.20230223-daita";

    src = prev.fetchFromGitHub {
      owner = "iakat";
      repo = "wireguard-go";
      rev = "mullvad";
      sha256 = "sha256-2xld9kREAKLVJgqAQYIav3aqPDlRjXcjIUkyeviAr3I=";
    };

    nativeBuildInputs = with prev; [ ];

    buildInputs = with prev; [ 
      # Use platform-specific C library
    ] ++ prev.lib.optionals prev.stdenv.isLinux [
      glibc.dev
    ] ++ prev.lib.optionals prev.stdenv.isDarwin [
      prev.darwin.apple_sdk.frameworks.CoreFoundation
      prev.darwin.apple_sdk.frameworks.Security
    ];

    preBuild = ''
      # Copy the pre-built maybenot library (platform-specific)
    '' + prev.lib.optionalString prev.stdenv.isDarwin ''
      cp ${final.maybenot-ffi}/lib/libmaybenot.dylib ./
    '' + prev.lib.optionalString prev.stdenv.isLinux ''
      cp ${final.maybenot-ffi}/lib/libmaybenot.so ./
    '';

    # Skip tests since they need the shared library in a specific location
    doCheck = false;

    tags = [ "daita" ];

    vendorHash = "sha256-0PJqPR9NMWhXbOGoegYqTPeqF9drePX14JvU2b2sZrY=";

    subPackages = [ "." ];

    ldflags = [ "-s" ];

    postPatch = ''
      # Inject version
      printf 'package main\n\nconst Version = "%s"' "${version}" > version.go
    '';

    postInstall = ''
      mv $out/bin/wireguard $out/bin/wireguard-go

      # Copy the shared library to the output (platform-specific)
      mkdir -p $out/lib
    '' + prev.lib.optionalString prev.stdenv.isDarwin ''
      cp ${final.maybenot-ffi}/lib/libmaybenot.dylib $out/lib/
      
      # Use install_name_tool on Darwin instead of patchelf
      ${prev.darwin.cctools}/bin/install_name_tool \
        -change libmaybenot.dylib $out/lib/libmaybenot.dylib \
        $out/bin/wireguard-go
    '' + prev.lib.optionalString prev.stdenv.isLinux ''
      cp ${final.maybenot-ffi}/lib/libmaybenot.so $out/lib/
      
      # Patch the binary to include the library path on Linux
      ${prev.patchelf}/bin/patchelf --set-rpath "$out/lib:$(${prev.patchelf}/bin/patchelf --print-rpath $out/bin/wireguard-go)" $out/bin/wireguard-go
    '';

    meta = with prev.lib; {
      description = "Userspace Go implementation of WireGuard with DAITA support";
      homepage = "https://github.com/mullvad/wireguard-go";
      license = licenses.mit;
      mainProgram = "wireguard-go";
    };
  };
}
