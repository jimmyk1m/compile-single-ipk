#!/bin/sh
set -e

echo SOURCECODEURL: "$SOURCECODEURL"
echo PKGNAME: "$PKGNAME"
echo BOARD: "$BOARD"
EMAIL=${EMAIL:-"aa@163.com"}
echo EMAIL: "$EMAIL"
echo PASSWORD: "$PASSWORD"

WORKDIR="$(pwd)"

sudo -E apt-get update
# 修复依赖：增加 python3-pyelftools, swig
sudo -E apt-get install -y \
git asciidoc bash bc binutils bzip2 fastjar flex gawk gcc genisoimage gettext \
git intltool jikespg libgtk2.0-dev libncurses5-dev libssl-dev make mercurial \
patch perl-modules python3-dev python3-pyelftools rsync ruby sdcc subversion \
unzip util-linux wget xsltproc zlib1g-dev zstd swig

git config --global user.email "${EMAIL}"
git config --global user.name "aa"
[ -n "${PASSWORD}" ] && git config --global user.password "${PASSWORD}"

# 下载源码并修复 Makefile
mkdir -p ${WORKDIR}/buildsource
cd ${WORKDIR}/buildsource
git clone "$SOURCECODEURL"

# 【关键修复】注入 Build/Compile 规则
if [ -f "${PKGNAME}/Makefile" ]; then
    if ! grep -q "define Build/Compile" "${PKGNAME}/Makefile"; then
        echo "Fixing Makefile: Adding empty Build/Compile definition..."
        echo "" >> "${PKGNAME}/Makefile"
        echo "define Build/Compile" >> "${PKGNAME}/Makefile"
        echo "endef" >> "${PKGNAME}/Makefile"
    fi
fi

cd ${WORKDIR}

# SDK 下载函数
x86_sdk_get()
{
    echo "Downloading X86 SDK..."
    wget -q -O openwrt-sdk.tar.zst https://downloads.openwrt.org/releases/23.05.5/targets/x86/64/openwrt-sdk-23.05.5-x86-64_gcc-12.3.0_musl.Linux-x86_64.tar.zst
    mkdir -p ${WORKDIR}/openwrt-sdk
    tar -I zstd -xf openwrt-sdk.tar.zst -C ${WORKDIR}/openwrt-sdk --strip=1
}

rockchip_sdk_get()
{
    echo "Downloading Rockchip SDK..."
    SDK_URL="https://downloads.openwrt.org/releases/25.12.0/targets/rockchip/armv8/openwrt-sdk-25.12.0-rockchip-armv8_gcc-14.3.0_musl.Linux-x86_64.tar.zst"
    wget -4 --tries=10 -O openwrt-sdk.tar.zst "$SDK_URL"
    
    mkdir -p ${WORKDIR}/openwrt-sdk
    tar -I zstd -xf openwrt-sdk.tar.zst -C ${WORKDIR}/openwrt-sdk --strip=1
}

mips_siflower_sdk_get() { echo "TODO: Implement mips_siflower_sdk_get"; exit 1; }
axt1800_sdk_get() { echo "TODO: Implement axt1800_sdk_get"; exit 1; }

case "$BOARD" in
    "rockchip" )
        rockchip_sdk_get
    ;;
    "X86" )
        x86_sdk_get
    ;;
    *)
        x86_sdk_get
    ;;
esac

cd openwrt-sdk

# 链接源码
sed -i "1i\src-link githubaction ${WORKDIR}/buildsource" feeds.conf.default

./scripts/feeds update -a
./scripts/feeds install -a

# 配置 (仅 X86 需要写入，SDK 默认配置通常已就绪)
if [ "$BOARD" = "X86" ] || [ "$BOARD" = "" ]; then
    cat >> .config <<EOF
CONFIG_TARGET_x86=y
CONFIG_TARGET_x86_64=y
CONFIG_TARGET_x86_64_Generic=y
EOF
fi

make defconfig

# 编译
make package/feeds/githubaction/${PKGNAME}/compile V=s

find bin -type f -name "*.ipk" -exec cp -f {} "${WORKDIR}" \;
