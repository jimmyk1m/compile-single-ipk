#!/bin/sh
echo SOURCECODEURL: "$SOURCECODEURL"
echo PKGNAME: "$PKGNAME"
echo BOARD: "$BOARD"
EMAIL=${EMAIL:-"aa@163.com"}
echo EMAIL: "$EMAIL"
echo PASSWORD: "$PASSWORD"

WORKDIR="$(pwd)"

sudo -E apt-get update
# 增加 zstd 以支持 .tar.zst 解压
sudo -E apt-get install git asciidoc bash bc binutils bzip2 fastjar flex gawk gcc genisoimage gettext git intltool jikespg libgtk2.0-dev libncurses5-dev libssl1.0-dev make mercurial patch perl-modules python2.7-dev rsync ruby sdcc subversion unzip util-linux wget xsltproc zlib1g-dev zlib1g-dev zstd -y

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
    # 使用 OpenWrt 23.05.5 版本的 x86-64 SDK (tar.zst 格式)
    # 如果需要其他版本，请替换下面的链接
    wget -q -O openwrt-sdk.tar.zst https://downloads.openwrt.org/releases/23.05.5/targets/x86/64/openwrt-sdk-23.05.5-x86-64_gcc-12.3.0_musl.Linux-x86_64.tar.zst
    mkdir -p ${WORKDIR}/openwrt-sdk
    
    # 使用 -I zstd 解压 .tar.zst 文件
    tar -I zstd -xf openwrt-sdk.tar.zst -C ${WORKDIR}/openwrt-sdk --strip=1
}
rockchip_sdk_get()
{
    # 如果需要其他版本，请替换下面的链接
    wget -q -O https://downloads.openwrt.org/releases/25.12.0/targets/rockchip/armv8/openwrt-sdk-25.12.0-rockchip-armv8_gcc-14.3.0_musl.Linux-x86_64.tar.zst
    mkdir -p ${WORKDIR}/openwrt-sdk
    
    # 使用 -I zstd 解压 .tar.zst 文件
    tar -I zstd -xf openwrt-sdk.tar.zst -C ${WORKDIR}/openwrt-sdk --strip=1
}

# 这里保留了原来的逻辑结构，如果需要其他架构请自行补充函数
mips_siflower_sdk_get() { echo "TODO: Implement mips_siflower_sdk_get"; }
axt1800_sdk_get() { echo "TODO: Implement axt1800_sdk_get"; }

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
# 将 buildsource 目录链接到 feeds.conf.default
sed -i "1i\src-link githubaction ${WORKDIR}/buildsource" feeds.conf.default

ls -l
cat feeds.conf.default

./scripts/feeds update -a
./scripts/feeds install -a

# 编译x64固件配置 (如果是 X86 SDK)
# 注意：SDK 通常不需要重新选择 target，因为它是预编译好的。
# 但如果你需要生成新的 .config，可以保留这段。
cat >> .config <<EOF
CONFIG_TARGET_x86=y
CONFIG_TARGET_x86_64=y
CONFIG_TARGET_x86_64_Generic=y
EOF

# 生成一个通用的编译系统配置
make defconfig

# 输出配置信息
cat .config

# 编译插件
# 注意：make 后面跟的是路径，不需要加 ./ 
# 且必须使用 V=s 查看日志，否则报错很难排查
make package/feeds/githubaction/${PKGNAME}/compile V=s

find bin -type f -exec ls -lh {} \;
find bin -type f -name "*.ipk" -exec cp -f {} "${WORKDIR}" \;
