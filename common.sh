#!/bin/bash

ACTIONS_VERSION="1.0.3"

# Black: \033[30m
# Red: \033[31m
# Green: \033[32m
# Yellow: \033[33m
# Blue: \033[34m
# Magenta:\033[35m
# Cyan: \033[36m
# White: \033[37m
# Reset: \033[0m
DEFAULT_COLOR="\033[0m"
RED_COLOR="\033[31m"
GREEN_COLOR="\033[32m"
YELLOW_COLOR="\033[33m"
BLUE_COLOR="\033[34m"
MAGENTA_COLOR="\033[35m"
CYAN_COLOR="\033[36m"
WHITE_COLOR="\033[36m"

function __error_msg() {
	echo -e "${RED_COLOR}[ERROR]${DEFAULT_COLOR} $*"
}

function __success_msg() {
	echo -e "${GREEN_COLOR}[SUCCESS]${DEFAULT_COLOR} $*"
}

function __warning_msg() {
	echo -e "${YELLOW_COLOR}[WARNING]${DEFAULT_COLOR} $*"
}

function __info_msg() {
	echo -e "${CYAN_COLOR}[INFO]${DEFAULT_COLOR} $*"
}
function __defualt_color() {
	echo -e "${DEFAULT_COLOR} $*"
}

function __red_color() {
	echo -e "${RED_COLOR} $*"
}

function __green_color() {
	echo -e "${GREEN_COLOR} $*"
}

function __yellow_color() {
	echo -e "${YELLOW_COLOR} $*"
}

function __blue_color() {
	echo -e "${BLUE_COLOR} $*"
}

function __magenta_color() {
	echo -e "${MAGENTA_COLOR} $*"
}

function __cyan_color() {
	echo -e "${CYAN_COLOR} $*"
}

function __white_color() {
	echo -e "${WHITE_COLOR} $*"
}

################################################################################################################
# 环境变量
################################################################################################################
function parse_settings() {
	source build/${MATRIX_TARGET}/settings.ini
	if [[ -n "${INPUTS_SOURCE_BRANCH}" ]]; then
		__info_msg "获取到actions设置，替换settings.ini设置"
		SOURCE_BRANCH="${INPUTS_SOURCE_BRANCH}"
		CONFIG_FILE="${INPUTS_CONFIG_FILE}"
		FIRMWARE_TYPE="${INPUTS_FIRMWARE_TYPE}"
		NOTICE_TYPE="${INPUTS_NOTICE_TYPE}"
		ENABLE_SSH="${INPUTS_ENABLE_SSH}"
		UPLOAD_RELEASE="${INPUTS_UPLOAD_RELEASE}"
		UPLOAD_FIRMWARE="${INPUTS_UPLOAD_FIRMWARE}"
		UPLOAD_CONFIG="${INPUTS_UPLOAD_CONFIG}"
		ENABLE_CACHEWRTBUILD="${INPUTS_ENABLE_CACHEWRTBUILD}"
	fi
	
	if [[ "${NOTICE_TYPE}" =~ 'false' ]]; then
		NOTICE_TYPE="false"
	elif [[ -n "$(echo "${NOTICE_TYPE}" |grep -i 'TG\|telegram')" ]]; then
		if [[ -z ${TELEGRAM_CHAT_ID} || -z ${TELEGRAM_BOT_TOKEN} ]]; then
			NOTICE_TYPE="false"
		else
			NOTICE_TYPE="TG"
		fi	
	elif [[ -n "$(echo "${NOTICE_TYPE}" |grep -i 'PUSH\|pushplus')" ]]; then
		if [[ -z ${PUSH_PLUS_TOKEN} ]]; then
			NOTICE_TYPE="false"
		else
			NOTICE_TYPE="TG"
		fi
		NOTICE_TYPE="PUSH"
	elif [[ -n "$(echo "${NOTICE_TYPE}" |grep -i 'WX\|WeChat')" ]]; then
		NOTICE_TYPE="WX"
	else
		NOTICE_TYPE="false"
	fi

	
	if [[ ${PACKAGES_ADDR} == "default" ]]; then
		PACKAGES_ADDR="roacn/openwrt-packages"
	fi
	if [[ ${ENABLE_PACKAGES_UPDATE} == "true" ]]; then
		local package_repo_owner=`echo "${PACKAGES_ADDR}" | awk -F/ '{print $1}'` 2>/dev/null
		if [[ ${package_repo_owner} != ${GITHUB_ACTOR} ]]; then
			ENABLE_PACKAGES_UPDATE="false"
			__warning_msg "插件库所有者：${package_repo_owner}"
			__warning_msg "没有权限更新插件库，关闭\"插件库更新\"！"
		fi
	fi
	
	case "${SOURCE_ABBR}" in
	lede|Lede|LEDE)
		SOURCE_URL="https://github.com/coolsnowwolf/lede"
		SOURCE="lede"
		SOURCE_OWNER="Lean's"
		LUCI_EDITION="18.06"
		PACKAGE_BRANCH="Lede"
	;;
	openwrt|Openwrt|OpenWrt|OpenWRT|OPENWRT|official|Official|OFFICIAL)
		SOURCE_URL="https://github.com/openwrt/openwrt"
		SOURCE="official"
		SOURCE_OWNER="openwrt's"
		LUCI_EDITION="$(echo "${SOURCE_BRANCH}" |sed 's/openwrt-//g')"
		PACKAGE_BRANCH="Official"
	;;
	*)
		__error_msg "不支持${SOURCE_ABBR}源码"
		exit 1
	;;
	esac
	
	# 下拉列表选项
	echo SOURCE_BRANCH="${SOURCE_BRANCH}" >> ${GITHUB_ENV}
	echo CONFIG_FILE="${CONFIG_FILE}" >> ${GITHUB_ENV}
	echo FIRMWARE_TYPE="${FIRMWARE_TYPE}" >> ${GITHUB_ENV}
	echo NOTICE_TYPE="${NOTICE_TYPE}" >> ${GITHUB_ENV}
	echo ENABLE_SSH="${ENABLE_SSH}" >> ${GITHUB_ENV}
	echo UPLOAD_RELEASE="${UPLOAD_RELEASE}" >> ${GITHUB_ENV}
	echo UPLOAD_FIRMWARE="${UPLOAD_FIRMWARE}" >> ${GITHUB_ENV}
	echo UPLOAD_CONFIG="${UPLOAD_CONFIG}" >> ${GITHUB_ENV}
	echo ENABLE_CACHEWRTBUILD="${ENABLE_CACHEWRTBUILD}" >> ${GITHUB_ENV}
	
	# 基础设置
	echo SOURCE="${SOURCE}" >> ${GITHUB_ENV}
	echo SOURCE_URL="${SOURCE_URL}" >> ${GITHUB_ENV}
	echo SOURCE_OWNER="${SOURCE_OWNER}" >> ${GITHUB_ENV}
	echo LUCI_EDITION="${LUCI_EDITION}" >> ${GITHUB_ENV}
	echo PACKAGE_BRANCH="${PACKAGE_BRANCH}" >> ${GITHUB_ENV}	
	echo REPOSITORY="${GITHUB_REPOSITORY##*/}" >> ${GITHUB_ENV}
	echo DIY_PART_SH="${DIY_PART_SH}" >> ${GITHUB_ENV}
	echo PACKAGES_ADDR="${PACKAGES_ADDR}" >> ${GITHUB_ENV}
	echo ENABLE_PACKAGES_UPDATE="${ENABLE_PACKAGES_UPDATE}" >> ${GITHUB_ENV}
	echo ENABLE_UPDATE_REPO="false" >> ${GITHUB_ENV}
	echo DIFFCONFIG_FILE="${GITHUB_WORKSPACE}/config.txt" >> ${GITHUB_ENV}
	echo CLEAR_FILE="${GITHUB_WORKSPACE}/openwrt/Clear" >> ${GITHUB_ENV}
	echo RELEASEINFO_FILE="${GITHUB_WORKSPACE}/openwrt/build/${MATRIX_TARGET}/releaseinfo.md" >> ${GITHUB_ENV}
	echo SETTINGS_FILE="${GITHUB_WORKSPACE}/openwrt/build/${MATRIX_TARGET}/settings.ini" >> ${GITHUB_ENV}
	
	# 日期时间
	echo COMPILE_DATE="$(date +%Y%m%d%H%M)" >> ${GITHUB_ENV}
	echo COMPILE_DATE_CN="$(date +%Y年%m月%d号%H时%M分)" >> ${GITHUB_ENV}
	echo UPGRADE_DATE="$(date -d "$(date +'%Y-%m-%d %H:%M:%S')" +%s)" >> ${GITHUB_ENV}
	echo FIRMWARE_DATE="$(date +%m.%d)" >> ${GITHUB_ENV}
	
	# 路径
	echo HOME_PATH="${GITHUB_WORKSPACE}/openwrt" >> ${GITHUB_ENV}
	echo BIN_PATH="${GITHUB_WORKSPACE}/openwrt/bin" >> ${GITHUB_ENV}
	echo AUTOUPDATE_PATH="${GITHUB_WORKSPACE}/openwrt/bin/autoupdate" >> ${GITHUB_ENV}
	echo BUILD_PATH="${GITHUB_WORKSPACE}/openwrt/build" >> ${GITHUB_ENV}
	echo COMMON_PATH="${GITHUB_WORKSPACE}/openwrt/build/common" >> ${GITHUB_ENV}
	echo MATRIX_TARGET_PATH="${GITHUB_WORKSPACE}/openwrt/build/${MATRIX_TARGET}" >> ${GITHUB_ENV}
	echo CONFIG_PATH="${GITHUB_WORKSPACE}/openwrt/build/${MATRIX_TARGET}/config" >> ${GITHUB_ENV}
	
	# 文件
	# https://github.com/coolsnowwolf/lede/tree/master/package/base-files/files
	echo FILES_PATH="${GITHUB_WORKSPACE}/openwrt/package/base-files/files" >> ${GITHUB_ENV}
	echo FILE_BASE_FILES="${GITHUB_WORKSPACE}/openwrt/package/base-files/files/lib/upgrade/keep.d/base-files-essential" >> ${GITHUB_ENV}
	echo FILE_DELETE="${GITHUB_WORKSPACE}/openwrt/package/base-files/files/etc/deletefile" >> ${GITHUB_ENV}
	echo FILE_DEFAULT_UCI="${GITHUB_WORKSPACE}/openwrt/package/base-files/files/etc/default_uci" >> ${GITHUB_ENV}
	echo FILE_DEFAULT_SETTINGS="${GITHUB_WORKSPACE}/openwrt/package/base-files/files/etc/default_settings" >> ${GITHUB_ENV}
	echo FILE_OPENWRT_RELEASE="${GITHUB_WORKSPACE}/openwrt/package/base-files/files/etc/openwrt_release" >> ${GITHUB_ENV}
	echo FILE_CONFIG_GEN="${GITHUB_WORKSPACE}/openwrt/package/base-files/files/bin/config_generate" >> ${GITHUB_ENV}
	
}

################################################################################################################
# 编译开始通知
################################################################################################################
function notice_begin() {
	if [[ "${NOTICE_TYPE}" == "TG" ]]; then
		curl -k --data chat_id="${TELEGRAM_CHAT_ID}" --data "text=🎉 主人：您正在使用【${GITHUB_REPOSITORY}】仓库【${MATRIX_TARGET}】文件夹编译${LUCI_EDITION}-${SOURCE}固件,请耐心等待...... 😋" "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage"
	elif [[ "${NOTICE_TYPE}" == "PUSH" ]]; then
		curl -k --data token="${PUSH_PLUS_TOKEN}" --data title="开始编译【${MATRIX_TARGET}】" --data "content=🎉 主人：您正在使用【${GITHUB_REPOSITORY}】仓库【${MATRIX_TARGET}】文件夹编译${LUCI_EDITION}-${SOURCE}固件,请耐心等待...... 😋💐" "http://www.pushplus.plus/send"
	fi
}

################################################################################################################
# 编译完成通知
################################################################################################################
function notice_end() {
	if [[ "${NOTICE_TYPE}" == "TG" ]]; then
		curl -k --data chat_id="${TELEGRAM_CHAT_ID}" --data "text=我亲爱的✨主人✨：您使用【${GITHUB_REPOSITORY}】仓库【${MATRIX_TARGET}】文件夹编译的[${SOURCE}-${TARGET_PROFILE }]固件顺利编译完成了！💐https://github.com/${GITHUB_REPOSITORY}/releases" "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage"
	elif [[ "${NOTICE_TYPE}" == "PUSH" ]]; then
		curl -k --data token="${PUSH_PLUS_TOKEN}" --data title="[${SOURCE}-${TARGET_PROFILE }]编译成功" --data "content=我亲爱的✨主人✨：您使用【${GITHUB_REPOSITORY}】仓库【${MATRIX_TARGET}】文件夹编译的[${SOURCE}-${TARGET_PROFILE }]固件顺利编译完成了！💐https://github.com/${GITHUB_REPOSITORY}/releases" "http://www.pushplus.plus/send"
	fi
}

################################################################################################################
# 初始化编译环境
################################################################################################################
function init_environment() {
	sudo -E apt-get -qq update -y
	sudo -E apt-get -qq full-upgrade -y
	sudo -E apt-get -qq install -y ack antlr3 aria2 asciidoc autoconf automake autopoint binutils bison build-essential bzip2 ccache cmake cpio curl device-tree-compiler fastjar flex g++-multilib gawk gcc-multilib gettext git git-core gperf haveged help2man intltool lib32stdc++6 libc6-dev-i386 libelf-dev libglib2.0-dev libgmp3-dev libltdl-dev libmpc-dev libmpfr-dev libncurses5-dev libncursesw5-dev libpcap0.8-dev libpython3-dev libreadline-dev libssl-dev libtool libz-dev lrzsz mkisofs msmtp nano ninja-build p7zip p7zip-full patch pkgconf python2.7 python3 python3-pip qemu-utils rename rsync scons squashfs-tools subversion swig texinfo uglifyjs unzip upx upx-ucl vim wget xmlto xxd zlib1g-dev
	sudo -E apt-get -qq autoremove -y --purge
	sudo -E apt-get -qq clean
	sudo timedatectl set-timezone "$TZ"
	# "/"目录创建文件夹${MATRIX_TARGET}
	sudo mkdir -p /${MATRIX_TARGET}
	sudo chown ${USER}:${GROUPS} /${MATRIX_TARGET}
	git config --global user.email "41898282+github-actions[bot]@users.noreply.github.com"
    git config --global user.name "github-actions[bot]" 
}

################################################################################################################
# 下载源码
################################################################################################################
function git_clone_source() {
	# 在每matrix.target目录下下载源码
	git clone -b "${SOURCE_BRANCH}" --single-branch "${SOURCE_URL}" openwrt > /dev/null 2>&1
	ln -sf /${MATRIX_TARGET}/openwrt ${GITHUB_WORKSPACE}/openwrt
	
	# 将build等文件夹复制到openwrt文件夹下
	cd ${GITHUB_WORKSPACE}
	cp -rf $(find ./ -maxdepth 1 -type d ! -path './openwrt' ! -path './') ${GITHUB_WORKSPACE}/openwrt/
	#rm -rf ${GITHUB_WORKSPACE}/openwrt/build/ && cp -rf ${GITHUB_WORKSPACE}/build/ ${GITHUB_WORKSPACE}/openwrt/build/
	
	# 下载common仓库
	sudo rm -rf ${BUILD_PATH}/common && git clone -b main --depth 1 https://github.com/stanlyshi/common ${BUILD_PATH}/common
	chmod -Rf +x ${BUILD_PATH}
	
}

################################################################################################################
# 插件库更新
################################################################################################################
function update_packages() {
	gitdate=$(curl -H "Authorization: token ${REPO_TOKEN}" -s "https://api.github.com/repos/${PACKAGES_ADDR}/actions/runs" | jq -r '.workflow_runs[0].created_at')
	gitdate=$(date -d "$gitdate" +%s)
	__info_msg "gitdate=${gitdate}"
	now=$(date -d "$(date '+%Y-%m-%d %H:%M:%S')" +%s)
	__info_msg "now=${now}"
	if [[ $(expr $gitdate + 60) < $now ]]; then
	curl -X POST https://api.github.com/repos/${PACKAGES_ADDR}/dispatches \
	-H "Accept: application/vnd.github.everest-preview+json" \
	-H "Authorization: token ${REPO_TOKEN}" \
	--data '{"event_type": "updated by ${REPOSITORY}"}'
	fi
	__info_msg "packages url: https://github.com/${PACKAGES_ADDR}"
}

################################################################################################################
# 加载源,补丁和自定义设置
################################################################################################################
function do_diy() {
	cd ${HOME_PATH}
		
	# 执行公共脚本
	diy_public
	
	
	# 执行源码库对应的私有脚本
	if [[ "${SOURCE}" =~ (lede|Lede|LEDE) ]]; then
		diy_lede
	elif [[ "${SOURCE}" =~ (openwrt|Openwrt|OpenWrt|OpenWRT|OPENWRT|official|Official|OFFICIAL) ]]; then
		diy_openwrt
	fi
	
	# 执行diy_part.sh脚本
	/bin/bash "${MATRIX_TARGET_PATH}/${DIY_PART_SH}"
	
	# 安装插件源
	./scripts/feeds clean
	./scripts/feeds update -a
	./scripts/feeds install -a > /dev/null 2>&1
	
	# .config相关
	# 复制自定义.config文件
	cp -rf ${CONFIG_PATH}/${CONFIG_FILE} ${HOME_PATH}/.config
	# 处理插件冲突
	resolve_conflictions > /dev/null 2>&1
	# 编译机型CPU架构、内核版本等信息，替换内核等
	firmware_settings
}


################################################################################################################
# 各源码库的公共脚本
################################################################################################################
function diy_public() {
	echo "--------------common_diy_public start--------------"
	echo
	cd ${HOME_PATH}

	__yellow_color "开始检测文件是否存在..."
	# 检查.config文件是否存在
	if [ -z "$(ls -A "${CONFIG_PATH}/${CONFIG_FILE}" 2>/dev/null)" ]; then
		__error_msg "编译脚本的[${MATRIX_TARGET}配置文件夹内缺少${CONFIG_FILE}文件],请在[${MATRIX_TARGET}/config/]文件夹内补齐"
		echo
		exit 1
	else
		__info_msg "[${MATRIX_TARGET}/config/${CONFIG_FILE}] OK."
	fi
	
	# 检查diy_part.sh文件是否存在
	if [ -z "$(ls -A "${MATRIX_TARGET_PATH}/${DIY_PART_SH}" 2>/dev/null)" ]; then
		__error_msg "编译脚本的[${MATRIX_TARGET}文件夹内缺少${DIY_PART_SH}文件],请在[${MATRIX_TARGET}]文件夹内补齐"
		echo
		exit 1
	else
		__info_msg "[${MATRIX_TARGET}/${DIY_PART_SH}] OK."
	fi
	
	__yellow_color "开始添加插件源..."
	# 添加插件源
	sed -i '/roacn/d; /stanlyshi/d; /281677160/d; /helloworld/d; /passwall/d; /OpenClash/d' "feeds.conf.default"
	cat feeds.conf.default|awk '!/^#/'|awk '!/^$/'|awk '!a[$1" "$2]++{print}' >uniq.conf
	mv -f uniq.conf feeds.conf.default
	if [[ "${SOURCE}" =~ (lede|Lede|LEDE) ]]; then
		__info_msg "添加lede源码对应插件源"
		cat >> "feeds.conf.default" <<-EOF
		src-git diypackages https://github.com/${PACKAGES_ADDR}.git;master
		EOF
	else
		__info_msg "添加${SOURCE}源码${PACKAGE_BRANCH}分支packages"
		cat >> "feeds.conf.default" <<-EOF
		src-git diypackages https://github.com/281677160/openwrt-package.git;${PACKAGE_BRANCH}
		EOF
	fi

	__yellow_color "开始添加openwrt.sh(或openwrt.lxc.sh)..."
	# openwrt.sh
	[[ ! -d "${FILES_PATH}/usr/bin" ]] && mkdir -p ${FILES_PATH}/usr/bin
	if [[ "${FIRMWARE_TYPE}" == "lxc" ]]; then
		cp -rf ${COMMON_PATH}/custom/openwrt.lxc.sh ${FILES_PATH}/usr/bin/openwrt.lxc && sudo chmod -f +x ${FILES_PATH}/usr/bin/openwrt.lxc
	else
		cp -rf ${COMMON_PATH}/custom/openwrt.sh ${FILES_PATH}/usr/bin/openwrt && sudo chmod -f +x ${FILES_PATH}/usr/bin/openwrt
	fi
	
	__yellow_color "开始替换diy文件夹内文件..."
	# 替换编译前源码中对应目录文件
	if [ -n "$(ls -A "${MATRIX_TARGET_PATH}/diy" 2>/dev/null)" ]; then
		cp -rf ${MATRIX_TARGET_PATH}/diy/* ${FILES_PATH} && chmod -Rf +x ${FILES_PATH}
	fi
	
	__yellow_color "开始替换files文件夹内文件..."
	# 替换编译后固件中对应目录文件（备用）
	if [ -n "$(ls -A "${MATRIX_TARGET_PATH}/files" 2>/dev/null)" ]; then
		rm -rf ${MATRIX_TARGET_PATH}/files/{LICENSE,.*README}
		cp -rf ${MATRIX_TARGET_PATH}/files ${HOME_PATH}
	fi
	
	__yellow_color "开始执行补丁文件..."
	# 打补丁
	if [ -n "$(ls -A "${MATRIX_TARGET_PATH}/patches" 2>/dev/null)" ]; then
		find "${MATRIX_TARGET_PATH}/patches" -type f -name '*.patch' -print0 | sort -z | xargs -I % -t -0 -n 1 sh -c "cat '%'  | patch -d './' -p1 --forward --no-backup-if-mismatch"
	fi
	
	__yellow_color "开始设置自动更新插件..."
	# 自动更新插件（luci-app-autoupdate）
	if [[ "${FIRMWARE_TYPE}" == "lxc" ]]; then
		find . -type d -name "luci-app-autoupdate" | xargs -i rm -rf {}
		if [[ -n "$(grep "luci-app-autoupdate" ${HOME_PATH}/include/target.mk)" ]]; then
			sed -i 's?luci-app-autoupdate??g' ${HOME_PATH}/include/target.mk
		fi
	else
		find . -type d -name 'luci-app-autoupdate' | xargs -i rm -rf {}
		git clone -b main https://github.com/stanlyshi/luci-app-autoupdate ${HOME_PATH}/package/luci-app-autoupdate 2>/dev/null
		if [[ `grep -c "luci-app-autoupdate" ${HOME_PATH}/include/target.mk` -eq '0' ]]; then
			sed -i 's?DEFAULT_PACKAGES:=?DEFAULT_PACKAGES:=luci-app-autoupdate luci-app-ttyd ?g' ${HOME_PATH}/include/target.mk
		fi
		if [[ -d "${HOME_PATH}/package/luci-app-autoupdate" ]]; then
			__success_msg "增加定时更新固件的插件成功"
		else
			__error_msg "插件源码下载失败"
		fi
	fi

	# "开始设置自动更新插件..."
	# https://github.com/coolsnowwolf/lede/blob/master/package/lean/default-settings/files/zzz-default-settings
	export ZZZ_PATH="$(find "${HOME_PATH}/package" -type f -name "*-default-settings" |grep files)"
	if [[ -n "${ZZZ_PATH}" ]]; then  
		echo ZZZ_PATH="${ZZZ_PATH}" >> ${GITHUB_ENV}
	fi
	
	__yellow_color "开始修改IP设置..."
	# 修改源码中IP设置
	local def_ipaddress="$(grep "ipaddr:-" "${FILE_CONFIG_GEN}" | grep -v 'addr_offset' | grep -Eo "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+")"
	local new_ipaddress="$(grep "network.lan.ipaddr" ${MATRIX_TARGET_PATH}/${DIY_PART_SH} | grep -Eo "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+")"
	if [[ -n "${new_ipaddress}" ]]; then
		sed -i "s/${def_ipaddress}/${new_ipaddress}/g" ${FILE_CONFIG_GEN}
		__info_msg "IP地址从[${def_ipaddress}]替换为[${new_ipaddress}]"
	else
		__info_msg "使用默认IP地址：${def_ipaddress}"
	fi
	
	__yellow_color "开始执行其它设置..."
	# UCI基础设置
	echo '#!/bin/bash' > "${FILE_DEFAULT_UCI}"
	sudo chmod -f +x "${FILE_DEFAULT_UCI}"
	
	# Openwrt固件升级时需要删除的文件
	echo '#!/bin/bash' > "${FILE_DELETE}"
	sudo chmod -f +x "${FILE_DELETE}"
	
	# Openwrt初次运行初始化设置
	cp -rf ${COMMON_PATH}/custom/default_settings ${FILE_DEFAULT_SETTINGS}
	sudo chmod -f +x ${FILE_DEFAULT_SETTINGS}	
	echo '
	rm -rf /etc/init.d/default_setting_runonce
	rm -rf /etc/default_settings
	exit 0
	' >> ${FILE_DEFAULT_SETTINGS}
	
	echo
	echo "--------------common_diy_public end--------------"
}

################################################################################################################
# LEDE源码库的私有脚本
################################################################################################################
function diy_lede() {
	echo "--------------common_diy_lede start--------------"
	echo
	cd ${HOME_PATH}

	__info_msg "去除防火墙规则"
	sed -i '/to-ports 53/d' ${ZZZ_PATH}

	__info_msg "设置密码为空"
	sed -i '/CYXluq4wUazHjmCDBCqXF/d' ${ZZZ_PATH}

	echo
	echo "--------------common_diy_lede end--------------"
}

################################################################################################################
# 官方源码库的私有脚本
################################################################################################################
function diy_openwrt() {
	echo "--------------common_diy_openwrt start--------------"
	echo
	cd ${HOME_PATH}

	echo "reserved for test."
	echo
	echo "--------------common_diy_openwrt end--------------"
}

################################################################################################################
# 生成.config文件
################################################################################################################
function make_defconfig() {
	cd ${HOME_PATH}
	
	# 生成.config文件
	make defconfig > /dev/null 2>&1
	# 生成diffconfig文件
	bash ${HOME_PATH}/scripts/diffconfig.sh > ${DIFFCONFIG_FILE}
}

################################################################################################################
# 编译机型CPU架构、内核版本、固件信息等（依赖于make defconfig，须在生成.config之后）
################################################################################################################
function firmware_settings() {
	# 如未运行过 make menuconfig，需要运行下一行命令
	# make defconfig > /dev/null 2>&1
	
	TARGET_BOARD="$(awk -F '[="]+' '/TARGET_BOARD/{print $2}' ${HOME_PATH}/.config)"
	TARGET_SUBTARGET="$(awk -F '[="]+' '/TARGET_SUBTARGET/{print $2}' ${HOME_PATH}/.config)"
	FIRMWARE_PATH=${HOME_PATH}/bin/targets/${TARGET_BOARD}/${TARGET_SUBTARGET}
	
	# CPU架构
	if [ `grep -c "CONFIG_TARGET_x86_64=y" .config` -eq '1' ]; then
		TARGET_PROFILE="x86-64"
	elif [[ `grep -c "CONFIG_TARGET_x86=y" .config` == '1' ]] && [[ `grep -c "CONFIG_TARGET_x86_64=y" .config` == '0' ]]; then
		TARGET_PROFILE="x86-32"
	elif [[ -n "$(grep -Eo 'CONFIG_TARGET.*armsr.*armv8.*=y' ${HOME_PATH}/.config)" ]]; then
		TARGET_PROFILE="Armvirt_64"
	elif [[ -n "$(grep -Eo 'CONFIG_TARGET.*armvirt.*64.*=y' ${HOME_PATH}/.config)" ]]; then
		TARGET_PROFILE="Armvirt_64"
	elif [[ -n "$(grep -Eo 'CONFIG_TARGET.*DEVICE.*=y' ${HOME_PATH}/.config)" ]]; then
		TARGET_PROFILE="$(grep -Eo "CONFIG_TARGET.*DEVICE.*=y" ${HOME_PATH}/.config | sed -r 's/.*DEVICE_(.*)=y/\1/')"
	else
		TARGET_PROFILE="$(awk -F '[="]+' '/TARGET_PROFILE/{print $2}' ${HOME_PATH}/.config)"
	fi
	__info_msg "CPU架构：${TARGET_PROFILE}"
	
	# 内核版本
	KERNEL_PATCHVER="$(grep "KERNEL_PATCHVER" "${HOME_PATH}/target/linux/${TARGET_BOARD}/Makefile" |grep -Eo "[0-9]+\.[0-9]+")"
	local kernel_version_file="kernel-${KERNEL_PATCHVER}"
	if [[ -f "${HOME_PATH}/include/${kernel_version_file}" ]]; then
		LINUX_KERNEL=$(egrep -o "${KERNEL_PATCHVER}\.[0-9]+" ${HOME_PATH}/include/${kernel_version_file})
		[[ -z ${LINUX_KERNEL} ]] && export LINUX_KERNEL="unknown"
	else
		LINUX_KERNEL=$(egrep -o "${KERNEL_PATCHVER}\.[0-9]+" ${HOME_PATH}/include/kernel-version.mk)
		[[ -z ${LINUX_KERNEL} ]] && export LINUX_KERNEL="unknown"
	fi	
	__info_msg "linux内核版本：${LINUX_KERNEL}"
	
	# 内核替换
	if [[ -n "${NEW_KERNEL_PATCHVER}" ]]; then
		if [[ "${NEW_KERNEL_PATCHVER}" == "0" ]]; then
			__info_msg "编译固件内核：[ ${KERNEL_PATCHVER} ]"
		elif [[ `ls -1 "${HOME_PATH}/target/linux/${TARGET_BOARD}" |grep -c "kernel-${NEW_KERNEL_PATCHVER}"` -eq '1' ]]; then
			sed -i "s/${KERNEL_PATCHVER}/${NEW_KERNEL_PATCHVER}/g" ${HOME_PATH}/target/linux/${TARGET_BOARD}/Makefile
			__success_msg "内核[ ${NEW_KERNEL_PATCHVER} ]更换完成"
		else
			__error_msg "没发现与${TARGET_PROFILE}机型对应[ ${NEW_KERNEL_PATCHVER} ]内核，使用默认内核[ ${KERNEL_PATCHVER} ]编译"
		fi
	else
		__info_msg "编译固件内核：[ ${KERNEL_PATCHVER} ]"
	fi


	# 固件相关
	if [[ "${FIRMWARE_TYPE}" == "lxc" ]]; then
		RELEASE_TAG="AutoUpdate-${TARGET_BOARD}-lxc"
	else
		RELEASE_TAG="AutoUpdate-${TARGET_BOARD}"
	fi
	
	local firmware_info_file="${FILES_PATH}/etc/openwrt_update"
	local github_api_origin="${GITHUB_REPO_URL}/releases/download/${RELEASE_TAG}/github_api"
	local github_api_fastgit="https://download.fastgit.org/${GITHUB_REPOSITORY}/releases/download/${RELEASE_TAG}/github_api"
	local github_api_ghproxy="https://ghproxy.com/${GITHUB_REPO_URL}/releases/download/${RELEASE_TAG}/github_api"
	local api_path="/tmp/Downloads/github_api"
	local release_download_origin="${GITHUB_REPO_URL}/releases/download/${RELEASE_TAG}"
	local release_download_ghproxy="https://ghproxy.com/${GITHUB_REPO_URL}/releases/download/${RELEASE_TAG}"
	GITHUB_RELEASE_URL="${GITHUB_REPO_URL}/releases/tag/${RELEASE_TAG}"

	if [[ "${TARGET_PROFILE}" =~ (phicomm_k3|phicomm-k3) ]]; then
		TARGET_PROFILE_ER="phicomm-k3"
	elif [[ "${TARGET_PROFILE}" =~ (k2p|phicomm_k2p|phicomm-k2p) ]]; then
		TARGET_PROFILE_ER="phicomm-k2p"
	elif [[ "${TARGET_PROFILE}" =~ (xiaomi_mi-router-3g-v2|xiaomi_mir3g_v2) ]]; then
		TARGET_PROFILE_ER="xiaomi_mir3g-v2"
	elif [[ "${TARGET_PROFILE}" == "xiaomi_mi-router-3g" ]]; then
		TARGET_PROFILE_ER="xiaomi_mir3g"
	elif [[ "${TARGET_PROFILE}" == "xiaomi_mi-router-3-pro" ]]; then
		TARGET_PROFILE_ER="xiaomi_mir3p"
	else
		TARGET_PROFILE_ER="${TARGET_PROFILE}"
	fi

	case "${TARGET_BOARD}" in
	x86)
		Rootfs_sfx=".tar.gz"
		Firmware_SFX=".img.gz"
		# 18.06-lede-x86-64-1695553941-legacy
		AutoBuild_Legacy="${LUCI_EDITION}-${SOURCE}-${TARGET_PROFILE}-${COMPILE_DATE}-legacy"
		# 18.06-lede-x86-64-1695553941-uefi
		AutoBuild_Uefi="${LUCI_EDITION}-${SOURCE}-${TARGET_PROFILE}-${COMPILE_DATE}-uefi"
		# 18.06-lede-x86-64-1695647548-rootfs
		AutoBuild_Rootfs="${LUCI_EDITION}-${SOURCE}-${TARGET_PROFILE}-${COMPILE_DATE}-rootfs"
	;;
	ramips | reltek | ath* | ipq* | bcm47xx | bmips | kirkwood | mediatek)
		Firmware_SFX=".bin"
		AutoBuild_Firmware="${LUCI_EDITION}-${SOURCE}-${TARGET_PROFILE_ER}-${UPGRADE_DATE}-sysupgrade"
	;;
	rockchip | bcm27xx | mxs | sunxi | zynq)
		Firmware_SFX=".img.gz"
		AutoBuild_Firmware="${LUCI_EDITION}-${SOURCE}-${TARGET_PROFILE_ER}-${UPGRADE_DATE}-sysupgrade"
	;;
	mvebu)
		case "${TARGET_SUBTARGET}" in
		cortexa53 | cortexa72)
			Firmware_SFX=".img.gz"
			AutoBuild_Firmware="${LUCI_EDITION}-${SOURCE}-${TARGET_PROFILE_ER}-${UPGRADE_DATE}-sysupgrade"
		;;
		esac
	;;
	bcm53xx)
		Firmware_SFX=".trx"
		AutoBuild_Firmware="${LUCI_EDITION}-${SOURCE}-${TARGET_PROFILE_ER}-${UPGRADE_DATE}-sysupgrade"
	;;
	octeon | oxnas | pistachio)
		Firmware_SFX=".tar"
		AutoBuild_Firmware="${LUCI_EDITION}-${SOURCE}-${TARGET_PROFILE_ER}-${UPGRADE_DATE}-sysupgrade"
	;;
	*)
		Firmware_SFX=".bin"
		AutoBuild_Firmware="${LUCI_EDITION}-${SOURCE}-${TARGET_PROFILE_ER}-${UPGRADE_DATE}-sysupgrade"
	;;
	esac

	if [[ -f "${HOME_PATH}/package/luci-app-autoupdate/root/usr/bin/AutoUpdate" ]]; then
		AutoUpdate_Version=$(grep -Eo "Version=V[0-9.]+" "${HOME_PATH}/package/luci-app-autoupdate/root/usr/bin/AutoUpdate" |grep -Eo [0-9.]+)
	fi
	
	OPENWRT_VERSION="${SOURCE}-${TARGET_PROFILE_ER}-${UPGRADE_DATE}"
	local cloud_find="${LUCI_EDITION}-${SOURCE}-${TARGET_PROFILE_ER}"
	
	if [[ "${TARGET_BOARD}" == "x86" ]]; then
		echo AutoBuild_Legacy="${AutoBuild_Legacy}" >> ${GITHUB_ENV}
		echo AutoBuild_Uefi="${AutoBuild_Uefi}" >> ${GITHUB_ENV}
		echo AutoBuild_Rootfs="${AutoBuild_Rootfs}" >> ${GITHUB_ENV}
		echo Rootfs_sfx="${Rootfs_sfx}" >> ${GITHUB_ENV}
	else
		echo AutoBuild_Firmware="${AutoBuild_Firmware}" >> ${GITHUB_ENV}
	fi
	
	echo TARGET_BOARD="${TARGET_BOARD}" >> ${GITHUB_ENV}
	echo TARGET_SUBTARGET="${TARGET_SUBTARGET}" >> ${GITHUB_ENV}
	echo FIRMWARE_PATH="${FIRMWARE_PATH}" >> ${GITHUB_ENV}
	echo TARGET_PROFILE="${TARGET_PROFILE}" >> ${GITHUB_ENV}
	echo KERNEL_PATCHVER="${KERNEL_PATCHVER}" >> ${GITHUB_ENV}
	echo LINUX_KERNEL="${LINUX_KERNEL}" >> ${GITHUB_ENV}
	echo Firmware_SFX="${Firmware_SFX}" >> ${GITHUB_ENV}
	echo RELEASE_TAG="${RELEASE_TAG}" >> ${GITHUB_ENV}
	echo AutoUpdate_Version="${AutoUpdate_Version}" >> ${GITHUB_ENV}
	echo OPENWRT_VERSION="${OPENWRT_VERSION}" >> ${GITHUB_ENV}
	echo GITHUB_RELEASE_URL="${GITHUB_RELEASE_URL}" >> ${GITHUB_ENV}
	
	cat > "${firmware_info_file}" <<-EOF
	GITHUB_LINK="${GITHUB_REPO_URL}"
	CURRENT_Version="${OPENWRT_VERSION}"
	SOURCE="${SOURCE}"
	LUCI_EDITION="${LUCI_EDITION}"
	DEFAULT_Device="${TARGET_PROFILE_ER}"
	Firmware_SFX="${Firmware_SFX}"
	TARGET_BOARD="${TARGET_BOARD}"
	CLOUD_CHAZHAO="${cloud_find}"
	Download_Path="/tmp/Downloads"
	Version="${AutoUpdate_Version}"
	API_PATH="${API_PATH}"
	Github_API1="${github_api_fastgit}"
	Github_API2="${github_api_ghproxy}"
	Github_Release="${GITHUB_RELEASE_URL}"
	Release_download1="${release_download_origin}"
	Release_download2="${release_download_ghproxy}"
	EOF

	cat ${HOME_PATH}/build/common/autoupdate/replace >> ${firmware_info_file}
	sudo chmod +x ${firmware_info_file}
}

################################################################################################################
# 编译信息
################################################################################################################
function compile_info() {	
	echo
	__red_color "OpenWrt固件信息"
	__blue_color "编译源码: ${SOURCE}"
	__blue_color "源码链接: ${SOURCE_URL}"
	__blue_color "源码分支: ${SOURCE_BRANCH}"
	__blue_color "源码作者: ${SOURCE_OWNER}"
	__blue_color "内核版本: ${LINUX_KERNEL}"
	__blue_color "Luci版本: ${LUCI_EDITION}"
	__blue_color "机型架构: ${TARGET_PROFILE}"
	__blue_color "固件作者: ${GITHUB_ACTOR}"
	__blue_color "仓库地址: ${GITHUB_REPO_URL}"
	__blue_color "编译时间: ${COMPILE_DATE_CN}"
	__blue_color "友情提示：您当前使用【${MATRIX_TARGET}】文件夹编译【${TARGET_PROFILE}】固件"
	echo

	echo
	__red_color "固件类型"
	if [[ "${FIRMWARE_TYPE}" == "lxc" ]]; then
		__blue_color "LXC固件：开启"
		echo
		__red_color "LXC固件自动更新："
		__defualt_color "1、PVE运行："
		__cyan_color "pct pull xxx /sbin/openwrt.lxc /usr/sbin/openwrt && chmod -f +x /usr/sbin/openwrt"
		__cyan_color "注意：将xxx改为个人OpenWrt容器的ID，如100"
		__defualt_color "2、PVE运行："
		__cyan_color "openwrt"
		echo
	else
		__defualt_color "LXC固件：关闭"
		echo
		__red_color "自动更新信息"
		__yellow_color "插件版本: ${AutoUpdate_Version}"
		if [[ "${TARGET_PROFILE}" == "x86" ]]; then
			__yellow_color "传统固件: ${AutoBuild_Legacy}${Firmware_SFX}"
			__yellow_color "UEFI固件: ${AutoBuild_Uefi}${Firmware_SFX}"
			__yellow_color "固件后缀: ${Firmware_sfx}"
		else
			__yellow_color "固件名称: ${AutoBuild_Firmware}${Firmware_SFX}"
			__yellow_color "固件后缀: ${Firmware_sfx}"
		fi
		__yellow_color "固件版本: ${OPENWRT_VERSION}"
		__yellow_color "云端路径: ${GITHUB_RELEASE_URL}"
		__white_color "编译成功后，会自动把固件发布到指定地址，生成云端路径"
		__white_color "修改IP、DNS、网关或者在线更新，请输入命令：openwrt"
	fi
	
	echo
	__red_color "Github在线编译配置"
	if [[ "${UPLOAD_RELEASE}" == "true" ]]; then
		__blue_color "发布firmware+ipk至Github Relese: 开启"
	else
		__defualt_color "发布firmware+ipk至Github Relese: 关闭"
	fi
	if [[ "${UPLOAD_FIRMWARE}" == "true" ]]; then
		__blue_color "上传firmware+ipk至Github Artifacts: 开启"
	else
		__defualt_color "上传firmware+ipk至Github Artifacts: 关闭"
	fi
	if [[ "${UPLOAD_CONFIG}" == "true" ]]; then
		__blue_color "上传.config配置文件至Github Artifacts: 开启"
	else
		__defualt_color "上传.config配置文件至Github Artifacts: 关闭"
	fi
	if [[ "${NOTICE_TYPE}" == "true" ]]; then
		__blue_color "pushplus/Telegram通知: 开启"
	else
		__defualt_color "pushplus/Telegram通知: 关闭"
	fi
	echo
	
	echo
	__red_color "Github在线编译CPU型号"
	echo `cat /proc/cpuinfo | grep name | cut -f2 -d: | uniq -c`
	echo
	echo -e "常见CPU类型及性能排行:
	Intel(R) Xeon(R) Platinum 8370C CPU @ 2.80GHz
	Intel(R) Xeon(R) Platinum 8272CL CPU @ 2.60GHz
	Intel(R) Xeon(R) Platinum 8171M CPU @ 2.60GHz
	Intel(R) Xeon(R) CPU E5-2673 v4 @ 2.30GHz
	Intel(R) Xeon(R) CPU E5-2673 v3 @ 2.40GHz"
	echo
	
	echo
	__red_color "系统空间使用情况"
	echo " 系统空间      类型   总数  已用  可用 使用率"
	echo "=============================================================="
	df -hT                                             
	echo "=============================================================="
	echo
	
	echo
	cd ${HOME_PATH}
	plugin_1="$(grep -Eo "CONFIG_PACKAGE_luci-app-.*=y|CONFIG_PACKAGE_luci-theme-.*=y" .config |grep -v 'INCLUDE\|_Proxy\|_static\|_dynamic' |sed 's/=y//' |sed 's/CONFIG_PACKAGE_//g')"
	plugin_2="$(echo "${plugin_1}" |sed 's/^/、/g' |sed 's/$/\"/g' |awk '$0=NR$0' |sed 's/^/__blue_color \"       /g')"
	echo "${plugin_2}" >plugin_info
	if [ -n "$(ls -A "${HOME_PATH}/plugin_info" 2>/dev/null)" ]; then
		__red_color "插件列表"
		chmod -Rf +x ${HOME_PATH}/plugin_info
		source ${HOME_PATH}/plugin_info
		rm -rf ${HOME_PATH}/plugin_info
		echo
	fi
}

################################################################################################################
# 插件列表
################################################################################################################
function update_plugin_list() {
	cd ${HOME_PATH}
	plugin_1="$(grep -Eo "CONFIG_PACKAGE_luci-app-.*=y|CONFIG_PACKAGE_luci-theme-.*=y" .config |grep -v 'INCLUDE\|_Proxy\|_static\|_dynamic' |sed 's/=y//' |sed 's/CONFIG_PACKAGE_//g')"
	plugin_2="$(echo "${plugin_1}" |sed 's/^/、/g' |awk '$0=NR$0')"
	echo "${plugin_2}" > ${HOME_PATH}/plugin_list
}

################################################################################################################
# 更新仓库
################################################################################################################
function update_repo() {
	local repo_path="${GITHUB_WORKSPACE}/repo"
	[[ -d "${repo_path}" ]] && rm -rf ${repo_path}

	cd ${GITHUB_WORKSPACE}	
	git clone https://github.com/${GITHUB_REPOSITORY}.git repo
	
	cd ${repo_path}
	
	# 更新COMPILE_YML文件中的matrix.target设置
	local compile_yml_target=$(grep 'target: \[' ${GITHUB_WORKSPACE}/.github/workflows/${COMPILE_YML} | sed 's/^[ ]*//g' |grep '^target' |cut -d '#' -f1 |sed 's/\[/\\&/' |sed 's/\]/\\&/') && echo "compile_yml_target=${compile_yml_target}"
	local build_yml_target=$(grep 'target: \[' ${GITHUB_WORKSPACE}/.github/workflows/${BUILD_YML}  |sed 's/^[ ]*//g' |grep '^target' |cut -d '#' -f1 |sed 's/\[/\\&/' |sed 's/\]/\\&/') && echo "build_yml_target=${build_yml_target}"
	if [[ -n "${compile_yml_target}" ]] && [[ -n "${build_yml_target}" ]] && [[ "${compile_yml_target}" != "${build_yml_target}" ]]; then
		ENABLE_UPDATE_REPO="true"
		sed -i "s/${compile_yml_target}/${build_yml_target}/g" ${repo_path}/.github/workflows/${COMPILE_YML} && echo "change compile target ${compile_yml_target} to ${build_yml_target}"
	fi

	# 更新settings.ini文件
	local settings_array=(SOURCE_BRANCH CONFIG_FILE FIRMWARE_TYPE NOTICE_TYPE UPLOAD_RELEASE UPLOAD_FIRMWARE UPLOAD_CONFIG ENABLE_CACHEWRTBUILD)
	for x in ${settings_array[*]}; do
		local settings_key="$(grep -E "${x}=" ${SETTINGS_FILE} |sed 's/^[ ]*//g' |grep -v '^#' | awk '{print $1}' | awk -F'=' '{print $1}')"
		local settings_val="$(grep -E "${x}=" ${SETTINGS_FILE} |sed 's/^[ ]*//g' |grep -v '^#' | awk '{print $1}' | awk -F'=' '{print $2}' | sed 's#"##g')"
		eval eval env_settings_val=\$$x
		if [[ -n "${settings_key}" ]]; then
			sed -i "s#${x}=\"${settings_val}\"#${x}=\"${env_settings_val}\"#g" ${SETTINGS_FILE}
		fi
	done
	if [[ "$(cat ${SETTINGS_FILE})" != "$(cat ${repo_path}/build/${MATRIX_TARGET}/config/settings.ini)" ]]; then
		ENABLE_UPDATE_REPO="true"
		cp -rf ${SETTINGS_FILE} ${repo_path}/build/${MATRIX_TARGET}/settings.ini
	fi
	
	# 更新.config文件
	# ${HOME_PATH}/scripts/diffconfig.sh > ${DIFFCONFIG_FILE}
	if [[ "$(cat ${DIFFCONFIG_FILE})" != "$(cat ${repo_path}/build/${MATRIX_TARGET}/config/${CONFIG_FILE})" ]]; then
		ENABLE_UPDATE_REPO="true"
		cp -rf ${DIFFCONFIG_FILE} ${repo_path}/build/${MATRIX_TARGET}/config/${CONFIG_FILE}
	fi
	
	# 更新插件列表
	update_plugin_list
	if [[ "$(cat ${HOME_PATH}/plugin_list)" != "$(cat ${repo_path}/build/${MATRIX_TARGET}/plugins)" ]]; then
		ENABLE_UPDATE_REPO="true"
		# 覆盖原plugin文件
		cp -f ${HOME_PATH}/plugin_list ${repo_path}/build/${MATRIX_TARGET}/plugins > /dev/null 2>&1
	fi
	
	# 提交commit，更新repo
	cd ${repo_path}
	local branch_head="$(git rev-parse --abbrev-ref HEAD)"
	if [[ "${ENABLE_UPDATE_REPO}" == "true" ]]; then
		git add .
		git commit -m "Update plugins and ${CONFIG_FILE}"
		git push --force "https://${REPO_TOKEN}@github.com/${GITHUB_REPOSITORY}" HEAD:${branch_head}
		__success_msg "Your branch is now up to latest."
	else
		__info_msg "Your branch is already up to date with origin/${branch_head}. Nothing to commit, working tree clean"
	fi
}

################################################################################################################
# 处理插件冲突
################################################################################################################
function resolve_conflictions() {
	cd ${HOME_PATH}
	echo
	echo "正在执行：判断插件有否冲突减少编译错误"
	make defconfig > /dev/null 2>&1
	rm -rf ${HOME_PATH}/CHONGTU && touch ${HOME_PATH}/CHONGTU
	echo "__blue_color \"					插件冲突信息\"" > ${HOME_PATH}/CHONGTU
	if [[ `grep -c "CONFIG_PACKAGE_luci-app-adblock-plus=y" ${HOME_PATH}/.config` -eq '1' ]]; then
		if [[ `grep -c "CONFIG_PACKAGE_luci-app-adblock=y" ${HOME_PATH}/.config` -eq '1' ]]; then
			sed -i 's/CONFIG_PACKAGE_luci-app-adblock=y/# CONFIG_PACKAGE_luci-app-adblock is not set/g' ${HOME_PATH}/.config
			sed -i 's/CONFIG_PACKAGE_adblock=y/# CONFIG_PACKAGE_adblock is not set/g' ${HOME_PATH}/.config
			sed -i '/luci-i18n-adblock/d' ${HOME_PATH}/.config
			echo "TIME r \"您同时选择luci-app-adblock-plus和luci-app-adblock，插件有依赖冲突，只能二选一，已删除luci-app-adblock\"" >>CHONGTU
			echo "" >>CHONGTU
		fi
	fi
	if [[ `grep -c "CONFIG_PACKAGE_luci-app-advanced=y" ${HOME_PATH}/.config` -eq '1' ]]; then
		if [[ `grep -c "CONFIG_PACKAGE_luci-app-fileassistant=y" ${HOME_PATH}/.config` -eq '1' ]]; then
			sed -i 's/CONFIG_PACKAGE_luci-app-fileassistant=y/# CONFIG_PACKAGE_luci-app-fileassistant is not set/g' ${HOME_PATH}/.config
			echo "TIME r \"您同时选择luci-app-advanced和luci-app-fileassistant，luci-app-advanced已附带luci-app-fileassistant，所以删除了luci-app-fileassistant\"" >>CHONGTU
			echo "" >>CHONGTU
		fi
	fi
	if [[ `grep -c "CONFIG_PACKAGE_luci-app-docker=y" ${HOME_PATH}/.config` -eq '1' ]]; then
		if [[ `grep -c "CONFIG_PACKAGE_luci-app-dockerman=y" ${HOME_PATH}/.config` -eq '1' ]]; then
			sed -i 's/CONFIG_PACKAGE_luci-app-docker=y/# CONFIG_PACKAGE_luci-app-docker is not set/g' ${HOME_PATH}/.config
			sed -i 's/CONFIG_PACKAGE_luci-i18n-docker-zh-cn=y/# CONFIG_PACKAGE_luci-i18n-docker-zh-cn is not set/g' ${HOME_PATH}/.config
			echo "TIME r \"您同时选择luci-app-docker和luci-app-dockerman，插件有冲突，相同功能插件只能二选一，已删除luci-app-docker\"" >>CHONGTU
			echo "" >>CHONGTU
		fi
	fi
	if [[ `grep -c "CONFIG_PACKAGE_luci-app-dockerman=y" ${HOME_PATH}/.config` -eq '0' ]] || [[ `grep -c "CONFIG_PACKAGE_luci-app-docker=y" ${HOME_PATH}/.config` -eq '0' ]]; then
		echo "# CONFIG_PACKAGE_luci-lib-docker is not set" >> ${HOME_PATH}/.config
		echo "# CONFIG_PACKAGE_luci-i18n-dockerman-zh-cn is not set" >> ${HOME_PATH}/.config
		echo "# CONFIG_PACKAGE_docker is not set" >> ${HOME_PATH}/.config
		echo "# CONFIG_PACKAGE_dockerd is not set" >> ${HOME_PATH}/.config
		echo "# CONFIG_PACKAGE_runc is not set" >> ${HOME_PATH}/.config
	fi
	if [[ `grep -c "CONFIG_PACKAGE_luci-app-kodexplorer=y" ${HOME_PATH}/.config` -eq '1' ]]; then
		if [[ `grep -c "CONFIG_PACKAGE_luci-app-vnstat=y" ${HOME_PATH}/.config` -eq '1' ]]; then
			sed -i 's/CONFIG_PACKAGE_luci-app-vnstat=y/# CONFIG_PACKAGE_luci-app-vnstat is not set/g' ${HOME_PATH}/.config
			sed -i 's/CONFIG_PACKAGE_vnstat=y/# CONFIG_PACKAGE_vnstat is not set/g' ${HOME_PATH}/.config
			sed -i 's/CONFIG_PACKAGE_vnstati=y/# CONFIG_PACKAGE_vnstati is not set/g' ${HOME_PATH}/.config
			sed -i 's/CONFIG_PACKAGE_libgd=y/# CONFIG_PACKAGE_libgd is not set/g' ${HOME_PATH}/.config
			sed -i '/luci-i18n-vnstat/d' ${HOME_PATH}/.config
			echo "TIME r \"您同时选择luci-app-kodexplorer和luci-app-vnstat，插件有依赖冲突，只能二选一，已删除luci-app-vnstat\"" >>CHONGTU
			echo "" >>CHONGTU
		fi
	fi
	if [[ `grep -c "CONFIG_PACKAGE_wpad-openssl=y" ${HOME_PATH}/.config` -eq '1' ]]; then
		if [[ `grep -c "CONFIG_PACKAGE_wpad=y" ${HOME_PATH}/.config` -eq '1' ]]; then
			sed -i 's/CONFIG_PACKAGE_wpad=y/# CONFIG_PACKAGE_wpad is not set/g' ${HOME_PATH}/.config
		fi
	fi
	if [[ `grep -c "CONFIG_PACKAGE_luci-i18n-qbittorrent-zh-cn=y" ${HOME_PATH}/.config` -eq '0' ]]; then
		sed -i 's/CONFIG_PACKAGE_luci-app-qbittorrent_static=y/# CONFIG_PACKAGE_luci-app-qbittorrent_static is not set/g' ${HOME_PATH}/.config
		sed -i 's/CONFIG_DEFAULT_luci-app-qbittorrent=y/# CONFIG_DEFAULT_luci-app-qbittorrent is not set/g' ${HOME_PATH}/.config
		sed -i 's/CONFIG_PACKAGE_luci-app-qbittorrent_dynamic=y/# CONFIG_PACKAGE_luci-app-qbittorrent_dynamic is not set/g' ${HOME_PATH}/.config
		sed -i 's/CONFIG_PACKAGE_qBittorrent-static=y/# CONFIG_PACKAGE_qBittorrent-static is not set/g' ${HOME_PATH}/.config
		sed -i 's/CONFIG_PACKAGE_qbittorrent=y/# CONFIG_PACKAGE_qbittorrent is not set/g' ${HOME_PATH}/.config
	fi
	if [[ `grep -c "CONFIG_PACKAGE_luci-app-samba4=y" ${HOME_PATH}/.config` -eq '1' ]]; then
		if [[ `grep -c "CONFIG_PACKAGE_luci-app-samba=y" ${HOME_PATH}/.config` -eq '1' ]]; then
			sed -i 's/CONFIG_PACKAGE_autosamba=y/# CONFIG_PACKAGE_autosamba is not set/g' ${HOME_PATH}/.config
			sed -i 's/CONFIG_PACKAGE_luci-app-samba=y/# CONFIG_PACKAGE_luci-app-samba is not set/g' ${HOME_PATH}/.config
			sed -i 's/CONFIG_PACKAGE_luci-i18n-samba-zh-cn=y/# CONFIG_PACKAGE_luci-i18n-samba-zh-cn is not set/g' ${HOME_PATH}/.config
			sed -i 's/CONFIG_PACKAGE_samba36-server=y/# CONFIG_PACKAGE_samba36-server is not set/g' ${HOME_PATH}/.config
			echo "TIME r \"您同时选择luci-app-samba和luci-app-samba4，插件有冲突，相同功能插件只能二选一，已删除luci-app-samba\"" >>CHONGTU
			echo "" >>CHONGTU
		fi
	elif [[ `grep -c "CONFIG_PACKAGE_samba4-server=y" ${HOME_PATH}/.config` -eq '1' ]]; then
		echo "# CONFIG_PACKAGE_samba4-admin is not set" >> ${HOME_PATH}/.config
		echo "# CONFIG_PACKAGE_samba4-client is not set" >> ${HOME_PATH}/.config
		echo "# CONFIG_PACKAGE_samba4-libs is not set" >> ${HOME_PATH}/.config
		echo "# CONFIG_PACKAGE_samba4-server is not set" >> ${HOME_PATH}/.config
		echo "# CONFIG_PACKAGE_samba4-utils is not set" >> ${HOME_PATH}/.config
	fi
	if [[ `grep -c "CONFIG_PACKAGE_luci-app-sfe=y" ${HOME_PATH}/.config` -eq '1' ]]; then
		if [[ `grep -c "CONFIG_PACKAGE_luci-app-flowoffload=y" ${HOME_PATH}/.config` -eq '1' ]]; then
			sed -i 's/CONFIG_DEFAULT_luci-app-flowoffload=y/# CONFIG_DEFAULT_luci-app-flowoffload is not set/g' ${HOME_PATH}/.config
			sed -i 's/CONFIG_PACKAGE_luci-app-flowoffload=y/# CONFIG_PACKAGE_luci-app-flowoffload is not set/g' ${HOME_PATH}/.config
			sed -i 's/CONFIG_PACKAGE_luci-i18n-flowoffload-zh-cn=y/# CONFIG_PACKAGE_luci-i18n-flowoffload-zh-cn is not set/g' ${HOME_PATH}/.config
			echo "TIME r \"提示：您同时选择了luci-app-sfe和luci-app-flowoffload，两个ACC网络加速，已删除luci-app-flowoffload\"" >>CHONGTU
			echo "" >>CHONGTU
		fi
	fi
	if [[ `grep -c "CONFIG_PACKAGE_luci-app-ssr-plus=y" ${HOME_PATH}/.config` -ge '1' ]]; then
		if [[ `grep -c "CONFIG_PACKAGE_luci-app-cshark=y" ${HOME_PATH}/.config` -eq '1' ]]; then
			sed -i 's/CONFIG_PACKAGE_luci-app-cshark=y/# CONFIG_PACKAGE_luci-app-cshark is not set/g' ${HOME_PATH}/.config
			sed -i 's/CONFIG_PACKAGE_cshark=y/# CONFIG_PACKAGE_cshark is not set/g' ${HOME_PATH}/.config
			sed -i 's/CONFIG_PACKAGE_libustream-mbedtls=y/# CONFIG_PACKAGE_libustream-mbedtls is not set/g' ${HOME_PATH}/.config
			echo "TIME r \"您同时选择luci-app-ssr-plus和luci-app-cshark，插件有依赖冲突，只能二选一，已删除luci-app-cshark\"" >>CHONGTU
			echo "" >>CHONGTU
		fi
	fi
	if [[ `grep -c "CONFIG_PACKAGE_luci-app-turboacc_INCLUDE_SHORTCUT_FE_CM=y" ${HOME_PATH}/.config` -ge '1' ]]; then
		if [[ `grep -c "CONFIG_PACKAGE_luci-app-turboacc_INCLUDE_SHORTCUT_FE=y" ${HOME_PATH}/.config` -eq '1' ]]; then
			sed -i 's/CONFIG_PACKAGE_luci-app-turboacc_INCLUDE_SHORTCUT_FE=y/# CONFIG_PACKAGE_luci-app-turboacc_INCLUDE_SHORTCUT_FE is not set/g' ${HOME_PATH}/.config
			sed -i 's/CONFIG_PACKAGE_kmod-fast-classifier=y/# CONFIG_PACKAGE_kmod-fast-classifier is not set/g' ${HOME_PATH}/.config
			echo "TIME r \"luci-app-turboacc同时选择Include Shortcut-FE CM和Include Shortcut-FE，有冲突，只能二选一，已删除Include Shortcut-FE\"" >>CHONGTU
			echo "" >>CHONGTU
		fi
	fi
	if [[ `grep -c "CONFIG_PACKAGE_luci-app-unblockneteasemusic=y" ${HOME_PATH}/.config` -eq '1' ]]; then
		if [[ `grep -c "CONFIG_PACKAGE_luci-app-unblockneteasemusic-go=y" ${HOME_PATH}/.config` -eq '1' ]]; then
			sed -i 's/CONFIG_PACKAGE_luci-app-unblockneteasemusic-go=y/# CONFIG_PACKAGE_luci-app-unblockneteasemusic-go is not set/g' ${HOME_PATH}/.config
			echo "TIME r \"您选择了luci-app-unblockneteasemusic-go，会和luci-app-unblockneteasemusic冲突导致编译错误，已删除luci-app-unblockneteasemusic-go\"" >>CHONGTU
			echo "" >>CHONGTU
		fi
		if [[ `grep -c "CONFIG_PACKAGE_luci-app-unblockmusic=y" ${HOME_PATH}/.config` -eq '1' ]]; then
			sed -i 's/CONFIG_PACKAGE_luci-app-unblockmusic=y/# CONFIG_PACKAGE_luci-app-unblockmusic is not set/g' ${HOME_PATH}/.config
			echo "TIME r \"您选择了luci-app-unblockmusic，会和luci-app-unblockneteasemusic冲突导致编译错误，已删除luci-app-unblockmusic\"" >>CHONGTU
			echo "" >>CHONGTU
		fi
	fi
	if [[ `grep -c "CONFIG_PACKAGE_dnsmasq-full=y" ${HOME_PATH}/.config` -eq '1' ]]; then
		if [[ `grep -c "CONFIG_PACKAGE_dnsmasq=y" ${HOME_PATH}/.config` -eq '1' ]] || [[ `grep -c "CONFIG_PACKAGE_dnsmasq-dhcpv6=y" ${HOME_PATH}/.config` -eq '1' ]]; then
			sed -i 's/CONFIG_PACKAGE_dnsmasq=y/# CONFIG_PACKAGE_dnsmasq is not set/g' ${HOME_PATH}/.config
			sed -i 's/CONFIG_PACKAGE_dnsmasq-dhcpv6=y/# CONFIG_PACKAGE_dnsmasq-dhcpv6 is not set/g' ${HOME_PATH}/.config
		fi
		if [[ `grep -c "CONFIG_PACKAGE_dnsmasq_full_conntrack=y" ${HOME_PATH}/.config` -eq '1' ]]; then
			sed -i 's/CONFIG_PACKAGE_dnsmasq_full_conntrack=y/# CONFIG_PACKAGE_dnsmasq_full_conntrack is not set/g' ${HOME_PATH}/.config
		fi
	fi
	if [[ `grep -c "CONFIG_PACKAGE_wpad-openssl=y" ${HOME_PATH}/.config` -eq '1' ]]; then
		if [[ `grep -c "CONFIG_PACKAGE_wpad=y" ${HOME_PATH}/.config` -eq '1' ]]; then
			sed -i 's/CONFIG_PACKAGE_wpad=y/# CONFIG_PACKAGE_wpad is not set/g' ${HOME_PATH}/.config
		fi
	fi
	if [[ `grep -c "CONFIG_PACKAGE_luci-theme-argon=y" ${HOME_PATH}/.config` -eq '1' ]]; then
		if [[ `grep -c "CONFIG_PACKAGE_luci-theme-argon_new=y" ${HOME_PATH}/.config` -eq '1' ]]; then
			sed -i 's/CONFIG_PACKAGE_luci-theme-argon_new=y/# CONFIG_PACKAGE_luci-theme-argon_new is not set/g' ${HOME_PATH}/.config
			echo "TIME r \"您同时选择luci-theme-argon和luci-theme-argon_new，插件有冲突，相同功能插件只能二选一，已删除luci-theme-argon_new\"" >>CHONGTU
			echo "" >>CHONGTU
		fi
		if [[ `grep -c "CONFIG_PACKAGE_luci-theme-argonne=y" ${HOME_PATH}/.config` -eq '1' ]]; then
			sed -i 's/CONFIG_PACKAGE_luci-theme-argonne=y/# CONFIG_PACKAGE_luci-theme-argonne is not set/g' ${HOME_PATH}/.config
			echo "TIME r \"您同时选择luci-theme-argon和luci-theme-argonne，插件有冲突，相同功能插件只能二选一，已删除luci-theme-argonne\"" >>CHONGTU
			echo "" >>CHONGTU
		fi
		if [[ `grep -c "CONFIG_PACKAGE_luci-app-argon-config=y" ${HOME_PATH}/.config` -eq '0' ]] && [[ `grep -c "CONFIG_TARGET_x86=y" ${HOME_PATH}/.config` -eq '1' ]]; then
			sed -i '/argon=y/i\CONFIG_PACKAGE_luci-app-argon-config=y' "${HOME_PATH}/.config"
		fi
	fi
	if [[ `grep -c "CONFIG_PACKAGE_luci-theme-argon=y" ${HOME_PATH}/.config` -eq '1' ]]; then
		if [[ `grep -c "CONFIG_PACKAGE_luci-app-argon-config=y" ${HOME_PATH}/.config` == '0' ]]; then
			sed -i '/luci-app-argon-config/d' ${HOME_PATH}/.config
			echo -e "\nCONFIG_PACKAGE_luci-app-argon-config=y" >> ${HOME_PATH}/.config
		fi
	else
		sed -i '/luci-app-argon-config/d' ${HOME_PATH}/.config
		echo -e "\n# CONFIG_PACKAGE_luci-app-argon-config is not set" >> ${HOME_PATH}/.config
	fi

	if [[ `grep -c "CONFIG_TARGET_x86=y" ${HOME_PATH}/.config` -eq '1' ]] || [[ `grep -c "CONFIG_TARGET_rockchip=y" ${HOME_PATH}/.config` -eq '1' ]] || [[ `grep -c "CONFIG_TARGET_bcm27xx=y" ${HOME_PATH}/.config` -eq '1' ]]; then
		sed -i '/IMAGES_GZIP/d' "${HOME_PATH}/.config"
		echo -e "\nCONFIG_TARGET_IMAGES_GZIP=y" >> "${HOME_PATH}/.config"
		sed -i '/CONFIG_PACKAGE_openssh-sftp-server/d' "${HOME_PATH}/.config"
		echo -e "\nCONFIG_PACKAGE_openssh-sftp-server=y" >> "${HOME_PATH}/.config"
	fi
	if [[ `grep -c "CONFIG_TARGET_mxs=y" ${HOME_PATH}/.config` -eq '1' ]] || [[ `grep -c "CONFIG_TARGET_sunxi=y" ${HOME_PATH}/.config` -eq '1' ]] || [[ `grep -c "CONFIG_TARGET_zynq=y" ${HOME_PATH}/.config` -eq '1' ]]; then
		sed -i '/IMAGES_GZIP/d' "${HOME_PATH}/.config"
		echo -e "\nCONFIG_TARGET_IMAGES_GZIP=y" >> "${HOME_PATH}/.config"
		sed -i '/CONFIG_PACKAGE_openssh-sftp-server/d' "${HOME_PATH}/.config"
		echo -e "\nCONFIG_PACKAGE_openssh-sftp-server=y" >> "${HOME_PATH}/.config"
	fi
	if [[ `grep -c "CONFIG_TARGET_armvirt=y" ${HOME_PATH}/.config` -eq '1' ]]; then
		sed -i 's/CONFIG_PACKAGE_luci-app-autoupdate=y/# CONFIG_PACKAGE_luci-app-autoupdate is not set/g' ${HOME_PATH}/.config
		export REGULAR_UPDATE="false"
		echo "REGULAR_UPDATE=false" >> ${GITHUB_ENV}
		sed -i '/CONFIG_PACKAGE_openssh-sftp-server/d' "${HOME_PATH}/.config"
		echo -e "\nCONFIG_PACKAGE_openssh-sftp-server=y" >> "${HOME_PATH}/.config"
	fi
	if [[ `grep -c "CONFIG_TARGET_ROOTFS_EXT4FS=y" ${HOME_PATH}/.config` -eq '1' ]]; then
		if [[ `grep -c "CONFIG_TARGET_ROOTFS_PARTSIZE" ${HOME_PATH}/.config` -eq '0' ]]; then
			sed -i '/CONFIG_TARGET_ROOTFS_PARTSIZE/d' ${HOME_PATH}/.config > /dev/null 2>&1
			echo -e "\nCONFIG_TARGET_ROOTFS_PARTSIZE=950" >> ${HOME_PATH}/.config
		fi
		egrep -o "CONFIG_TARGET_ROOTFS_PARTSIZE=+.*?[0-9]" ${HOME_PATH}/.config > ${HOME_PATH}/EXT4PARTSIZE
		sed -i 's|CONFIG_TARGET_ROOTFS_PARTSIZE=||g' ${HOME_PATH}/EXT4PARTSIZE
		PARTSIZE="$(cat EXT4PARTSIZE)"
		if [[ "${PARTSIZE}" -lt "950" ]];then
			sed -i '/CONFIG_TARGET_ROOTFS_PARTSIZE/d' ${HOME_PATH}/.config > /dev/null 2>&1
			echo -e "\nCONFIG_TARGET_ROOTFS_PARTSIZE=950" >> ${HOME_PATH}/.config
			echo "__green_color \" \"" > ${HOME_PATH}/EXT4
			echo "__red_color \"EXT4提示：请注意，您选择了ext4安装的固件格式,而检测到您的分配的固件系统分区过小\"" >> ${HOME_PATH}/EXT4
			echo "__yellow_color \"为避免编译出错,建议修改成950或者以上比较好,已帮您修改成950M\"" >> ${HOME_PATH}/EXT4
			echo "__green_color \" \"" >> ${HOME_PATH}/EXT4
		fi
		rm -rf ${HOME_PATH}/EXT4PARTSIZE
	fi
	if [[ `grep -c "CONFIG_PACKAGE_antfs-mount=y" ${HOME_PATH}/.config` -eq '1' ]]; then
		if [[ `grep -c "CONFIG_PACKAGE_ntfs3-mount=y" ${HOME_PATH}/.config` -eq '1' ]]; then
			sed -i 's/CONFIG_PACKAGE_antfs-mount=y/# CONFIG_PACKAGE_antfs-mount is not set/g' ${HOME_PATH}/.config
		fi
	fi
	if [[ `grep -c "CONFIG_PACKAGE_dnsmasq-full=y" ${HOME_PATH}/.config` -eq '1' ]]; then
		if [[ `grep -c "CONFIG_PACKAGE_dnsmasq=y" ${HOME_PATH}/.config` -eq '1' ]] || [[ `grep -c "CONFIG_PACKAGE_dnsmasq-dhcpv6=y" ${HOME_PATH}/.config` -eq '1' ]]; then
			sed -i 's/CONFIG_PACKAGE_dnsmasq=y/# CONFIG_PACKAGE_dnsmasq is not set/g' ${HOME_PATH}/.config
			sed -i 's/CONFIG_PACKAGE_dnsmasq-dhcpv6=y/# CONFIG_PACKAGE_dnsmasq-dhcpv6 is not set/g' ${HOME_PATH}/.config
		fi
	fi
	if [[ `grep -c "CONFIG_PACKAGE_libustream-wolfssl=y" ${HOME_PATH}/.config` -eq '1' ]]; then
		if [[ `grep -c "CONFIG_PACKAGE_libustream-openssl=y" ${HOME_PATH}/.config` -eq '1' ]]; then
			sed -i 's/CONFIG_PACKAGE_libustream-wolfssl=y/# CONFIG_PACKAGE_libustream-wolfssl is not set/g' ${HOME_PATH}/.config
		fi
	fi
}

################################################################################################################
# 整理固件
################################################################################################################
function organize_firmware() {
	cd ${FIRMWARE_PATH}
	echo "files under ${FIRMWARE_PATH}:"
	ls -l ${FIRMWARE_PATH}

	# 清理无关文件
	__yellow_color "开始清理无关文件..."
	for X in $(cat ${CLEAR_FILE} | sed '/^#.*/d'); do		
		rm -rf *"${X}"* > /dev/null 2>&1
		__info_msg "delete ${X}"
	done
	rm -rf packages > /dev/null 2>&1
	rm -rf ${CLEAR_FILE}

	__yellow_color "开始准备固件自动更新相关固件..."
	[[ ! -d ${AUTOUPDATE_PATH} ]] && mkdir -p ${AUTOUPDATE_PATH} || rm -rf ${AUTOUPDATE_PATH}/*
	case "${TARGET_BOARD}" in
	x86)
		if [[ "${FIRMWARE_TYPE}" == "lxc" ]]; then
			local firmware_rootfs_img="$(ls -1 |grep -Eo ".*squashfs.*rootfs.*img.gz")"
			[[ -f ${firmware_rootfs_img} ]] && {
				local rootfs_img_md5="$(md5sum ${firmware_rootfs_img} |cut -c1-3)$(sha256sum ${firmware_rootfs_img} |cut -c1-3)"
				cp -rf ${firmware_rootfs_img} ${AUTOUPDATE_PATH}/${AutoBuild_Rootfs}-${rootfs_img_md5}${Firmware_sfx}
				__info_msg "copy ${firmware_rootfs_img} to ${AUTOUPDATE_PATH}/${AutoBuild_Rootfs}-${rootfs_img_md5}${Firmware_sfx}"
			}
			local firmware_rootfs_tar="$(ls -1 |grep -Eo ".*squashfs.*rootfs.*tar.gz")"
			[[ -f ${firmware_rootfs_tar} ]] && {
				local rootfs_tar_md5="$(md5sum ${firmware_rootfs_tar} |cut -c1-3)$(sha256sum ${firmware_rootfs_tar} |cut -c1-3)"
				cp -rf ${firmware_rootfs_tar} ${AUTOUPDATE_PATH}/${AutoBuild_Rootfs}-${rootfs_tar_md5}${Rootfs_sfx}
				__info_msg "copy ${firmware_rootfs_tar} to ${AUTOUPDATE_PATH}/${AutoBuild_Rootfs}-${rootfs_tar_md5}${Rootfs_sfx}"
			}
		elif [[ `ls -1 | grep -c "efi"` -ge '1' ]]; then
			local firmware_uefi="$(ls -1 |grep -Eo ".*squashfs.*efi.*img.gz")"
			[[ -f ${firmware_uefi} ]] && {
				local uefimd5="$(md5sum ${firmware_uefi} |cut -c1-3)$(sha256sum ${firmware_uefi} |cut -c1-3)"
				cp -rf "${firmware_uefi}" "${AUTOUPDATE_PATH}/${AutoBuild_Uefi}-${uefimd5}${Firmware_SFX}"
				__info_msg "copy ${firmware_uefi} to ${AUTOUPDATE_PATH}/${AutoBuild_Uefi}-${uefimd5}${Firmware_sfx}"
			}
		elif [[ `ls -1 | grep -c "squashfs"` -ge '1' ]]; then
			local firmware_legacy="$(ls -1 |grep -Eo ".*squashfs.*img.gz" |grep -v ".vm\|.vb\|.vh\|.qco\|efi\|root")"
			[[ -f ${firmware_legacy} ]] && {
				local legacymd5="$(md5sum ${firmware_legacy} |cut -c1-3)$(sha256sum ${firmware_legacy} |cut -c1-3)"
				cp -rf "${firmware_legacy}" "${AUTOUPDATE_PATH}/${AutoBuild_Legacy}-${legacymd5}${Firmware_SFX}"
				__info_msg "copy ${firmware_legacy} to ${AUTOUPDATE_PATH}/${AutoBuild_Legacy}-${legacymd5}${Firmware_sfx}"
			}
		else
			__error_msg "没有找到squashfs格式的固件！"
		fi
	;;
	*)
		if [[ `ls -1 | grep -c "sysupgrade"` -ge '1' ]]; then
			local firmware_sysupgrade="$(ls -1 |grep -Eo ".*${TARGET_PROFILE}.*sysupgrade.*${Firmware_SFX}" |grep -v "rootfs\|ext4\|factory")"
		else
			local firmware_sysupgrade="$(ls -1 |grep -Eo ".*${TARGET_PROFILE}.*squashfs.*${Firmware_SFX}" |grep -v "rootfs\|ext4\|factory")"
		fi
		if [[ -f "${firmware_sysupgrade}" ]]; then
			local sysupgrademd5="$(md5sum ${firmware_sysupgrade} | cut -c1-3)$(sha256sum ${firmware_sysupgrade} | cut -c1-3)"
			cp -rf "${firmware_sysupgrade}" "${AUTOUPDATE_PATH}/${AutoBuild_Firmware}-${sysupgrademd5}${Firmware_SFX}"
			__info_msg "copy ${firmware_sysupgrade} to ${AUTOUPDATE_PATH}/${AutoBuild_Firmware}-${sysupgrademd5}${Firmware_sfx}"
		else
			__error_msg "没有找到可用的sysupgrade格式${Firmware_SFX}固件！"
		fi
	;;
	esac

	__yellow_color "开始准备固件发布文件..."
	__info_msg " 准备ipk压缩包"
	if [[ "${UPLOAD_FIRMWARE}" == "true" || "${UPLOAD_RELEASE}" == "true" ]]; then
		[[ ! -d ${FIRMWARE_PATH}/ipk ]] && mkdir -p ${FIRMWARE_PATH}/ipk || rm -rf ${FIRMWARE_PATH}/ipk/*
		cp -rf $(find ${HOME_PATH}/bin/packages/ -type f -name "*.ipk") ipk/ && sync
		sudo tar -czf ipk.tar.gz ipk && sync && sudo rm -rf ipk
	fi
	__info_msg "重命名固件名称"
	if [[ `ls -1 | grep -c "armvirt"` -eq '0' ]]; then
		rename -v "s/^openwrt/${FIRMWARE_DATE}-${SOURCE}-${LUCI_EDITION}-${LINUX_KERNEL}/" *
	fi
	
	release_info	
}

################################################################################################################
# 准备发布固件页面信息显示
################################################################################################################
release_info() {
	cd ${MATRIX_TARGET_PATH}
	__yellow_color "开始准备固件发布信息..."
	local releaseinfo_md="${RELEASEINFO_FILE}"
	local diy_part_ipaddr=`awk '{print $3}' ${MATRIX_TARGET_PATH}/$DIY_PART_SH | awk -F= '$1 == "network.lan.ipaddr" {print $2}' | sed "s/'//g" 2>/dev/null`
	local release_ipaddr=${diy_part_ipaddr:-192.168.1.1}
	
	sed -i "s#release_device#${TARGET_PROFILE}#" ${MATRIX_TARGET_PATH}/${releaseinfo_md} > /dev/null 2>&1
	sed -i "s#default_ip#${release_ipaddr}#" ${MATRIX_TARGET_PATH}/${releaseinfo_md} > /dev/null 2>&1
	sed -i "s#default_password#-" ${MATRIX_TARGET_PATH}/${releaseinfo_md} > /dev/null 2>&1
	sed -i "s#release_source#${LUCI_EDITION}-${SOURCE}#" ${MATRIX_TARGET_PATH}/${releaseinfo_md} > /dev/null 2>&1
	sed -i "s#release_kernel#${KERNEL_PATCHVER}#" ${MATRIX_TARGET_PATH}/${releaseinfo_md} > /dev/null 2>&1
	sed -i "s#repository#${GITHUB_REPOSITORY}" ${MATRIX_TARGET_PATH}/${releaseinfo_md} > /dev/null 2>&1
	sed -i "s#matrixtarget#${MATRIX_TARGET}" ${MATRIX_TARGET_PATH}/${releaseinfo_md} > /dev/null 2>&1

	cat ${MATRIX_TARGET_PATH}/${releaseinfo_md} > /dev/null 2>&1
}

################################################################################################################
# 解锁固件分区：Bootloader、Bdata、factory、reserved0，ramips系列路由器专用
################################################################################################################
function unlock_bootloader() {
echo " target/linux/${TARGET_BOARD}/dts/${TARGET_SUBTARGET}_${TARGET_PROFILE}.dts"
if [[ ${TARGET_BOARD} == "ramips" ]]; then
	sed -i "/read-only;/d" target/linux/${TARGET_BOARD}/dts/${TARGET_SUBTARGET}_${TARGET_PROFILE}.dts
	if [[ `grep -c "read-only;" target/linux/${TARGET_BOARD}/dts/${TARGET_SUBTARGET}_${TARGET_PROFILE}.dts` -eq '0' ]]; then
		__success_msg "固件分区已经解锁！"
		echo "UNLOCK=true" >> ${GITHUB_ENV}
	else
		__error_msg "固件分区解锁失败！"
	fi
else
	__warning_msg "非ramips系列，暂不支持！"
fi
}
