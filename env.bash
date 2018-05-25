TOP="${PWD}"
PATH_KERNEL="${PWD}/linux"
PATH_ROOTFS="${PWD}/buildroot"
PATH_IMG_GEN="${PWD}/img_generator"

export ARCH=arm
export CROSS_COMPILE="${PATH_ROOTFS}/output/host/bin/arm-buildroot-linux-uclibcgnueabi-"

# TARGET support: relajet c series
IMX_PATH="./mnt"
MODULE=$(basename $BASH_SOURCE)
CPU_TYPE=$(echo $MODULE | awk -F. '{print $3}')
CPU_MODULE=$(echo $MODULE | awk -F. '{print $4}')
DISPLAY=$(echo $MODULE | awk -F. '{print $5}')


if [[ "$CPU_TYPE" == "relajet" ]]; then
    if [[ "$CPU_MODULE" == "ait8328q" ]]; then
        KERNEL_IMAGE=''
        KERNEL_CONFIG='relajet_8328q_defconfig'
        ROOTFS_CONFIG='relajet_c8328_defconfig'
        IMG_CONFIG='action_iot_2spi_config'
    fi
fi

recipe() {
    local TMP_PWD="${PWD}"

    case "${PWD}" in
        "${PATH_ROOTFS}"*)
            cd "${PATH_ROOTFS}"
            make "$@" menuconfig || return $?
            ;;
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
            cd ${PATH_ROOTFS} && heat "$@" || return $?
            cd "${TMP_PWD}"
            cd ${PATH_IMG_GEN} && heat "$@" || return $?
            cd "${TMP_PWD}"
            cd ${PATH_KERNEL} && heat "$@" || return $?
            cd "${TMP_PWD}"
            ;;
        "${PATH_IMG_GEN}"*)
            cd "${PATH_IMG_GEN}"
            cp -rv "${PATH_ROOTFS}"/output/images/rootfs.tar .
            mkdir -p ./root_file_system
            cd ./root_file_system
            sudo tar xvf ../rootfs.tar
            cd ../
            sync
            rm rootfs.tar
            sudo make "$@" || return $?
            sudo rm -rf root_file_system
            sync
            ;;
        "${PATH_ROOTFS}"*)
            cd "${PATH_ROOTFS}"
            sudo make "$@" || return $?
            ;;
        "${PATH_KERNEL}"*)
            cd "${PATH_KERNEL}"
            make KALLSYMS_EXTRA_PASS=1 || return $?
            make "$@" modules || return $?
            mkimage -A arm -O linux -T kernel -C none -a 0x1008000 -e 0x1008040 -n 'Linux-3.2.7' -d "${PATH_KERNEL}"/arch/arm/boot/zImage "${PATH_KERNEL}"/arch/arm/boot/uImage
            mkimage -A arm -O linux -T kernel -C none -a 0x1008000 -e 0x1008000 -n 'Linux-3.2.7' -d "${PATH_KERNEL}"/arch/arm/boot/Image "${PATH_KERNEL}"/arch/arm/boot/uImage.Raw
            rm -rf ./modules
            make modules_install INSTALL_MOD_PATH=./modules/
            ;;
        "${PATH_ROOTFS}"*)
            cd "${PATH_ROOTFS}"
            sudo make "$@" || return $?
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
            cd ${PATH_ROOTFS} && cook "$@" || return $?
            cd "${TMP_PWD}"
            cd ${PATH_IMG_GEN} && cook "$@" || return $?
            cd "${TMP_PWD}"
            cd ${PATH_KERNEL} && cook "$@" || return $?
            cd "${TMP_PWD}"
            ;;
        "${PATH_IMG_GEN}"*)
            cd "${PATH_IMG_GEN}"
            ./setup.sh "${IMG_CONFIG}"
            heat "$@" || return $?
            ;;
        "${PATH_ROOTFS}"*)
            cd "${PATH_ROOTFS}"
            make "$@" "${ROOTFS_CONFIG}" || return $?
            heat "$@" || return $?
            ;;
        "${PATH_KERNEL}"*)
            cd "${PATH_KERNEL}"
            make "$@" $KERNEL_CONFIG || return $?
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
            cd ${PATH_IMG_GEN} && throw "$@" || return $?
            cd ${PATH_ROOTFS} && throw "$@" || return $?
            cd ${PATH_KERNEL} && throw "$@" || return $?
            ;;
        "${PATH_IMG_GEN}"*)
            cd "${PATH_IMG_GEN}"
            sudo make "$@" clean || return $?
            ;;
        "${PATH_ROOTFS}"*)
            cd "${PATH_ROOTFS}"
            sudo make "$@" distclean || return $?
            ;;
        "${PATH_KERNEL}"*)
            cd "${PATH_KERNEL}"
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

  dev_node="$@"
  MNT_PATH="./mnt"
  echo "$dev_node prepare flash....."
  cd "${TOP}"
  sudo mkfs.vfat -F 32 ${dev_node}1 -n c_series;sync

  mkdir -p $MNT_PATH
  sudo mount ${dev_node}1 "$MNT_PATH"
  echo "$dev_node starting flash....."
  sudo cp -rv "$PATH_IMG_GEN"/update_tools/actcam_update_tool/* "$MNT_PATH"/
  sync
  sudo cp -rv "$PATH_KERNEL"/modules/lib/modules/3.2.7 "$MNT_PATH"/
  sync
  sudo cp -rv "$PATH_IMG_GEN"/driver/video/ait-cam-codec_MV2_ipc_v1.2.5.ko "$MNT_PATH"/
  sync
  sudo umount ${dev_node}1
  sudo rm -rf "$MNT_PATH"
  cd "${TMP_PWD}"
  echo "$dev_node done to flash....."
}
