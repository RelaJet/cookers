TOP="${PWD}"
PATH_KERNEL="${PWD}/linux"
PATH_UBOOT="${PWD}/u-boot"
CROSS_PATH="${PWD}/toolchain/bin"

export UIMAGE_TYPE=multi
export UIMAGE_IN=${PATH_KERNEL}/arch/arm/boot/Image:${PATH_KERNEL}/arch/arm/boot/dts/imxrt1050-evk.dtb
export PATH="${PATH_UBOOT}/tools:$CROSS_PATH:${PATH}"
export ARCH=arm
export CROSS_COMPILE=arm-v7-linux-uclibceabi-

# TARGET support: nutsboard pistachio series
IMX_PATH="./mnt"
MODULE=$(basename $BASH_SOURCE)
CPU_TYPE=$(echo $MODULE | awk -F. '{print $3}')
CPU_MODULE=$(echo $MODULE | awk -F. '{print $4}')
DISPLAY=$(echo $MODULE | awk -F. '{print $5}')


if [[ "$CPU_TYPE" == "relajet" ]]; then
    if [[ "$CPU_MODULE" == "rt1050" ]]; then
        UBOOT_CONFIG='mxrt105x-evk_defconfig'
        KERNEL_IMAGE='uImage'
        KERNEL_CONFIG='relajet_imxrt_defconfig'
        DTB_TARGET='imxrt1050-evk.dtb'
    fi
fi

recipe() {
    local TMP_PWD="${PWD}"

    case "${PWD}" in
        "${PATH_KERNEL}"*)
            cd "${PATH_KERNEL}"
            make "$@" menuconfig || return $?
            ;;
        *)
            echo -e "Error: outside the project" >&2
            return 1
            ;;
    esac

    cd "${TMP_PWD}"
}

heat() {
    local TMP_PWD="${PWD}"
    case "${PWD}" in
        "${TOP}")
            cd "${TMP_PWD}"
            cd ${PATH_UBOOT} && heat "$@" || return $?
            cd ${PATH_KERNEL} && heat "$@" || return $?
            cd "${TMP_PWD}"
            ;;
        "${PATH_KERNEL}"*)
            cd "${PATH_KERNEL}"
            make "$@" $DTB_TARGET || return $?
            KCFLAGS=-mno-fdpic make "$@" $KERNEL_IMAGE || return $?
            #make "$@" $KERNEL_IMAGE || return $?
            #make -mno-fdpic "$@" $DTB_TARGET || return $?
            ;;
        "${PATH_UBOOT}"*)
            cd "${PATH_UBOOT}"
            make "$@" || return $?
            ;;
        *)
            echo -e "Error: outside the project" >&2
            return 1
            ;;
    esac

    cd "${TMP_PWD}"
}

cook() {
    local TMP_PWD="${PWD}"

    case "${PWD}" in
        "${TOP}")
            cd ${PATH_UBOOT} && cook "$@" || return $?
            cd ${PATH_KERNEL} && cook "$@" || return $?
            ;;
        "${PATH_KERNEL}"*)
            cd "${PATH_KERNEL}"
            make "$@" $KERNEL_CONFIG || return $?
            heat "$@" || return $?
            ;;
        "${PATH_UBOOT}"*)
            cd "${PATH_UBOOT}"
            make "$@" $UBOOT_CONFIG || return $?
            heat "$@" || return $?
            ;;
        *)
            echo -e "Error: outside the project" >&2
            return 1
            ;;
    esac

    cd "${TMP_PWD}"
}

throw() {
    local TMP_PWD="${PWD}"

    case "${PWD}" in
        "${TOP}")
            rm -rf out
            cd ${PATH_UBOOT} && throw "$@" || return $?
            cd ${PATH_KERNEL} && throw "$@" || return $?
            ;;
        "${PATH_KERNEL}"*)
            cd "${PATH_KERNEL}"
            make "$@" distclean || return $?
            ;;
        "${PATH_UBOOT}"*)
            cd "${PATH_UBOOT}"
            make "$@" distclean || return $?
            ;;
        *)
            echo -e "Error: outside the project" >&2
            return 1
            ;;
    esac

    cd "${TMP_PWD}"
}

flashcard() {
  local TMP_PWD="${PWD}"

  cd "${TOP}"
  sudo -E cookers/flashcard "$@" $CPU_MODULE
  cd "${TMP_PWD}"
}


