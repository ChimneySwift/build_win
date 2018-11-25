#!/bin/bash
set -e

echo -e ${GREEN}"Initializing..."${NC}

dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [ $# -ne 1 ]; then
	echo "Usage: $0 <build directory>"
	exit 1
fi
builddir=$1
mkdir -p $builddir
builddir="$( cd "$builddir" && pwd )"
packagedir=$builddir/packages
libdir=$builddir/libs

version_str="-dev"

RED="\e[31m"
GREEN="\e[32m"
CYAN="\e[36m"
NC="\e[0m"

toolchain_file=$dir/toolchain_mingw64.cmake
irrlicht_version=1.8.4
ogg_version=1.3.2
vorbis_version=1.3.5
curl_version=7.54.0
gettext_version=0.19.8.1
freetype_version=2.8
sqlite3_version=3.19.2
luajit_version=2.1.0-beta3
leveldb_version=1.19
zlib_version=1.2.11

mkdir -p $packagedir
mkdir -p $libdir

cd $builddir

# Get stuff
echo -e ${GREEN}"Downloading packages..."${NC}

[ -e $packagedir/irrlicht-$irrlicht_version.zip ] || wget http://minetest.kitsunemimi.pw/irrlicht-$irrlicht_version-win64.zip \
	-c -O $packagedir/irrlicht-$irrlicht_version.zip
[ -e $packagedir/zlib-$zlib_version.zip ] || wget http://minetest.kitsunemimi.pw/zlib-$zlib_version-win64.zip \
	-c -O $packagedir/zlib-$zlib_version.zip
[ -e $packagedir/libogg-$ogg_version.zip ] || wget http://minetest.kitsunemimi.pw/libogg-$ogg_version-win64.zip \
	-c -O $packagedir/libogg-$ogg_version.zip
[ -e $packagedir/libvorbis-$vorbis_version.zip ] || wget http://minetest.kitsunemimi.pw/libvorbis-$vorbis_version-win64.zip \
	-c -O $packagedir/libvorbis-$vorbis_version.zip
[ -e $packagedir/curl-$curl_version.zip ] || wget http://minetest.kitsunemimi.pw/curl-$curl_version-win64.zip \
	-c -O $packagedir/curl-$curl_version.zip
[ -e $packagedir/gettext-$gettext_version.zip ] || wget http://minetest.kitsunemimi.pw/gettext-$gettext_version-win64.zip \
	-c -O $packagedir/gettext-$gettext_version.zip
[ -e $packagedir/freetype2-$freetype_version.zip ] || wget http://minetest.kitsunemimi.pw/freetype2-$freetype_version-win64.zip \
	-c -O $packagedir/freetype2-$freetype_version.zip
[ -e $packagedir/sqlite3-$sqlite3_version.zip ] || wget http://minetest.kitsunemimi.pw/sqlite3-$sqlite3_version-win64.zip \
	-c -O $packagedir/sqlite3-$sqlite3_version.zip
[ -e $packagedir/luajit-$luajit_version.zip ] || wget http://luajit.org/download/LuaJIT-$luajit_version.zip \
   -c -O $packagedir/luajit-$luajit_version.zip
[ -e $packagedir/libleveldb-$leveldb_version.zip ] || wget http://minetest.kitsunemimi.pw/libleveldb-$leveldb_version-win64.zip \
	-c -O $packagedir/libleveldb-$leveldb_version.zip
[ -e $packagedir/openal_stripped.zip ] || wget http://minetest.kitsunemimi.pw/openal_stripped64.zip \
	-c -O $packagedir/openal_stripped.zip


# Extract stuff
echo -e ${GREEN}"Extracting packages..."${NC}

cd $libdir
[ -d irrlicht ] || unzip -q -o $packagedir/irrlicht-$irrlicht_version.zip -d irrlicht
[ -d zlib ] || unzip -q -o $packagedir/zlib-$zlib_version.zip -d zlib
[ -d libogg ] || unzip -q -o $packagedir/libogg-$ogg_version.zip -d libogg
[ -d libvorbis ] || unzip -q -o $packagedir/libvorbis-$vorbis_version.zip -d libvorbis
[ -d libcurl ] || unzip -q -o $packagedir/curl-$curl_version.zip -d libcurl
[ -d gettext ] || unzip -q -o $packagedir/gettext-$gettext_version.zip -d gettext
[ -d freetype ] || unzip -q -o $packagedir/freetype2-$freetype_version.zip -d freetype
[ -d sqlite3 ] || unzip -q -o $packagedir/sqlite3-$sqlite3_version.zip -d sqlite3
[ -d openal_stripped ] || unzip -q -o $packagedir/openal_stripped.zip
[ -d luajit ] || unzip -q -o $packagedir/luajit-$luajit_version.zip -d luajit-tmp
[ -d luasocket ] || git clone https://github.com/diegonehab/luasocket.git
[ -d leveldb ] || unzip -q -o $packagedir/libleveldb-$leveldb_version.zip -d leveldb

# Build the thing
echo -e ${GREEN}"Initiating build process..."${NC}

# Build luajit
echo -e ${GREEN}"Building luajit..."${NC}
[ -d luajit-tmp/LuaJIT-$luajit_version ] && mv luajit-tmp/LuaJIT-$luajit_version ./luajit && rmdir luajit-tmp
cd luajit
mingw32-make amalg
cd ..

# Build luasocket for the luajit we just built
echo -e ${GREEN}"Building luasocket..."${NC}
cd luasocket
export LUAV=5.1
export LUAINC_mingw=$libdir/luajit/src
export LUALIB_mingw=$libdir/luajit/src/lua51.dll
export CDIR_mingw=lua/$LUAV
export LDIR_mingw=lua/$LUAV/lua
mingw32-make mingw
mkdir -p socket-lib/mime socket-lib/socket
cd socket-lib
cp ../src/*.lua socket/
cp ../src/mime*.dll mime/core.dll
cp ../src/socket*.dll socket/core.dll
mv socket/ltn12.lua .
mv socket/socket.lua .
mv socket/mime.lua .
cd ../..

# Build Minetest!
# This first tries to build without re-running CMake, so you don't have to build from scratch every time
# If make fails, it'll run CMake and retry
# Problem with this approach is that it will run CMake and retry making whenever it fails, regardless of reason
# I'm a n00b to shell scripting so if you know how to make it work properly then please submit a PR
cd $builddir
{
	cd _build
    echo -e ${GREEN}"Attempting to compile without running CMake first (faster)..."${NC}
	mingw32-make -j$(nproc)
} || {
	echo -e ${RED}"Error running make or accessing makefile, (re)building make file..."${NC}
	[ -d _build ] && rm -Rf _build/
	mkdir _build
    cd _build
	{ # try
		{ # try
			mv C:/msys64/usr/bin/sh.exe C:/msys64/usr/bin/sh.exe~
			cmake .. \
			-G"MinGW Makefiles" \
			-DCMAKE_AR=/mingw64/x86_64-w64-mingw32/bin/ar \
			-DCMAKE_TOOLCHAIN_FILE=$toolchain_file \
			-DCMAKE_INSTALL_PREFIX=/tmp \
			-DVERSION_EXTRA=$git_hash \
			-DBUILD_CLIENT=1 -DBUILD_SERVER=0\
			-DCMAKE_BUILD_TYPE=Release\
			\
			-DENABLE_SOUND=1 \
			-DENABLE_CURL=1 \
			-DENABLE_GETTEXT=1 \
			-DENABLE_FREETYPE=1 \
			-DENABLE_LEVELDB=1 \
			\
			-DIRRLICHT_INCLUDE_DIR=$libdir/irrlicht/include \
			-DIRRLICHT_LIBRARY=$libdir/irrlicht/lib/Win64-gcc/libIrrlicht.dll.a \
			-DIRRLICHT_DLL=$libdir/irrlicht/bin/Win64-gcc/Irrlicht.dll \
			\
			-DZLIB_INCLUDE_DIR=$libdir/zlib/include \
			-DZLIB_LIBRARIES=$libdir/zlib/lib/libz.dll.a \
			-DZLIB_DLL=$libdir/zlib/bin/zlib1.dll \
			\
			-DLUA_INCLUDE_DIR=$libdir/luajit/src \
			-DLUA_LIBRARY=$libdir/luajit/src/lua51.dll \
			-DLUA_DLL=$libdir/luajit/src/lua51.dll \
			\
			-DOGG_INCLUDE_DIR=$libdir/libogg/include \
			-DOGG_LIBRARY=$libdir/libogg/lib/libogg.dll.a \
			-DOGG_DLL=$libdir/libogg/bin/libogg-0.dll \
			\
			-DVORBIS_INCLUDE_DIR=$libdir/libvorbis/include \
			-DVORBIS_LIBRARY=$libdir/libvorbis/lib/libvorbis.dll.a \
			-DVORBIS_DLL=$libdir/libvorbis/bin/libvorbis-0.dll \
			-DVORBISFILE_LIBRARY=$libdir/libvorbis/lib/libvorbisfile.dll.a \
			-DVORBISFILE_DLL=$libdir/libvorbis/bin/libvorbisfile-3.dll \
			\
			-DOPENAL_INCLUDE_DIR=$libdir/openal_stripped/include/AL \
			-DOPENAL_LIBRARY=$libdir/openal_stripped/lib/libOpenAL32.dll.a \
			-DOPENAL_DLL=$libdir/openal_stripped/bin/OpenAL32.dll \
			\
			-DCURL_DLL=$libdir/libcurl/bin/libcurl-4.dll \
			-DCURL_INCLUDE_DIR=$libdir/libcurl/include \
			-DCURL_LIBRARY=$libdir/libcurl/lib/libcurl.dll.a \
			\
			-DGETTEXT_MSGFMT=`which msgfmt` \
			-DGETTEXT_DLL=$libdir/gettext/bin/libintl-8.dll \
			-DGETTEXT_ICONV_DLL=$libdir/gettext/bin/libiconv-2.dll \
			-DGETTEXT_INCLUDE_DIR=$libdir/gettext/include \
			-DGETTEXT_LIBRARY=$libdir/gettext/lib/libintl.dll.a \
			\
			-DFREETYPE_INCLUDE_DIR_freetype2=$libdir/freetype/include/freetype2 \
			-DFREETYPE_INCLUDE_DIR_ft2build=$libdir/freetype/include/freetype2 \
			-DFREETYPE_LIBRARY=$libdir/freetype/lib/libfreetype.dll.a \
			-DFREETYPE_DLL=$libdir/freetype/bin/libfreetype-6.dll \
			\
			-DSQLITE3_INCLUDE_DIR=$libdir/sqlite3/include \
			-DSQLITE3_LIBRARY=$libdir/sqlite3/lib/libsqlite3.dll.a \
			-DSQLITE3_DLL=$libdir/sqlite3/bin/libsqlite3-0.dll \
			\
			-DLEVELDB_INCLUDE_DIR=$libdir/leveldb/include \
			-DLEVELDB_LIBRARY=$libdir/leveldb/lib/libleveldb.dll.a \
			-DLEVELDB_DLL=$libdir/leveldb/bin/libleveldb.dll
			mv C:/msys64/usr/bin/sh.exe~ C:/msys64/usr/bin/sh.exe
		} || { # catch
			${RED}echo -e "CMake failed, cleaning up..."${NC}
		    mv C:/msys64/usr/bin/sh.exe~ C:/msys64/usr/bin/sh.exe
            ${RED}echo -e "Building failed. Check CMake errors and try again."${NC}
		    exit 1
		}
	} && { #success
		echo -e ${GREEN}"Compiling..."${NC}
		{ # try
			mingw32-make -j$(nproc)
            echo -e ${GREEN}"Compilation successful!"${NC}
		} || { #catch
			echo -e ${RED}"Compilation failed."${NC}
            ${RED}echo -e "Building failed. Check make errors and try again."${NC}
			exit 1
		}
	}
}

# Now setup a fully functional build by moving all of the necessary files to their correct locations
# Move DLLs
echo -e ${GREEN}"Copying required DLL files to /bin..."${NC}
cp /mingw64/bin/libgcc_s_seh-1.dll $builddir/bin
cp /mingw64/bin/libstdc++-6.dll $builddir/bin
cp /mingw64/bin/libwinpthread-1.dll $builddir/bin
cp $libdir/irrlicht/bin/Win64-gcc/Irrlicht.dll $builddir/bin
cp $libdir/libcurl/bin/libcurl-4.dll $builddir/bin
cp $libdir/freetype/bin/libfreetype-6.dll $builddir/bin
cp $libdir/libogg/bin/libogg-0.dll $builddir/bin
cp $libdir/sqlite3/bin/libsqlite3-0.dll $builddir/bin
cp $libdir/libvorbis/bin/libvorbis-0.dll $builddir/bin
cp $libdir/libvorbis/bin/libvorbisfile-3.dll $builddir/bin
cp $libdir/leveldb/bin/libleveldb.dll $builddir/bin
cp $libdir/openal_stripped/bin/OpenAL32.dll $builddir/bin
cp $libdir/zlib/bin/zlib1.dll $builddir/bin
cp $libdir/gettext/bin/libiconv-2.dll $builddir/bin
cp $libdir/gettext/bin/libintl-8.dll $builddir/bin
cp $libdir/luasocket/src/*.dll $builddir/bin
cp $libdir/luajit/src/Lua51.dll $builddir/bin

# Move luasocket stuff
mkdir -p $builddir/bin/lua
cp -r $libdir/luasocket/socket-lib/* $builddir/bin/lua

mv $builddir/bin/mime-1.0.3.dll $builddir/bin/mime.dll
mv $builddir/bin/socket-3.0-rc1.dll $builddir/bin/socket.dll

echo -e ${GREEN}"Exporting package..."${NC}

cd $builddir
packdir=$builddir/minetest-$version_str

echo -e ${GREEN}"Deleting old package..."${NC}
rm -rf $packdir*

# Copy only the required files so we ignore stuff like sourcecode in the release build
echo -e ${GREEN}"Creating new directory and copying built Minetest..."${NC}
mkdir -p $packdir

set +e
cp -R $builddir/bin $packdir/bin
cp -R $builddir/builtin $packdir/builtin
cp -R $builddir/client $packdir/client
cp -R $builddir/clientmods $packdir/clientmods
cp -R $builddir/doc $packdir/doc
cp -R $builddir/fonts $packdir/fonts
cp -R $builddir/games $packdir/games
cp -R $builddir/locale $packdir/locale
cp -R $builddir/mods $packdir/mods
cp -R $builddir/misc $packdir/misc
cp -R $builddir/textures $packdir/textures
cp $builddir/minetest.conf.example $packdir/minetest.conf.example
cp $builddir/minetest.conf $packdir/minetest.conf
cp $builddir/README.txt $packdir/README.txt
set -e

echo -e ${GREEN}"Creating .zip file..."${NC}
zip -r -q -9 $packdir/minetest-$version_str.zip ./minetest-$version_str

echo -e ${GREEN}"All tasks finished and successful. Information:"${NC}
echo -e ${CYAN}"Compiled package directory: "${NC}$packdir
echo -e ${CYAN}"Compiled zipped package location: "${NC}$packdir/minetest-$version_str.zip
echo -e ${CYAN}"Minetest version: "${NC}$version_str
exit 0
# EOF
