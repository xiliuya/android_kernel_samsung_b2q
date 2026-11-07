#!/bin/bash

# 任何命令失败时立即退出脚本
set -e

# 获取脚本所在的目录，确保路径稳健
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

# 导出构建环境变量（设置 KBUILD_BUILD_TIMESTAMP 为空可确保可重复构建）
export LTO=thin
export ARCH=arm64
export PRODUCT_NAME=b2q
export CROSS_COMPILE="aarch64-linux-gnu-"
export CROSS_COMPILE_COMPAT="arm-linux-gnueabi-"
export PATH="$SCRIPT_DIR/../clang-rb397f8/bin/:$PATH"
export KBUILD_BUILD_TIMESTAMP=''

# 禁止生成 __pycache__
export PYTHONPYCACHEPREFIX=/tmp/kernel-pycache

# 路径和性能设置
OUT_DIR="$SCRIPT_DIR/out"
MODULE_INSTALL_DIR="$SCRIPT_DIR/modules_install" # 定义模块目标文件夹
JOBS="$(nproc --all)" # 动态获取所有 CPU 核心数

mkdir -p "$OUT_DIR"
mkdir -p "$MODULE_INSTALL_DIR"

# 将通用的 Make 环境变量和参数分组
KERNEL_MAKE_ENV=(
    LLVM=1
    LLVM_IAS=1
    CONFIG_BUILD_ARM64_DT_OVERLAY=y
    CC="ccache clang"
    ARCH=arm64
    CONFIG_SECTION_MISMATCH_WARN_ONLY=y
)

MAKE_ARGS=(
    -j"$JOBS"
    -C "$SCRIPT_DIR"
    O="$OUT_DIR"
    V=1
)

echo "===> 正在为 $PRODUCT_NAME 生成 defconfig..."
make "${MAKE_ARGS[@]}" "${KERNEL_MAKE_ENV[@]}" vendor/b2q_chn_hkx_defconfig

#make "${MAKE_ARGS[@]}" "${KERNEL_MAKE_ENV[@]}" menuconfig

echo "===> 正在使用 $JOBS 个并行任务编译内核..."
make "${MAKE_ARGS[@]}" "${KERNEL_MAKE_ENV[@]}"

echo "===> 正在使用 find 查找并复制所有 .ko 文件到 $MODULE_INSTALL_DIR..."
# 清空目标目录下的旧 ko 文件（可选）以防混淆
rm -f "$MODULE_INSTALL_DIR"/*.ko

# 递归查找 out 目录下所有的 .ko 文件并复制到目标目录
find "$OUT_DIR" -name "*.ko" -exec cp {} "$MODULE_INSTALL_DIR" \;

echo "===> 内核编译及模块复制完成！所有 .ko 文件已存放在：$MODULE_INSTALL_DIR"
