#!/bin/bash

cd "$(dirname "$0")"

# turn on verbose debugging output for parabuild logs.
set -x
# make errors fatal
set -e

OPENJPEG_VERSION="2.0.0"
OPENJPEG_SOURCE_DIR="openjpeg"

if [ -z "$AUTOBUILD" ] ; then 
    fail
fi

if [ "$OSTYPE" = "cygwin" ] ; then
    export AUTOBUILD="$(cygpath -u $AUTOBUILD)"
fi

# load autobuild provided shell functions and variables
set +x
eval "$("$AUTOBUILD" source_environment)"
set -x

stage="$(pwd)/stage"
pushd "$OPENJPEG_SOURCE_DIR"
    case "$AUTOBUILD_PLATFORM" in

        "windows")
            load_vsvars

            cmake . -G"Visual Studio 10" -DCMAKE_INSTALL_PREFIX=$stage
            
            build_sln "OPENJPEG.sln" "Release|Win32"
            build_sln "OPENJPEG.sln" "Debug|Win32"
            mkdir -p "$stage/lib/debug"
            mkdir -p "$stage/lib/release"
            cp bin/Release/openjp2{.dll,.lib} "$stage/lib/release"
            cp bin/Debug/openjp2.dll "$stage/lib/debug/openjp2d.dll"
            cp bin/Debug/openjp2.lib "$stage/lib/debug/openjp2d.lib"
            cp bin/Debug/openjp2.pdb "$stage/lib/debug/openjp2d.pdb"
            mkdir -p "$stage/include/openjp2"
            cp libopenjp2/openjpeg.h "$stage/include/openjp2"
        ;;

        "darwin")
            cmake . -GXcode -D'CMAKE_OSX_ARCHITECTURES:STRING=i386;ppc' -D'BUILD_SHARED_LIBS:bool=off' -D'BUILD_CODEC:bool=off' -DCMAKE_INSTALL_PREFIX=$stage
            xcodebuild -configuration Release -target libopenjp2.a -project openjpeg.xcodeproj
            xcodebuild -configuration Release -target install -project openjpeg.xcodeproj
            mkdir -p "$stage/lib/release"
            cp "$stage/lib/libopenjp2.a" "$stage/lib/release/libopenjp2.a"
            mkdir -p "$stage/include/openjp2"
            cp "$stage/include/openjp2/openjpeg.h" "$stage/include/openjp2"
        ;;

        "linux")
            # Force 4.6
            export CC=gcc-4.6
            export CXX=g++-4.6

            # Inhibit '--sysroot' nonsense
            export CPPFLAGS=""

            cmake -G"Unix Makefiles" \
                -DCMAKE_INSTALL_PREFIX="$stage" \
                -DBUILD_SHARED_LIBS:bool=off \
                -DCMAKE_INSTALL_DEBUG_LIBRARIES=1 .
            # From 1.4.0:
            # CFLAGS="-m32" CPPFLAGS="-m32" LDFLAGS="-m32" ./configure --target=i686-linux-gnu --prefix="$stage" --enable-png=no --enable-lcms1=no --enable-lcms2=no --enable-tiff=no
            make
            make install
            # conditionally run unit tests
            if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                echo "No unit tests yet"
            fi

            mv "$stage/lib" "$stage/release"
            mkdir -p "$stage/lib"
            mv "$stage/release" "$stage/lib"
        ;;
    esac
    mkdir -p "$stage/LICENSES"
    cp LICENSE "$stage/LICENSES/openjpeg.txt"
popd

pass
