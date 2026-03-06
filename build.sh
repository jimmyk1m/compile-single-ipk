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

# 【修改点】增加 python3-pyelftools，修复 uboot prereq 失败的问题
# 同时保留 python3-dev, swig, zstd 等必要依赖
sudo -E apt-get install -y \
git asciidoc bash bc binutils bzip2 fastjar flex gawk gcc genisoimage gettext \
git intltool jikespg libgtk2.0-dev libncurses5-dev libssl-dev make mercurial \
patch perl-modules python3-dev python3-pyelftools rsync ruby sdcc subversion \
unzip util-linux wget xsltproc zlib1g-dev zstd swig

git config --global user.email "${EMAIL}"
git config --global user.name "aa"
[ -n "${PASSWORD}" ] && git config --global user.password "${PASSWORD}"

# 下载插件源码
mkdir -p ${WORKDIR}/buildsource
cd ${WORKDIR}/buildsource
git clone "$SOURCECODEURL"
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
    # 注意：OpenWrt 官方 Rockchip SDK 版本号需核对，这里假设使用 23.05.5
    wget -q -O openwrt-sdk.tar.zst https://downloads.openwrt.org/releases/23.05.5/targets/rockchip/armv8/openwrt-sdk-23.05.5-rockchip-armv8_gcc-12.3.0_musl.Linux-x86_64.tar.zst
    mkdir -p ${WORKDIR}/openwrt-sdk
    tar -I zstd -xf openwrt-sdk.tar.zst -C ${WORKDIR}/openwrt-sdk --strip=1
}

# 其他架构占位
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

# 注入源码
sed -i "1i\src-link githubaction ${WORKDIR}/buildsource" feeds.conf.default

ls -l
cat feeds.conf.default

./scripts/feeds update -a
./scripts/feeds install -a

# 【优化】配置部分
# SDK 通常不需要重新选 Target，因为已经预编译了内核。
# 强制写入配置可能会导致不必要的重编译或冲突。
# 如果你必须生成 .config，请确保架构匹配。
if [ "$BOARD" = "X86" ] || [ "$BOARD" = "" ]; then
    cat >> .config <<EOF
CONFIG_TARGET_x86=y
CONFIG_TARGET_x86_64=y
CONFIG_TARGET_x86_64_Generic=y
EOF
fi
# 如果是 Rockchip，SDK 自带的 .config 应该已经正确，无需手动干预

make defconfig

# 输出配置检查
cat .config

# 开始编译
make package/feeds/githubaction/${PKGNAME}/compile V=s

find bin -type f -exec ls -lh {} \;
find bin -type f -name "*.ipk" -exec cp -f {} "${WORKDIR}" \;
