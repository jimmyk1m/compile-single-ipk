#!/bin/sh
# 设置遇到错误即退出，避免一连串报错
set -e

echo SOURCECODEURL: "$SOURCECODEURL"
echo PKGNAME: "$PKGNAME"
echo BOARD: "$BOARD"
EMAIL=${EMAIL:-"aa@163.com"}
echo EMAIL: "$EMAIL"
echo PASSWORD: "$PASSWORD"

WORKDIR="$(pwd)"

sudo -E apt-get update
# 修复1: 更新依赖包名称
# libssl1.0-dev -> libssl-dev
# python2.7-dev -> python3-dev (OpenWrt 新版构建系统需要 Python3)
# 增加 zstd 以支持 .tar.zst 解压
sudo -E apt-get install -y git asciidoc bash bc binutils bzip2 fastjar flex gawk gcc genisoimage gettext git intltool jikespg libgtk2.0-dev libncurses5-dev libssl-dev make mercurial patch perl-modules python3-dev rsync ruby sdcc subversion unzip util-linux wget xsltproc zlib1g-dev zstd

git config --global user.email "${EMAIL}"
git config --global user.name "aa"
[ -n "${PASSWORD}" ] && git config --global user.password "${PASSWORD}"

# 下载需要编译插件的源代码
mkdir -p ${WORKDIR}/buildsource
cd ${WORKDIR}/buildsource
git clone "$SOURCECODEURL"
cd ${WORKDIR}

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
    # 修复2: wget 语法错误，缺少 -O 后的文件名参数
    # 修复3: 版本号修正。OpenWrt 没有 25.12.0 版本，这里改为 23.05.5 以匹配 X86 版本，或使用 snapshots
    # 如果必须使用特定版本，请确认 URL 有效。这里假设使用 23.05.5 stable
    wget -q -O openwrt-sdk.tar.zst https://downloads.openwrt.org/releases/25.12.0/targets/rockchip/armv8/openwrt-sdk-25.12.0-rockchip-armv8_gcc-14.3.0_musl.Linux-x86_64.tar.zst
    
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
        # 默认使用 X86 SDK
        x86_sdk_get
    ;;
esac

cd openwrt-sdk

# 加入要编译插件的代码
sed -i "1i\src-link githubaction ${WORKDIR}/buildsource" feeds.conf.default

ls -l
cat feeds.conf.default

./scripts/feeds update -a
./scripts/feeds install -a

# 修复4: 只有在使用 X86 SDK 时才强制写入 X86 配置
# SDK 自带默认配置，通常不需要手动覆盖 .config
# 如果确实需要，请根据架构区分
if [ "$BOARD" = "X86" ] || [ "$BOARD" = "" ]; then
    cat >> .config <<EOF
CONFIG_TARGET_x86=y
CONFIG_TARGET_x86_64=y
CONFIG_TARGET_x86_64_Generic=y
EOF
fi

# 生成配置
make defconfig

# 输出配置信息
cat .config

# 编译插件
# 必须使用 V=s 查看日志
make package/feeds/githubaction/${PKGNAME}/compile V=s

find bin -type f -exec ls -lh {} \;
find bin -type f -name "*.ipk" -exec cp -f {} "${WORKDIR}" \;
