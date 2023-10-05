#!/bin/bash

RESET_COLOR="\e[0m"
RED_COLOR="\e[31m"
GREEN_COLOR="\e[32m"
YELLOW_COLOR="\e[33m"
BLUE_COLOR="\e[34m"
MAGENTA_COLOR="\e[35m"
CYAN_COLOR="\e[36m"
WHITE_COLOR="\e[37m"

function __error_msg() {
	echo -e "${RED_COLOR}[ERROR]${RESET_COLOR} $*"
}
function __success_msg() {
	echo -e "${GREEN_COLOR}[SUCCESS]${RESET_COLOR} $*"
}
function __warning_msg() {
	echo -e "${YELLOW_COLOR}[WARNING]${RESET_COLOR} $*"
}
function __info_msg() {
	echo -e "${CYAN_COLOR}[INFO]${RESET_COLOR} $*"
}
function __red_color() {
	echo -e "${RED_COLOR}$*${RESET_COLOR}"
}
function __green_color() {
	echo -e "${GREEN_COLOR}$*${RESET_COLOR}"
}
function __yellow_color() {
	echo -e "${YELLOW_COLOR}$*${RESET_COLOR}"
}
function __blue_color() {
	echo -e "${BLUE_COLOR}$*${RESET_COLOR}"
}
function __magenta_color() {
	echo -e "${MAGENTA_COLOR}$*${RESET_COLOR}"
}
function __cyan_color() {
	echo -e "${CYAN_COLOR}$*${RESET_COLOR}"
}
function __white_color() {
	echo -e "${WHITE_COLOR}$*${RESET_COLOR}"
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
	echo ENABLE_REPO_UPDATE="false" >> ${GITHUB_ENV}
	echo GITHUB_API="zzz_api" >> ${GITHUB_ENV}
	
	# 日期时间
	echo COMPILE_DATE_MD="$(date +%m.%d)" >> ${GITHUB_ENV}
	echo COMPILE_DATE_HM="$(date +%Y%m%d%H%M)" >> ${GITHUB_ENV}
	echo COMPILE_DATE_HMS="$(date +%Y%m%d%H%M%S)" >> ${GITHUB_ENV}
	echo COMPILE_DATE_CN="$(date +%Y年%m月%d号%H时%M分)" >> ${GITHUB_ENV}
	echo COMPILE_DATE_STAMP="$(date -d "$(date +'%Y-%m-%d %H:%M:%S')" +%s)" >> ${GITHUB_ENV}
	
	# 路径
	echo HOME_PATH="${GITHUB_WORKSPACE}/openwrt" >> ${GITHUB_ENV}
	echo BIN_PATH="${GITHUB_WORKSPACE}/openwrt/bin" >> ${GITHUB_ENV}
	echo AUTOUPDATE_PATH="${GITHUB_WORKSPACE}/openwrt/bin/autoupdate" >> ${GITHUB_ENV}
	echo FEEDS_PATH="${GITHUB_WORKSPACE}/openwrt/feeds" >> ${GITHUB_ENV}
	echo BUILD_PATH="${GITHUB_WORKSPACE}/openwrt/build" >> ${GITHUB_ENV}
	echo COMMON_PATH="${GITHUB_WORKSPACE}/openwrt/build/common" >> ${GITHUB_ENV}
	echo MATRIX_TARGET_PATH="${GITHUB_WORKSPACE}/openwrt/build/${MATRIX_TARGET}" >> ${GITHUB_ENV}
	echo CONFIG_PATH="${GITHUB_WORKSPACE}/openwrt/build/${MATRIX_TARGET}/config" >> ${GITHUB_ENV}
	
	# 文件
	echo DIFFCONFIG_TXT="${GITHUB_WORKSPACE}/diffconfig.txt" >> ${GITHUB_ENV}
	echo RELEASEINFO_MD="${GITHUB_WORKSPACE}/openwrt/build/${MATRIX_TARGET}/releaseinfo.md" >> ${GITHUB_ENV}
	echo SETTINGS_INI="${GITHUB_WORKSPACE}/openwrt/build/${MATRIX_TARGET}/settings.ini" >> ${GITHUB_ENV}
	echo FILES_TO_CLEAR="${GITHUB_WORKSPACE}/openwrt/default_clear" >> ${GITHUB_ENV}
	echo CONFFLICTIONS="${GITHUB_WORKSPACE}/openwrt/confflictions" >> ${GITHUB_ENV}
	
	# https://github.com/coolsnowwolf/lede/tree/master/package/base-files/files
	echo FILES_PATH="${GITHUB_WORKSPACE}/openwrt/package/base-files/files" >> ${GITHUB_ENV}
	echo FILE_DEFAULT_UCI="${GITHUB_WORKSPACE}/openwrt/package/base-files/files/etc/default_uci" >> ${GITHUB_ENV}
	echo FILES_TO_DELETE="${GITHUB_WORKSPACE}/openwrt/package/base-files/files/etc/default_delete" >> ${GITHUB_ENV}
	echo FILENAME_DEFAULT_UCI="default_uci" >> ${GITHUB_ENV}
	echo FILENAME_DEFAULT_SETTINGS="default_settings" >> ${GITHUB_ENV}
	echo FILENAME_DEFAULT_RUNONCE="default_settings_runonce" >> ${GITHUB_ENV}
	echo FILENAME_CONFIG_GEN="config_generate" >> ${GITHUB_ENV}
	echo FILENAME_TO_DELETE="default_delete" >> ${GITHUB_ENV}
}

################################################################################################################
# 编译开始通知
################################################################################################################
function notice_begin() {
	if [[ "${NOTICE_TYPE}" == "TG" ]]; then
		curl -k --data chat_id="${TELEGRAM_CHAT_ID}" --data "text=🎉 主人：您正在使用【${GITHUB_REPOSITORY}】仓库【${MATRIX_TARGET}】文件夹编译【${LUCI_EDITION}-${SOURCE}】固件,请耐心等待...... 😋" "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage"
	elif [[ "${NOTICE_TYPE}" == "PUSH" ]]; then
		curl -k --data token="${PUSH_PLUS_TOKEN}" --data title="开始编译【${SOURCE}-${MATRIX_TARGET}】" --data "content=🎉 主人：您正在使用【${GITHUB_REPOSITORY}】仓库【${MATRIX_TARGET}】文件夹编译【${LUCI_EDITION}-${SOURCE}】固件,请耐心等待...... 😋💐" "http://www.pushplus.plus/send"
	fi
}

################################################################################################################
# 编译完成通知
################################################################################################################
function notice_end() {
	if [[ "${NOTICE_TYPE}" == "TG" ]]; then
		curl -k --data chat_id="${TELEGRAM_CHAT_ID}" --data "text=我亲爱的✨主人✨：您使用【${GITHUB_REPOSITORY}】仓库【${MATRIX_TARGET}】文件夹编译的【${FIRMWARE_NAME_PREFIX}】固件顺利编译完成了！💐https://github.com/${GITHUB_REPOSITORY}/releases" "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage"
	elif [[ "${NOTICE_TYPE}" == "PUSH" ]]; then
		curl -k --data token="${PUSH_PLUS_TOKEN}" --data title="【${SOURCE}-${TARGET_PROFILE}】编译成功" --data "content=我亲爱的✨主人✨：您使用【${GITHUB_REPOSITORY}】仓库【${MATRIX_TARGET}】文件夹编译的【${FIRMWARE_NAME_PREFIX}】固件顺利编译完成了！💐https://github.com/${GITHUB_REPOSITORY}/releases" "http://www.pushplus.plus/send"
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
	sudo rm -rf ${COMMON_PATH} && git clone -b main --depth 1 https://github.com/stanlyshi/common ${COMMON_PATH}
	chmod -Rf +x ${BUILD_PATH}
	
}

################################################################################################################
# 插件源仓库更新
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

	# 添加添加源
	update_feeds
	
	# 执行公共脚本
	diy_public
	
	# 执行私有脚本
	if [[ "${SOURCE}" =~ (lede|Lede|LEDE) ]]; then
		diy_lede
	elif [[ "${SOURCE}" =~ (openwrt|Openwrt|OpenWrt|OpenWRT|OPENWRT|official|Official|OFFICIAL) ]]; then
		diy_openwrt
	fi
	
	# 执行diy_part.sh脚本
	/bin/bash "${MATRIX_TARGET_PATH}/${DIY_PART_SH}"
	
	# 安装插件源
	./scripts/feeds install -a > /dev/null 2>&1
	
	# .config相关
	# 复制自定义.config文件
	cp -rf ${CONFIG_PATH}/${CONFIG_FILE} ${HOME_PATH}/.config
	
	# 处理插件冲突
	resolve_confflictions > /dev/null 2>&1
	
	# 编译机型CPU架构、内核版本等信息，替换内核等
	firmware_settings
}

################################################################################################################
# 插件源
################################################################################################################
function update_feeds() {
	echo "--------------update_feeds start--------------"
	echo
	
	cd ${HOME_PATH}
	
	# 添加插件源
	__yellow_color "开始添加插件源..."
	local packages_url="https://github.com/${PACKAGES_ADDR}.git"
	local packages_branch="${PACKAGE_BRANCH}"
	local packages="pkg${GITHUB_ACTOR}"
	
	sed -i "/${packages}/d; /#/d; /^$/d; /argon/d; /ssrplus/d; /helloworld/d; /passwall/d; /OpenClash/d" "feeds.conf.default"
	
	__info_msg "源码：${SOURCE} 插件源：${packages_url} 插件源分支：${packages_branch} 文件夹：${packages}"
	cat >> "feeds.conf.default" <<-EOF
	src-git ${packages} ${packages_url};${packages_branch}
	EOF
	
	# 更新插件源
	__yellow_color "开始更新插件源..."
	./scripts/feeds clean
	./scripts/feeds update -a > /dev/null 2>&1 && __info_msg "OK."	
	rm -rf ${FEEDS_PATH}/${packages}/{LICENSE,*README*,*readme*,.diy,.github,.gitignore} > /dev/null 2>&1
	
	echo
	echo "--------------update_feeds end--------------"
}

################################################################################################################
# 各源码库的公共脚本(文件检测、添加插件源、diy、files、patch等，以及Openwrt编译完成后的首次运行设置)
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

	__yellow_color "开始替换diy文件夹内文件..."
	# 替换编译前源码中对应目录文件
	if [ -n "$(ls -A "${MATRIX_TARGET_PATH}/diy" 2>/dev/null)" ]; then
		rm -rf ${MATRIX_TARGET_PATH}/diy/{LICENSE,*README*,*readme*} > /dev/null 2>&1
		cp -rf ${MATRIX_TARGET_PATH}/diy/* ${FILES_PATH} && chmod -Rf +x ${FILES_PATH}
	fi
	
	__yellow_color "开始替换files文件夹内文件..."
	# 替换编译后固件中对应目录文件（备用）
	if [ -n "$(ls -A "${MATRIX_TARGET_PATH}/files" 2>/dev/null)" ]; then
		rm -rf ${MATRIX_TARGET_PATH}/files/{LICENSE,*README*,.*readme*} > /dev/null 2>&1
		cp -rf ${MATRIX_TARGET_PATH}/files ${HOME_PATH}
	fi
	
	__yellow_color "开始执行补丁文件..."
	# 打补丁
	rm -rf ${MATRIX_TARGET_PATH}/patches/{LICENSE,*README*,*readme*} > /dev/null 2>&1
	if [ -n "$(ls -A "${MATRIX_TARGET_PATH}/patches" 2>/dev/null)" ]; then
		find "${MATRIX_TARGET_PATH}/patches" -type f -name '*.patch' -print0 | sort -z | xargs -I % -t -0 -n 1 sh -c "cat '%'  | patch -d './' -p1 --forward --no-backup-if-mismatch"
	fi
	
	__yellow_color "开始添加openwrt.sh(或openwrt.lxc.sh)..."
	# openwrt.sh
	[[ ! -d "${FILES_PATH}/usr/bin" ]] && mkdir -p ${FILES_PATH}/usr/bin
	if [[ "${FIRMWARE_TYPE}" == "lxc" ]]; then
		cp -rf ${COMMON_PATH}/custom/openwrt.lxc.sh ${FILES_PATH}/usr/bin/openwrt.lxc && sudo chmod -f +x ${FILES_PATH}/usr/bin/openwrt.lxc
	else
		cp -rf ${COMMON_PATH}/custom/openwrt.sh ${FILES_PATH}/usr/bin/openwrt && sudo chmod -f +x ${FILES_PATH}/usr/bin/openwrt
		cp -rf ${COMMON_PATH}/custom/tools.sh "${FILES_PATH}/usr/bin/tools" && sudo chmod -f +x "${FILES_PATH}/usr/bin/tools"
	fi
	
	__yellow_color "开始设置自动更新插件..."
	# 自动更新插件（luci-app-autoupdate）
	if [[ "${FIRMWARE_TYPE}" == "lxc" ]]; then
		find . -type d -name "luci-app-autoupdate" | xargs -i rm -rf {}
		if [[ -n "$(grep "luci-app-autoupdate" ${HOME_PATH}/include/target.mk)" ]]; then
			sed -i 's?luci-app-autoupdate??g' ${HOME_PATH}/include/target.mk
		fi
		__info_msg "lxc固件，删除自动更新插件"
	else
		find . -type d -name 'luci-app-autoupdate' | xargs -i rm -rf {}
		git clone -b main https://github.com/stanlyshi/luci-app-autoupdate ${HOME_PATH}/package/luci-app-autoupdate 2>/dev/null
		if [[ `grep -c "luci-app-autoupdate" ${HOME_PATH}/include/target.mk` -eq '0' ]]; then
			sed -i 's?DEFAULT_PACKAGES:=?DEFAULT_PACKAGES:=luci-app-autoupdate luci-app-ttyd ?g' ${HOME_PATH}/include/target.mk
		fi
		if [[ -d "${HOME_PATH}/package/luci-app-autoupdate" ]]; then
			__info_msg "增加定时更新固件的插件成功"
		else
			__error_msg "插件源码下载失败"
		fi
		# autoupdate插件版本
		if [[ -f "${HOME_PATH}/package/luci-app-autoupdate/root/usr/bin/autoupdate" ]]; then
			AUTOUPDATE_VERSION=$(grep -Eo "Version=V[0-9.]+" "${HOME_PATH}/package/luci-app-autoupdate/root/usr/bin/autoupdate" |grep -Eo [0-9.]+)
			echo AUTOUPDATE_VERSION="${AUTOUPDATE_VERSION}" >> ${GITHUB_ENV}
			__info_msg "luci-app-autoupdate版本：${AUTOUPDATE_VERSION}"
		fi
	fi

	# "默认设置文件..."
	# https://github.com/coolsnowwolf/lede/blob/master/package/lean/default-settings/files/zzz-default-settings
	export ZZZ_PATH="$(find "${HOME_PATH}/package" -type f -name "*-default-settings" |grep files)"
	if [[ -n "${ZZZ_PATH}" ]]; then  
		echo ZZZ_PATH="${ZZZ_PATH}" >> ${GITHUB_ENV}
	fi
	
	__yellow_color "开始修改IP设置..."
	# 修改源码中IP设置
	local def_ipaddress="$(grep "ipaddr:-" "${FILES_PATH}/bin/${FILENAME_CONFIG_GEN}" | grep -v 'addr_offset' | grep -Eo "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+")"
	local new_ipaddress="$(grep "network.lan.ipaddr" ${MATRIX_TARGET_PATH}/${DIY_PART_SH} | grep -Eo "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+")"
	if [[ -n "${new_ipaddress}" ]]; then
		sed -i "s/${def_ipaddress}/${new_ipaddress}/g" ${FILES_PATH}/bin/${FILENAME_CONFIG_GEN}
		__info_msg "IP地址从[${def_ipaddress}]替换为[${new_ipaddress}]"
	else
		__info_msg "使用默认IP地址：${def_ipaddress}"
	fi
	
	__yellow_color "开始执行其它设置..."
	# default_uci文件，UCI基础设置
	echo '#!/bin/sh' > "${FILES_PATH}/etc/${FILENAME_DEFAULT_UCI}"
	sudo chmod -f +x "${FILES_PATH}/etc/${FILENAME_DEFAULT_UCI}"
	
	# default_delete文件，Openwrt固件升级时需要删除的文件
	echo '#!/bin/sh' > "${FILES_PATH}/etc/${FILENAME_TO_DELETE}"
	sudo chmod -f +x "${FILES_PATH}/etc/${FILENAME_TO_DELETE}"
	
	# Openwrt初次运行初始化设置
	cp -rf ${COMMON_PATH}/custom/${FILENAME_DEFAULT_RUNONCE} ${FILES_PATH}/etc/init.d/${FILENAME_DEFAULT_RUNONCE}
	cp -rf ${COMMON_PATH}/custom/${FILENAME_DEFAULT_SETTINGS} ${FILES_PATH}/etc/${FILENAME_DEFAULT_SETTINGS}
	sudo chmod -f +x ${FILES_PATH}/etc/${FILENAME_DEFAULT_SETTINGS}	
	echo "
	rm -rf /etc/init.d/${FILENAME_DEFAULT_RUNONCE}
	rm -rf /etc/${FILENAME_DEFAULT_UCI}
	rm -rf /etc/${FILENAME_TO_DELETE}
	rm -rf /etc/${FILENAME_DEFAULT_SETTINGS}
	exit 0
	" >> ${FILES_PATH}/etc/${FILENAME_DEFAULT_SETTINGS}
	
	__info_msg "OK."
	
	echo
	echo "--------------common_diy_public end--------------"
}

################################################################################################################
# LEDE源码库的私有脚本(LEDE源码对应的修改，请在此处)
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
# 官方源码库的私有脚本(官方源码对应的修改，请在此处)
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
# 处理插件冲突
################################################################################################################
function resolve_confflictions() {
	cd ${HOME_PATH}

	__yellow_color "正在判断插件是否有冲突..."
	
	make defconfig > /dev/null 2>&1
	rm -rf ${CONFFLICTIONS} && touch ${CONFFLICTIONS}
	
	# lxc模式下编译.tar.gz固件
	if [[ "${FIRMWARE_TYPE}" == "lxc" ]]; then
		sed -i '/CONFIG_TARGET_ROOTFS_TARGZ/d' ${HOME_PATH}/.config > /dev/null 2>&1
		sed -i '$a CONFIG_TARGET_ROOTFS_TARGZ=y' ${HOME_PATH}/.config > /dev/null 2>&1
		__info_msg "lxc模式，添加openwrt-generic-rootfs.tar.gz文件编译"
	fi
	
	if [[ `grep -c "CONFIG_PACKAGE_luci-app-adblock-plus=y" ${HOME_PATH}/.config` -eq '1' ]]; then
		if [[ `grep -c "CONFIG_PACKAGE_luci-app-adblock=y" ${HOME_PATH}/.config` -eq '1' ]]; then
			sed -i 's/CONFIG_PACKAGE_luci-app-adblock=y/# CONFIG_PACKAGE_luci-app-adblock is not set/g' ${HOME_PATH}/.config
			sed -i 's/CONFIG_PACKAGE_adblock=y/# CONFIG_PACKAGE_adblock is not set/g' ${HOME_PATH}/.config
			sed -i '/luci-i18n-adblock/d' ${HOME_PATH}/.config
			echo "__error_msg \"您同时选择luci-app-adblock-plus和luci-app-adblock，插件有依赖冲突，只能二选一，已删除luci-app-adblock\"" >> ${CONFFLICTIONS}
			echo "" >> ${CONFFLICTIONS}
		fi
	fi
	
	if [[ `grep -c "CONFIG_PACKAGE_luci-app-advanced=y" ${HOME_PATH}/.config` -eq '1' ]]; then
		if [[ `grep -c "CONFIG_PACKAGE_luci-app-fileassistant=y" ${HOME_PATH}/.config` -eq '1' ]]; then
			sed -i 's/CONFIG_PACKAGE_luci-app-fileassistant=y/# CONFIG_PACKAGE_luci-app-fileassistant is not set/g' ${HOME_PATH}/.config
			echo "__error_msg \"您同时选择luci-app-advanced和luci-app-fileassistant，luci-app-advanced已附带luci-app-fileassistant，所以删除了luci-app-fileassistant\"" >> ${CONFFLICTIONS}
			echo "" >> ${CONFFLICTIONS}
		fi
	fi
	
	if [[ `grep -c "CONFIG_PACKAGE_luci-app-docker=y" ${HOME_PATH}/.config` -eq '1' ]]; then
		if [[ `grep -c "CONFIG_PACKAGE_luci-app-dockerman=y" ${HOME_PATH}/.config` -eq '1' ]]; then
			sed -i 's/CONFIG_PACKAGE_luci-app-docker=y/# CONFIG_PACKAGE_luci-app-docker is not set/g' ${HOME_PATH}/.config
			sed -i 's/CONFIG_PACKAGE_luci-i18n-docker-zh-cn=y/# CONFIG_PACKAGE_luci-i18n-docker-zh-cn is not set/g' ${HOME_PATH}/.config
			echo "__error_msg \"您同时选择luci-app-docker和luci-app-dockerman，插件有冲突，相同功能插件只能二选一，已删除luci-app-docker\"" >> ${CONFFLICTIONS}
			echo "" >> ${CONFFLICTIONS}
		fi
	fi
	
	if [[ `grep -c "CONFIG_PACKAGE_luci-app-dockerman=y" ${HOME_PATH}/.config` -eq '0' ]] || [[ `grep -c "CONFIG_PACKAGE_luci-app-docker=y" ${HOME_PATH}/.config` -eq '0' ]]; then
		sed -i '/CONFIG_PACKAGE_luci-lib-docker/d' ${HOME_PATH}/.config
		sed -i '/CONFIG_PACKAGE_luci-i18n-dockerman-zh-cn/d' ${HOME_PATH}/.config
		sed -i '/CONFIG_PACKAGE_docker/d' ${HOME_PATH}/.config
		sed -i '/CONFIG_PACKAGE_dockerd/d' ${HOME_PATH}/.config
		sed -i '/CONFIG_PACKAGE_runc/d' ${HOME_PATH}/.config
		
		sed -i '$a # CONFIG_PACKAGE_luci-lib-docker is not set' ${HOME_PATH}/.config
		sed -i '$a # CONFIG_PACKAGE_luci-i18n-dockerman-zh-cn is not set' ${HOME_PATH}/.config
		sed -i '$a # CONFIG_PACKAGE_docker is not set' ${HOME_PATH}/.config
		sed -i '$a # CONFIG_PACKAGE_dockerd is not set' ${HOME_PATH}/.config
		sed -i '$a # CONFIG_PACKAGE_runc is not set' ${HOME_PATH}/.config
	fi
	
	if [[ `grep -c "CONFIG_PACKAGE_luci-app-ipsec-server=y" ${HOME_PATH}/.config` -eq '1' ]]; then
		if [[ `grep -c "CONFIG_PACKAGE_luci-app-ipsec-vpnd=y" ${HOME_PATH}/.config` -eq '1' ]]; then
			sed -i 's/CONFIG_PACKAGE_luci-app-ipsec-vpnd=y/# CONFIG_PACKAGE_luci-app-ipsec-vpnd is not set/g' ${HOME_PATH}/.config
			echo "__error_msg \"您同时选择luci-app-ipsec-vpnd和luci-app-ipsec-server，插件有冲突，相同功能插件只能二选一，已删除luci-app-ipsec-vpnd\""  >> ${CONFFLICTIONS}
			echo "" >> ${CONFFLICTIONS}
		fi
	fi
	
	if [[ `grep -c "CONFIG_PACKAGE_luci-app-kodexplorer=y" ${HOME_PATH}/.config` -eq '1' ]]; then
		if [[ `grep -c "CONFIG_PACKAGE_luci-app-vnstat=y" ${HOME_PATH}/.config` -eq '1' ]]; then
			sed -i 's/CONFIG_PACKAGE_luci-app-vnstat=y/# CONFIG_PACKAGE_luci-app-vnstat is not set/g' ${HOME_PATH}/.config
			sed -i 's/CONFIG_PACKAGE_vnstat=y/# CONFIG_PACKAGE_vnstat is not set/g' ${HOME_PATH}/.config
			sed -i 's/CONFIG_PACKAGE_vnstati=y/# CONFIG_PACKAGE_vnstati is not set/g' ${HOME_PATH}/.config
			sed -i 's/CONFIG_PACKAGE_libgd=y/# CONFIG_PACKAGE_libgd is not set/g' ${HOME_PATH}/.config
			sed -i '/luci-i18n-vnstat/d' ${HOME_PATH}/.config
			echo "__error_msg \"您同时选择luci-app-kodexplorer和luci-app-vnstat，插件有依赖冲突，只能二选一，已删除luci-app-vnstat\"" >> ${CONFFLICTIONS}
			echo "" >> ${CONFFLICTIONS}
		fi
	fi
	
	if [[ `grep -c "CONFIG_PACKAGE_wpad-openssl=y" ${HOME_PATH}/.config` -eq '1' ]]; then
		if [[ `grep -c "CONFIG_PACKAGE_wpad=y" ${HOME_PATH}/.config` -eq '1' ]]; then
			sed -i 's/CONFIG_PACKAGE_wpad=y/# CONFIG_PACKAGE_wpad is not set/g' ${HOME_PATH}/.config
		fi
	fi
	
	if [[ `grep -c "CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Trojan_Plus=y" ${HOME_PATH}/.config` -eq '1' ]]; then
		if [[ `grep -c "CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Trojan_GO=y" ${HOME_PATH}/.config` -eq '1' ]]; then
			sed -i 's/CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Trojan_GO=y/# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Trojan_GO is not set/g' ${HOME_PATH}/.config
			echo "__error_msg \"您选择了passwall的Trojan_GO，会和passwall的Trojan_Plus冲突导致编译错误，只能二选一，已删除Trojan_GO\"" >> ${CONFFLICTIONS}
			echo "" >> ${CONFFLICTIONS}
		fi
	fi
	
	if [[ `grep -c "CONFIG_PACKAGE_luci-app-qbittorrent=y" ${HOME_PATH}/.config` -eq '1' ]]; then
		if [[ `grep -c "CONFIG_PACKAGE_luci-app-qbittorrent-simple=y" ${HOME_PATH}/.config` -eq '1' ]]; then
			sed -i 's/CONFIG_PACKAGE_luci-app-qbittorrent-simple=y/# CONFIG_PACKAGE_luci-app-qbittorrent-simple is not set/g' ${HOME_PATH}/.config
			sed -i 's/CONFIG_PACKAGE_luci-i18n-qbittorrent-simple-zh-cn=y/# CONFIG_PACKAGE_luci-i18n-qbittorrent-simple-zh-cn is not set/g' ${HOME_PATH}/.config
			sed -i 's/CONFIG_PACKAGE_qbittorrent=y/# CONFIG_PACKAGE_qbittorrent is not set/g' ${HOME_PATH}/.config
			echo "__error_msg \"您同时选择luci-app-qbittorrent和luci-app-qbittorrent-simple，插件有冲突，相同功能插件只能二选一，已删除luci-app-qbittorrent-simple\"" >> ${CONFFLICTIONS}
			echo "" >> ${CONFFLICTIONS}
		fi
	fi
	
	if [[ `grep -c "CONFIG_PACKAGE_luci-app-samba4=y" ${HOME_PATH}/.config` -eq '1' ]]; then
		if [[ `grep -c "CONFIG_PACKAGE_luci-app-samba=y" ${HOME_PATH}/.config` -eq '1' ]]; then
			sed -i 's/CONFIG_PACKAGE_luci-app-samba=y/# CONFIG_PACKAGE_luci-app-samba is not set/g' ${HOME_PATH}/.config
			sed -i 's/CONFIG_PACKAGE_luci-i18n-samba-zh-cn=y/# CONFIG_PACKAGE_luci-i18n-samba-zh-cn is not set/g' ${HOME_PATH}/.config
			sed -i 's/CONFIG_PACKAGE_samba36-server=y/# CONFIG_PACKAGE_samba36-server is not set/g' ${HOME_PATH}/.config
			echo "__error_msg \"您同时选择luci-app-samba和luci-app-samba4，插件有冲突，相同功能插件只能二选一，已删除luci-app-samba\"" >> ${CONFFLICTIONS}
			echo "" >> ${CONFFLICTIONS}
		fi
	elif [[ `grep -c "CONFIG_PACKAGE_samba4-server=y" ${HOME_PATH}/.config` -eq '1' ]]; then
		sed -i '/CONFIG_PACKAGE_samba4-admin/d' ${HOME_PATH}/.config
		sed -i '/CONFIG_PACKAGE_samba4-client/d' ${HOME_PATH}/.config
		sed -i '/CONFIG_PACKAGE_samba4-libs/d' ${HOME_PATH}/.config
		sed -i '/CONFIG_PACKAGE_samba4-server/d' ${HOME_PATH}/.config
		sed -i '/CONFIG_PACKAGE_samba4-utils/d' ${HOME_PATH}/.config
		
		sed -i '$a # CONFIG_PACKAGE_samba4-admin is not set' ${HOME_PATH}/.config
		sed -i '$a # CONFIG_PACKAGE_samba4-client is not set' ${HOME_PATH}/.config
		sed -i '$a # CONFIG_PACKAGE_samba4-libs is not set' ${HOME_PATH}/.config
		sed -i '$a # CONFIG_PACKAGE_samba4-server is not set' ${HOME_PATH}/.config
		sed -i '$a # CONFIG_PACKAGE_samba4-utils is not set' ${HOME_PATH}/.config
	fi
	
	if [[ `grep -c "CONFIG_PACKAGE_luci-app-sfe=y" ${HOME_PATH}/.config` -eq '1' ]]; then
		if [[ `grep -c "CONFIG_PACKAGE_luci-app-flowoffload=y" ${HOME_PATH}/.config` -eq '1' ]]; then
			sed -i 's/CONFIG_DEFAULT_luci-app-flowoffload=y/# CONFIG_DEFAULT_luci-app-flowoffload is not set/g' ${HOME_PATH}/.config
			sed -i 's/CONFIG_PACKAGE_luci-app-flowoffload=y/# CONFIG_PACKAGE_luci-app-flowoffload is not set/g' ${HOME_PATH}/.config
			sed -i 's/CONFIG_PACKAGE_luci-i18n-flowoffload-zh-cn=y/# CONFIG_PACKAGE_luci-i18n-flowoffload-zh-cn is not set/g' ${HOME_PATH}/.config
			echo "__error_msg \"提示：您同时选择了luci-app-sfe和luci-app-flowoffload，两个ACC网络加速，已删除luci-app-flowoffload\"" >> ${CONFFLICTIONS}
			echo "" >> ${CONFFLICTIONS}
		fi
	fi
	
	if [[ `grep -c "CONFIG_PACKAGE_luci-app-ssr-plus=y" ${HOME_PATH}/.config` -ge '1' ]]; then
		if [[ `grep -c "CONFIG_PACKAGE_luci-app-cshark=y" ${HOME_PATH}/.config` -eq '1' ]]; then
			sed -i 's/CONFIG_PACKAGE_luci-app-cshark=y/# CONFIG_PACKAGE_luci-app-cshark is not set/g' ${HOME_PATH}/.config
			sed -i 's/CONFIG_PACKAGE_cshark=y/# CONFIG_PACKAGE_cshark is not set/g' ${HOME_PATH}/.config
			sed -i 's/CONFIG_PACKAGE_libustream-mbedtls=y/# CONFIG_PACKAGE_libustream-mbedtls is not set/g' ${HOME_PATH}/.config
			echo "__error_msg \"您同时选择luci-app-ssr-plus和luci-app-cshark，插件有依赖冲突，只能二选一，已删除luci-app-cshark\"" >> ${CONFFLICTIONS}
			echo "" >> ${CONFFLICTIONS}
		fi
	fi
	
	if [[ `grep -c "CONFIG_PACKAGE_luci-app-turboacc_INCLUDE_SHORTCUT_FE_CM=y" ${HOME_PATH}/.config` -ge '1' ]]; then
		if [[ `grep -c "CONFIG_PACKAGE_luci-app-turboacc_INCLUDE_SHORTCUT_FE=y" ${HOME_PATH}/.config` -eq '1' ]]; then
			sed -i 's/CONFIG_PACKAGE_luci-app-turboacc_INCLUDE_SHORTCUT_FE=y/# CONFIG_PACKAGE_luci-app-turboacc_INCLUDE_SHORTCUT_FE is not set/g' ${HOME_PATH}/.config
			sed -i 's/CONFIG_PACKAGE_kmod-fast-classifier=y/# CONFIG_PACKAGE_kmod-fast-classifier is not set/g' ${HOME_PATH}/.config
			echo "__error_msg \"luci-app-turboacc同时选择Include Shortcut-FE CM和Include Shortcut-FE，有冲突，只能二选一，已删除Include Shortcut-FE\"" >> ${CONFFLICTIONS}
			echo "" >> ${CONFFLICTIONS}
		fi
	fi
	
	if [[ `grep -c "CONFIG_PACKAGE_luci-app-unblockneteasemusic=y" ${HOME_PATH}/.config` -eq '1' ]]; then
		if [[ `grep -c "CONFIG_PACKAGE_luci-app-unblockneteasemusic-go=y" ${HOME_PATH}/.config` -eq '1' ]]; then
			sed -i 's/CONFIG_PACKAGE_luci-app-unblockneteasemusic-go=y/# CONFIG_PACKAGE_luci-app-unblockneteasemusic-go is not set/g' ${HOME_PATH}/.config
			echo "__error_msg \"您选择了luci-app-unblockneteasemusic-go，会和luci-app-unblockneteasemusic冲突导致编译错误，已删除luci-app-unblockneteasemusic-go\"" >> ${CONFFLICTIONS}
			echo "" >> ${CONFFLICTIONS}
		fi
		if [[ `grep -c "CONFIG_PACKAGE_luci-app-unblockmusic=y" ${HOME_PATH}/.config` -eq '1' ]]; then
			sed -i 's/CONFIG_PACKAGE_luci-app-unblockmusic=y/# CONFIG_PACKAGE_luci-app-unblockmusic is not set/g' ${HOME_PATH}/.config
			echo "__error_msg \"您选择了luci-app-unblockmusic，会和luci-app-unblockneteasemusic冲突导致编译错误，已删除luci-app-unblockmusic\"" >> ${CONFFLICTIONS}
			echo "" >> ${CONFFLICTIONS}
		fi
	fi
	
	if [[ `grep -c "CONFIG_PACKAGE_wpad-openssl=y" ${HOME_PATH}/.config` -eq '1' ]]; then
		if [[ `grep -c "CONFIG_PACKAGE_wpad=y" ${HOME_PATH}/.config` -eq '1' ]]; then
			sed -i 's/CONFIG_PACKAGE_wpad=y/# CONFIG_PACKAGE_wpad is not set/g' ${HOME_PATH}/.config
		fi
	fi
	
	if [[ `grep -c "CONFIG_PACKAGE_dnsmasq-full=y" ${HOME_PATH}/.config` -eq '1' ]]; then
		if [[ `grep -c "CONFIG_PACKAGE_dnsmasq=y" ${HOME_PATH}/.config` -eq '1' ]] || [[ `grep -c "CONFIG_PACKAGE_dnsmasq-dhcpv6=y" ${HOME_PATH}/.config` -eq '1' ]]; then
			sed -i 's/CONFIG_PACKAGE_dnsmasq=y/# CONFIG_PACKAGE_dnsmasq is not set/g' ${HOME_PATH}/.config
			sed -i 's/CONFIG_PACKAGE_dnsmasq-dhcpv6=y/# CONFIG_PACKAGE_dnsmasq-dhcpv6 is not set/g' ${HOME_PATH}/.config
		fi
	fi
	
	if [[ `grep -c "CONFIG_PACKAGE_odhcp6c=y" ${HOME_PATH}/.config` -eq '1' ]]; then
		sed -i '/CONFIG_PACKAGE_odhcpd=y/d' ${HOME_PATH}/.config
		sed -i '/CONFIG_PACKAGE_odhcpd_full_ext_cer_id=0/d' ${HOME_PATH}/.config
	fi

	if [[ `grep -c "CONFIG_PACKAGE_luci-theme-argon=y" ${HOME_PATH}/.config` -eq '1' ]]; then
		if [[ `grep -c "CONFIG_PACKAGE_luci-theme-argon_new=y" ${HOME_PATH}/.config` -eq '1' ]]; then
			sed -i 's/CONFIG_PACKAGE_luci-theme-argon_new=y/# CONFIG_PACKAGE_luci-theme-argon_new is not set/g' ${HOME_PATH}/.config
			echo "__error_msg \"您同时选择luci-theme-argon和luci-theme-argon_new，插件有冲突，相同功能插件只能二选一，已删除luci-theme-argon_new\"" >> ${CONFFLICTIONS}
			echo "" >> ${CONFFLICTIONS}
		fi
		if [[ `grep -c "CONFIG_PACKAGE_luci-theme-argonne=y" ${HOME_PATH}/.config` -eq '1' ]]; then
			sed -i 's/CONFIG_PACKAGE_luci-theme-argonne=y/# CONFIG_PACKAGE_luci-theme-argonne is not set/g' ${HOME_PATH}/.config
			echo "__error_msg \"您同时选择luci-theme-argon和luci-theme-argonne，插件有冲突，相同功能插件只能二选一，已删除luci-theme-argonne\"" >> ${CONFFLICTIONS}
			echo "" >> ${CONFFLICTIONS}
		fi
		if [[ `grep -c "CONFIG_PACKAGE_luci-app-argon-config=y" ${HOME_PATH}/.config` -eq '0' ]] && [[ `grep -c "CONFIG_TARGET_x86=y" ${HOME_PATH}/.config` -eq '1' ]]; then
			sed -i '/CONFIG_PACKAGE_luci-app-argon-config/d' ${HOME_PATH}/.config
			sed -i '/argon=y/i\CONFIG_PACKAGE_luci-app-argon-config=y' ${HOME_PATH}/.config
		fi
	fi
	
	if [[ `grep -c "CONFIG_PACKAGE_luci-theme-argon=y" ${HOME_PATH}/.config` -eq '1' ]]; then
		if [[ `grep -c "CONFIG_PACKAGE_luci-app-argon-config=y" ${HOME_PATH}/.config` == '0' ]]; then
			sed -i '/luci-app-argon-config/d' ${HOME_PATH}/.config
			sed -i '$a CONFIG_PACKAGE_luci-app-argon-config=y' ${HOME_PATH}/.config
		fi
	else
		sed -i '/luci-app-argon-config/d' ${HOME_PATH}/.config
		sed -i '$a # CONFIG_PACKAGE_luci-app-argon-config is not set' ${HOME_PATH}/.config
	fi

	if [[ `grep -c "CONFIG_TARGET_x86=y" ${HOME_PATH}/.config` -eq '1' ]] || [[ `grep -c "CONFIG_TARGET_rockchip=y" ${HOME_PATH}/.config` -eq '1' ]] || [[ `grep -c "CONFIG_TARGET_bcm27xx=y" ${HOME_PATH}/.config` -eq '1' ]]; then
		sed -i '/CONFIG_TARGET_IMAGES_GZIP/d' ${HOME_PATH}/.config
		sed -i '$a CONFIG_TARGET_IMAGES_GZIP=y' ${HOME_PATH}/.config
		sed -i '/CONFIG_PACKAGE_openssh-sftp-server/d' ${HOME_PATH}/.config
		sed -i '$a CONFIG_PACKAGE_openssh-sftp-server=y' ${HOME_PATH}/.config
	fi

	if [[ `grep -c "CONFIG_TARGET_x86=y" ${HOME_PATH}/.config` -eq '1' ]] || [[ `grep -c "CONFIG_TARGET_rockchip=y" ${HOME_PATH}/.config` -eq '1' ]] || [[ `grep -c "CONFIG_TARGET_bcm27xx=y" ${HOME_PATH}/.config` -eq '1' ]]; then
		sed -i '/CONFIG_PACKAGE_snmpd/d' ${HOME_PATH}/.config
		sed -i '$a CONFIG_PACKAGE_snmpd=y' ${HOME_PATH}/.config
		sed -i '/CONFIG_TARGET_IMAGES_GZIP/d' ${HOME_PATH}/.config
		sed -i '$a CONFIG_TARGET_IMAGES_GZIP=y' ${HOME_PATH}/.config
		sed -i '/CONFIG_PACKAGE_openssh-sftp-server/d' ${HOME_PATH}/.config
		sed -i '$a CONFIG_PACKAGE_openssh-sftp-server=y' ${HOME_PATH}/.config
		#sed -i '/CONFIG_GRUB_IMAGES/d' ${HOME_PATH}/.config
		#sed -i '$a CONFIG_GRUB_IMAGES=y' ${HOME_PATH}/.config
		if [[ `grep -c "CONFIG_TARGET_ROOTFS_PARTSIZE=" ${HOME_PATH}/.config` -eq '1' ]]; then
			local partsize="$(grep -Eo "CONFIG_TARGET_ROOTFS_PARTSIZE=[0-9]+" ${HOME_PATH}/.config |cut -f2 -d=)"
			if [[ "${partsize}" -lt "400" ]];then
				sed -i '/CONFIG_TARGET_ROOTFS_PARTSIZE/d' ${HOME_PATH}/.config
			fi
		fi
	fi
	
	if [[ `grep -c "CONFIG_TARGET_mxs=y" ${HOME_PATH}/.config` -eq '1' ]] || [[ `grep -c "CONFIG_TARGET_sunxi=y" ${HOME_PATH}/.config` -eq '1' ]] || [[ `grep -c "CONFIG_TARGET_zynq=y" ${HOME_PATH}/.config` -eq '1' ]]; then	
		sed -i '/CONFIG_TARGET_IMAGES_GZIP/d' ${HOME_PATH}/.config
		sed -i '$a CONFIG_TARGET_IMAGES_GZIP=y' ${HOME_PATH}/.config
		sed -i '/CONFIG_PACKAGE_openssh-sftp-server/d' ${HOME_PATH}/.config
		sed -i '$a CONFIG_PACKAGE_openssh-sftp-server=y' ${HOME_PATH}/.config
		sed -i '/CONFIG_GRUB_IMAGES/d' ${HOME_PATH}/.config
		sed -i '$a CONFIG_GRUB_IMAGES=y' ${HOME_PATH}/.config
		if [[ `grep -c "CONFIG_TARGET_ROOTFS_PARTSIZE=" ${HOME_PATH}/.config` -eq '1' ]]; then
			local partsize="$(grep -Eo "CONFIG_TARGET_ROOTFS_PARTSIZE=[0-9]+" ${HOME_PATH}/.config |cut -f2 -d=)"
			if [[ "${partsize}" -lt "400" ]];then
				sed -i '/CONFIG_TARGET_ROOTFS_PARTSIZE/d' ${HOME_PATH}/.config
				sed -i '$a CONFIG_TARGET_ROOTFS_PARTSIZE=400' ${HOME_PATH}/.config
			fi
		fi
	fi
	
	if [[ `grep -c "CONFIG_TARGET_armvirt=y" ${HOME_PATH}/.config` -eq '1' ]] || [[ `grep -c "CONFIG_TARGET_armsr=y" ${HOME_PATH}/.config` -eq '1' ]]; then
		sed -i 's/CONFIG_PACKAGE_luci-app-autoupdate=y/# CONFIG_PACKAGE_luci-app-autoupdate is not set/g' ${HOME_PATH}/.config
		sed -i '/CONFIG_TARGET_ROOTFS_TARGZ/d' ${HOME_PATH}/.config
		sed -i '$a CONFIG_TARGET_ROOTFS_TARGZ=y' ${HOME_PATH}/.config
	fi
	
	if [[ `grep -c "CONFIG_TARGET_ROOTFS_EXT4FS=y" ${HOME_PATH}/.config` -eq '1' ]]; then	
		local partsize="$(grep -Eo "CONFIG_TARGET_ROOTFS_PARTSIZE=[0-9]+" ${HOME_PATH}/.config |cut -f2 -d=)"
		if [[ "${partsize}" -lt "950" ]];then
			sed -i '/CONFIG_TARGET_ROOTFS_PARTSIZE/d' ${HOME_PATH}/.config
			sed -i '$a CONFIG_TARGET_ROOTFS_PARTSIZE=950' ${HOME_PATH}/.config
			echo "__error_msg \"EXT4提示：请注意，您选择了ext4安装的固件格式,而检测到您的分配的固件系统分区过小\"" >> ${CONFFLICTIONS}
			echo "__error_msg \"为避免编译出错,已自动帮您修改成950M\"" >> ${CONFFLICTIONS}
			echo "" >> ${CONFFLICTIONS}
		fi
	fi
	
	if [[ `grep -c "CONFIG_PACKAGE_antfs-mount=y" ${HOME_PATH}/.config` -eq '1' ]]; then
		if [[ `grep -c "CONFIG_PACKAGE_ntfs3-mount=y" ${HOME_PATH}/.config` -eq '1' ]]; then
			sed -i 's/CONFIG_PACKAGE_antfs-mount=y/# CONFIG_PACKAGE_antfs-mount is not set/g' ${HOME_PATH}/.config
		fi
	fi

	if [[ `grep -c "CONFIG_PACKAGE_libustream-wolfssl=y" ${HOME_PATH}/.config` -eq '1' ]]; then
		if [[ `grep -c "CONFIG_PACKAGE_libustream-openssl=y" ${HOME_PATH}/.config` -eq '1' ]]; then
			sed -i 's/CONFIG_PACKAGE_libustream-wolfssl=y/# CONFIG_PACKAGE_libustream-wolfssl is not set/g' ${HOME_PATH}/.config
		fi
	fi
}

################################################################################################################
# 编译机型CPU机型架构、内核版本、固件名称、固件自动更新相关信息等（依赖于make defconfig，须在生成.config之后）
################################################################################################################
function firmware_settings() {
	echo "--------------firmware_settings start--------------"
	echo
	
	cd ${HOME_PATH}
	
	# 如未运行过 make menuconfig，需要运行下一行命令
	# make defconfig > /dev/null 2>&1
	
	# x86、ramips...
	TARGET_BOARD="$(awk -F '[="]+' '/CONFIG_TARGET_BOARD/{print $2}' ${HOME_PATH}/.config)"
	# 64、generic、legacy、mt7621...
	TARGET_SUBTARGET="$(awk -F '[="]+' '/CONFIG_TARGET_SUBTARGET/{print $2}' ${HOME_PATH}/.config)"
	# x86_64、i386_pentium4、i386_pentium-mmx、mipsel_24kc...
	ARCHITECTURE="$(awk -F '[="]+' '/CONFIG_TARGET_ARCH_PACKAGES/{print $2}' ${HOME_PATH}/.config)"
	
	# 机型架构
	__yellow_color "开始获取固件机型架构信息..."
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
		TARGET_PROFILE="$(awk -F '[="]+' '/TARGET_PROFILE/{print $2}' ${HOME_PATH}/.config | sed 's/DEVICE_//')"
	fi
	TARGET_DEVICE="${TARGET_PROFILE}"
	# 修改TARGET_PROFILE
	if [[ "${TARGET_PROFILE}" =~ (phicomm_k3|phicomm-k3) ]]; then		
		TARGET_PROFILE="phicomm-k3"
	elif [[ "${TARGET_PROFILE}" =~ (k2p|phicomm_k2p|phicomm-k2p) ]]; then
		TARGET_PROFILE="phicomm-k2p"
	elif [[ "${TARGET_PROFILE}" =~ (xiaomi_mi-router-3g-v2|xiaomi_mir3g_v2) ]]; then
		TARGET_PROFILE="xiaomi_mir3g-v2"
	elif [[ "${TARGET_PROFILE}" == "xiaomi_mi-router-3g" ]]; then
		TARGET_PROFILE="xiaomi_mir3g"
	elif [[ "${TARGET_PROFILE}" == "xiaomi_mi-router-3-pro" ]]; then
		TARGET_PROFILE="xiaomi_mir3p"
	fi
	__info_msg "机型信息：${TARGET_PROFILE}"
	__info_msg "CPU架构：${ARCHITECTURE}"
	
	# 内核版本
	__yellow_color "开始获取内核版本信息、替换内核等..."
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
	__yellow_color "开始设置固件名称、后缀等相关信息..."
	# 固件路径
	FIRMWARE_PATH=${HOME_PATH}/bin/targets/${TARGET_BOARD}/${TARGET_SUBTARGET}
	__info_msg "固件保存路径：${FIRMWARE_PATH}"
	# 固件版本 如：lede-x86-64-202310011001
	FIRMWARE_BRIEF="${SOURCE}-${TARGET_PROFILE}-${COMPILE_DATE_HM}"
	# 固件名称前缀 如：18.06-lede-x86-64，方便自动更新固件搜寻可更新固件
	FIRMWARE_NAME_PREFIX="${LUCI_EDITION}-${SOURCE}-${TARGET_PROFILE}"
	# 固件名称（简写，x86区分legacy、uefi）如：18.06-lede-x86-64-202310101010	
	FIRMWARE_NAME="${FIRMWARE_NAME_PREFIX}-${COMPILE_DATE_HM}"
	# 固件名称与后缀
	case "${TARGET_BOARD}" in
	x86)
		ROOTFS_EXT=".tar.gz"
		FIRMWARE_EXT=".img.gz"		
		# 18.06-lede-x86-64-1695553941-legacy
		# FIRMWARE_NAME_LEGACY="${FIRMWARE_NAME}-legacy"
		# 18.06-lede-x86-64-1695553941-uefi
		# FIRMWARE_NAME_UEFI="${FIRMWARE_NAME}-uefi"
		# 18.06-lede-x86-64-1695647548-rootfs
		# FIRMWARE_NAME_ROOTFS="${FIRMWARE_NAME}-rootfs"
		echo ROOTFS_EXT="${ROOTFS_EXT}" >> ${GITHUB_ENV}
	;;
	ramips | reltek | ath* | ipq* | bcm47xx | bmips | kirkwood | mediatek)
		FIRMWARE_EXT=".bin"
		FIRMWARE_NAME="${FIRMWARE_NAME}-sysupgrade"
	;;
	rockchip | bcm27xx | mxs | sunxi | zynq)
		FIRMWARE_EXT=".img.gz"
	;;
	mvebu)
		case "${TARGET_SUBTARGET}" in
		cortexa53 | cortexa72)
			FIRMWARE_EXT=".img.gz"
		;;
		esac
	;;
	bcm53xx)
		FIRMWARE_EXT=".trx"
	;;
	octeon | oxnas | pistachio)
		FIRMWARE_EXT=".tar"
	;;
	*)
		FIRMWARE_EXT=".bin"
	;;
	esac

	# release标签
	if [[ "${FIRMWARE_TYPE}" == "lxc" ]]; then
		RELEASE_TAG="AutoUpdate-${TARGET_BOARD}-lxc"
	else
		RELEASE_TAG="AutoUpdate-${TARGET_BOARD}"
	fi
	# release地址
	GITHUB_RELEASE_URL="${GITHUB_REPOSITORY_URL}/releases/tag/${RELEASE_TAG}"
	GITHUB_RELEASE_DOWNLOAD_URL="${GITHUB_REPOSITORY_URL}/releases/download/${RELEASE_TAG}"

	echo FIRMWARE_NAME="${FIRMWARE_NAME}" >> ${GITHUB_ENV}
	echo TARGET_BOARD="${TARGET_BOARD}" >> ${GITHUB_ENV}
	echo TARGET_SUBTARGET="${TARGET_SUBTARGET}" >> ${GITHUB_ENV}
	echo ARCHITECTURE="${ARCHITECTURE}" >> ${GITHUB_ENV}	
	echo FIRMWARE_PATH="${FIRMWARE_PATH}" >> ${GITHUB_ENV}
	echo TARGET_PROFILE="${TARGET_PROFILE}" >> ${GITHUB_ENV}
	echo TARGET_DEVICE="${TARGET_DEVICE}" >> ${GITHUB_ENV}
	echo KERNEL_PATCHVER="${KERNEL_PATCHVER}" >> ${GITHUB_ENV}
	echo LINUX_KERNEL="${LINUX_KERNEL}" >> ${GITHUB_ENV}
	echo FIRMWARE_EXT="${FIRMWARE_EXT}" >> ${GITHUB_ENV}
	echo RELEASE_TAG="${RELEASE_TAG}" >> ${GITHUB_ENV}
	echo GITHUB_RELEASE_URL="${GITHUB_RELEASE_URL}" >> ${GITHUB_ENV}
	echo FIRMWARE_BRIEF="${FIRMWARE_BRIEF}" >> ${GITHUB_ENV}
	
	# 固件自动更新相关信息等
	__yellow_color "开始设置自动更新固件相关信息..."
	local file_openwrt_autoupdate="${FILES_PATH}/etc/openwrt_autoupdate"
	local github_api_origin="${GITHUB_REPOSITORY_URL}/releases/download/${RELEASE_TAG}/${GITHUB_API}"
	local github_api_ghproxy="https://ghproxy.com/${GITHUB_REPOSITORY_URL}/releases/download/${RELEASE_TAG}/${GITHUB_API}"
	local github_api_fastgit="https://download.fastgit.org/${GITHUB_REPOSITORY}/releases/download/${RELEASE_TAG}/${GITHUB_API}"
	local release_download_origin="${GITHUB_REPOSITORY_URL}/releases/download/${RELEASE_TAG}"
	local release_download_ghproxy="https://ghproxy.com/${GITHUB_REPOSITORY_URL}/releases/download/${RELEASE_TAG}"
	cat > "${file_openwrt_autoupdate}" <<-EOF
	GITHUB_REPOSITORY="${GITHUB_REPOSITORY}"
	GITHUB_REPOSITORY_URL="https://github.com/${GITHUB_REPOSITORY}"
	GITHUB_RELEASE_URL="${GITHUB_RELEASE_URL}"
	GITHUB_RELEASE_DOWNLOAD_URL="${GITHUB_RELEASE_DOWNLOAD_URL}"
	GITHUB_TAG="${RELEASE_TAG}"
	GITHUB_API="${GITHUB_API}"
	GITHUB_API_URL_ORIGIN="${github_api_origin}"
	GITHUB_API_URL_FASTGIT="${github_api_fastgit}"
	GITHUB_API_URL_GHPROXY="${github_api_ghproxy}"
	FRIMWARE_URL_ORIGIN="${release_download_origin}"
	FRIMWARE_URL_GHPROXY="${release_download_ghproxy}"
	# lede
	SOURCE="${SOURCE}"
	# x86-64
	TARGET_PROFILE="${TARGET_PROFILE}"
	# x86
	TARGET_BOARD="${TARGET_BOARD}"
	# 64
	TARGET_SUBTARGET="${TARGET_SUBTARGET}"
	# 18.06
	LUCI_EDITION="${LUCI_EDITION}"
	# 202310011221
	COMPILE_DATE="${COMPILE_DATE_HM}"
	# .img.gz
	FIRMWARE_EXT="${FIRMWARE_EXT}"
	# lede-x86-64-202310011001
	FIRMWARE_BRIEF="${FIRMWARE_BRIEF}"
	# 18.06-lede-x86-64
	FIRMWARE_NAME_PREFIX="${FIRMWARE_NAME_PREFIX}"
	# 18.06-lede-x86-64-202310011001
	CURRENT_FIRMWARE="${FIRMWARE_NAME}"
	# luci-app-autoupdate version
	AUTOUPDATE_VERSION="${AUTOUPDATE_VERSION}"
	FILES_TO_DELETE="/etc/${FILENAME_TO_DELETE}"
	EOF

	cat ${COMMON_PATH}/autoupdate/replace >> ${file_openwrt_autoupdate}
	sudo chmod +x ${file_openwrt_autoupdate}
	cat ${file_openwrt_autoupdate}
	
	echo
	echo "--------------firmware_settings end--------------"
}

################################################################################################################
# 生成.config文件
################################################################################################################
function make_defconfig() {
	cd ${HOME_PATH}
	
	# 生成.config文件
	make defconfig > /dev/null 2>&1
	# 生成diffconfig文件
	bash ${HOME_PATH}/scripts/diffconfig.sh > ${DIFFCONFIG_TXT}
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
	__blue_color "LUCI版本: ${LUCI_EDITION}"
	__blue_color "机型信息: ${TARGET_PROFILE}"
	__blue_color "CPU 架构: ${ARCHITECTURE}"
	__blue_color "固件作者: ${GITHUB_ACTOR}"
	__blue_color "仓库地址: ${GITHUB_REPOSITORY_URL}"
	__blue_color "编译时间: ${COMPILE_DATE_CN}"
	__blue_color "友情提示：您当前使用【${MATRIX_TARGET}】文件夹编译【${TARGET_PROFILE}】固件"
	echo

	echo
	__red_color "固件类型"
	if [[ "${FIRMWARE_TYPE}" == "lxc" ]]; then
		__blue_color "LXC固件：开启"
		echo
		__red_color "LXC固件自动更新"
		__white_color "1、PVE运行："
		__green_color "pct pull xxx /bin/openwrt.lxc /bin/openwrt && chmod -f +x /bin/openwrt"
		__white_color "注意：将xxx改为个人OpenWrt容器的ID，如100"
		__white_color "2、PVE运行："
		__green_color "openwrt"
		echo
	else
		__white_color "LXC固件：关闭"
		echo
		__red_color "自动更新信息"
		__blue_color "插件版本: ${AUTOUPDATE_VERSION}"
		
		if [[ "${TARGET_BOARD}" == "x86" ]]; then
			__blue_color "传统固件: ${FIRMWARE_NAME}-legacy${FIRMWARE_EXT}"
			__blue_color "UEFI固件: ${FIRMWARE_NAME}-uefi${FIRMWARE_EXT}"
			__blue_color "固件后缀: ${FIRMWARE_EXT}"
		else
			__blue_color "固件名称: ${FIRMWARE_NAME}-sysupgrade${FIRMWARE_EXT}"
			__blue_color "固件后缀: ${FIRMWARE_EXT}"
		fi
		__blue_color "固件版本: ${FIRMWARE_NAME}"
		__blue_color "云端路径: ${GITHUB_RELEASE_URL}"
		__white_color "编译成功后，会自动把固件发布到指定地址，生成云端路径"
		__white_color "修改IP、DNS、网关或者在线更新，请输入命令：openwrt"
	fi
	
	echo
	__red_color "Github在线编译配置"
	if [[ "${UPLOAD_RELEASE}" == "true" ]]; then
		__blue_color "发布firmware+ipk至Github Relese: 开启"
	else
		__white_color "发布firmware+ipk至Github Relese: 关闭"
	fi
	if [[ "${UPLOAD_FIRMWARE}" == "true" ]]; then
		__blue_color "上传firmware+ipk至Github Artifacts: 开启"
	else
		__white_color "上传firmware+ipk至Github Artifacts: 关闭"
	fi
	if [[ "${UPLOAD_CONFIG}" == "true" ]]; then
		__blue_color "上传.config配置文件至Github Artifacts: 开启"
	else
		__white_color "上传.config配置文件至Github Artifacts: 关闭"
	fi
	if [[ "${NOTICE_TYPE}" =~ (TG|telegram|PUSH|pushplus|WX|WeChat) ]]; then
		__blue_color "pushplus/Telegram通知: 开启"
	else
		__white_color "pushplus/Telegram通知: 关闭"
	fi
	echo
	
	echo
	__red_color "Github在线编译CPU型号"
	__blue_color `cat /proc/cpuinfo | grep name | cut -f2 -d: | uniq -c`
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
	
	if [[ -s ${CONFFLICTIONS} ]]; then
		__red_color "插件冲突信息"
		chmod +x ${CONFFLICTIONS} && source ${CONFFLICTIONS}
		rm -rf ${CONFFLICTIONS}
	fi
}

################################################################################################################
# 更新编译仓库
################################################################################################################
function update_repo() {
	local repo_path="${GITHUB_WORKSPACE}/repo"
	local repo_matrix_target_path="${repo_path}/build/${MATRIX_TARGET}"
	local repo_config_path="${repo_path}/build/${MATRIX_TARGET}/config"
	local repo_settings_ini="${repo_path}/build/${MATRIX_TARGET}/settings.ini"
	
	[[ -d "${repo_path}" ]] && rm -rf ${repo_path}

	cd ${GITHUB_WORKSPACE}	
	git clone https://github.com/${GITHUB_REPOSITORY}.git repo
	
	cd ${repo_path}
	
	# 更新COMPILE_YML文件中的matrix.target设置
	local compile_yml_target=$(grep 'target: \[' ${repo_path}/.github/workflows/${COMPILE_YML} | sed 's/^[ ]*//g' |grep '^target' |cut -d '#' -f1 |sed 's/\[/\\&/' |sed 's/\]/\\&/') && echo "compile_yml_target=${compile_yml_target}"
	local build_yml_target=$(grep 'target: \[' ${repo_path}/.github/workflows/${BUILD_YML}  |sed 's/^[ ]*//g' |grep '^target' |cut -d '#' -f1 |sed 's/\[/\\&/' |sed 's/\]/\\&/') && echo "build_yml_target=${build_yml_target}"
	if [[ -n "${compile_yml_target}" ]] && [[ -n "${build_yml_target}" ]] && [[ "${compile_yml_target}" != "${build_yml_target}" ]]; then
		ENABLE_REPO_UPDATE="true"
		sed -i "s/${compile_yml_target}/${build_yml_target}/g" ${repo_path}/.github/workflows/${COMPILE_YML} && echo "change compile target ${compile_yml_target} to ${build_yml_target}"
	fi

	# 更新settings.ini文件
	local settings_array=(SOURCE_BRANCH CONFIG_FILE FIRMWARE_TYPE NOTICE_TYPE UPLOAD_RELEASE UPLOAD_FIRMWARE UPLOAD_CONFIG ENABLE_CACHEWRTBUILD)
	for x in ${settings_array[*]}; do
		local settings_key="$(grep -E "${x}=" ${SETTINGS_INI} |sed 's/^[ ]*//g' |grep -v '^#' | awk '{print $1}' | awk -F'=' '{print $1}')"
		local settings_val="$(grep -E "${x}=" ${SETTINGS_INI} |sed 's/^[ ]*//g' |grep -v '^#' | awk '{print $1}' | awk -F'=' '{print $2}' | sed 's#"##g')"
		eval eval env_settings_val=\$$x
		if [[ -n "${settings_key}" ]]; then
			sed -i "s#${x}=\"${settings_val}\"#${x}=\"${env_settings_val}\"#g" ${SETTINGS_INI}
		fi
	done
	if [[ "$(cat ${SETTINGS_INI})" != "$(cat ${repo_settings_ini})" ]]; then
		ENABLE_REPO_UPDATE="true"
		cp -rf ${SETTINGS_INI} ${repo_settings_ini}
	fi
	
	# 更新.config文件
	# ${HOME_PATH}/scripts/diffconfig.sh > ${DIFFCONFIG_TXT}
	if [[ "$(cat ${DIFFCONFIG_TXT})" != "$(cat ${repo_config_path}/${CONFIG_FILE})" ]]; then
		ENABLE_REPO_UPDATE="true"
		cp -rf ${DIFFCONFIG_TXT} ${repo_config_path}/${CONFIG_FILE}
	fi
	
	# 更新plugins插件列表
	plugin_1="$(grep -Eo "CONFIG_PACKAGE_luci-app-.*=y|CONFIG_PACKAGE_luci-theme-.*=y" ${HOME_PATH}/.config |grep -v 'INCLUDE\|_Proxy\|_static\|_dynamic' |sed 's/=y//' |sed 's/CONFIG_PACKAGE_//g')"
	plugin_2="$(echo "${plugin_1}" |sed 's/^/、/g' |awk '$0=NR$0')"
	echo "${plugin_2}" > ${HOME_PATH}/plugin_list
	if [[ "$(cat ${HOME_PATH}/plugin_list)" != "$(cat ${repo_matrix_target_path}/plugins)" ]]; then
		ENABLE_REPO_UPDATE="true"
		# 覆盖原plugin文件
		mv -f ${HOME_PATH}/plugin_list ${repo_matrix_target_path}/plugins > /dev/null 2>&1
	fi
	
	# 提交commit，更新repo
	cd ${repo_path}
	local branch_head="$(git rev-parse --abbrev-ref HEAD)"
	if [[ "${ENABLE_REPO_UPDATE}" == "true" ]]; then
		git add .
		git commit -m "Update plugins, ${CONFIG_FILE} and settings.ini, etc."
		git push --force "https://${REPO_TOKEN}@github.com/${GITHUB_REPOSITORY}" HEAD:${branch_head}
		__success_msg "Your branch is now up to the latest."
	else
		__info_msg "Your branch is already up to date with origin/${branch_head}. Nothing to commit, working tree clean."
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
	for X in $(cat ${FILES_TO_CLEAR} | sed '/^#.*/d'); do		
		rm -rf *"${X}"* > /dev/null 2>&1
		__info_msg "delete ${X}"
	done
	rm -rf packages > /dev/null 2>&1
	rm -rf ${FILES_TO_CLEAR}

	__yellow_color "开始准备固件自动更新相关固件..."
	[[ ! -d ${AUTOUPDATE_PATH} ]] && mkdir -p ${AUTOUPDATE_PATH} || rm -rf ${AUTOUPDATE_PATH}/*
	case "${TARGET_BOARD}" in
	x86)
		if [[ "${FIRMWARE_TYPE}" == "lxc" ]]; then
			local firmware_rootfs_img="$(ls -1 |grep -Eo ".*squashfs.*rootfs.*img.gz")"
			[[ -f ${firmware_rootfs_img} ]] && {
				local rootfs_img_md5="$(md5sum ${firmware_rootfs_img} |cut -c1-3)$(sha256sum ${firmware_rootfs_img} |cut -c1-3)"
				cp -rf ${firmware_rootfs_img} ${AUTOUPDATE_PATH}/${FIRMWARE_NAME}-rootfs-${rootfs_img_md5}${FIRMWARE_EXT}
				__info_msg "copy ${firmware_rootfs_img} to ${AUTOUPDATE_PATH}/${FIRMWARE_NAME}-rootfs-${rootfs_img_md5}${FIRMWARE_EXT}"
			}
			local firmware_rootfs_tar="$(ls -1 |grep -Eo ".*rootfs.*tar.gz")"
			[[ -f ${firmware_rootfs_tar} ]] && {
				local rootfs_tar_md5="$(md5sum ${firmware_rootfs_tar} |cut -c1-3)$(sha256sum ${firmware_rootfs_tar} |cut -c1-3)"
				cp -rf ${firmware_rootfs_tar} ${AUTOUPDATE_PATH}/${FIRMWARE_NAME}-rootfs-${rootfs_tar_md5}${ROOTFS_EXT}
				__info_msg "copy ${firmware_rootfs_tar} to ${AUTOUPDATE_PATH}/${FIRMWARE_NAME}-rootfs-${rootfs_tar_md5}${ROOTFS_EXT}"
			}
		else
			if [[ `ls -1 | grep -c "efi"` -ge '1' ]]; then
				local firmware_uefi="$(ls -1 |grep -Eo ".*squashfs.*efi.*img.gz")"
				[[ -f ${firmware_uefi} ]] && {
					local uefimd5="$(md5sum ${firmware_uefi} |cut -c1-3)$(sha256sum ${firmware_uefi} |cut -c1-3)"
					cp -rf "${firmware_uefi}" "${AUTOUPDATE_PATH}/${FIRMWARE_NAME}-uefi-${uefimd5}${FIRMWARE_EXT}"
					__info_msg "copy ${firmware_uefi} to ${AUTOUPDATE_PATH}/${FIRMWARE_NAME}-uefi-${uefimd5}${FIRMWARE_EXT}"
				}
			fi
			if [[ `ls -1 | grep -c "squashfs"` -ge '1' ]]; then
				local firmware_legacy="$(ls -1 |grep -Eo ".*squashfs.*img.gz" |grep -v ".vm\|.vb\|.vh\|.qco\|efi\|root")"
				[[ -f ${firmware_legacy} ]] && {
					local legacymd5="$(md5sum ${firmware_legacy} |cut -c1-3)$(sha256sum ${firmware_legacy} |cut -c1-3)"
					cp -rf "${firmware_legacy}" "${AUTOUPDATE_PATH}/${FIRMWARE_NAME}-legacy-${legacymd5}${FIRMWARE_EXT}"
					__info_msg "copy ${firmware_legacy} to ${AUTOUPDATE_PATH}/${FIRMWARE_NAME}-legacy-${legacymd5}${FIRMWARE_EXT}"
				}
			fi
		fi
	;;
	*)
		if [[ `ls -1 | grep -c "sysupgrade"` -ge '1' ]]; then
			local firmware_sysupgrade="$(ls -1 |grep -Eo ".*${TARGET_PROFILE}.*sysupgrade.*${FIRMWARE_EXT}" |grep -v "rootfs\|ext4\|factory")"
		else
			local firmware_sysupgrade="$(ls -1 |grep -Eo ".*${TARGET_PROFILE}.*squashfs.*${FIRMWARE_EXT}" |grep -v "rootfs\|ext4\|factory")"
		fi
		if [[ -f "${firmware_sysupgrade}" ]]; then
			local sysupgrademd5="$(md5sum ${firmware_sysupgrade} | cut -c1-3)$(sha256sum ${firmware_sysupgrade} | cut -c1-3)"
			cp -rf "${firmware_sysupgrade}" "${AUTOUPDATE_PATH}/${FIRMWARE_NAME}-sysupgrade-${sysupgrademd5}${FIRMWARE_EXT}"
			__info_msg "copy ${firmware_sysupgrade} to ${AUTOUPDATE_PATH}/${FIRMWARE_NAME}-sysupgrade-${sysupgrademd5}${FIRMWARE_EXT}"
		else
			__error_msg "没有找到可用的sysupgrade格式${FIRMWARE_EXT}固件！"
		fi
	;;
	esac

	__yellow_color "开始准备固件发布文件..."
	__info_msg "准备ipk压缩包"
	if [[ "${UPLOAD_FIRMWARE}" == "true" || "${UPLOAD_RELEASE}" == "true" ]]; then
		[[ ! -d ${FIRMWARE_PATH}/ipk ]] && mkdir -p ${FIRMWARE_PATH}/ipk || rm -rf ${FIRMWARE_PATH}/ipk/*
		cp -rf $(find ${HOME_PATH}/bin/packages/ -type f -name "*.ipk") ${FIRMWARE_PATH}/ipk/ && sync
		sudo tar -czf ipk.tar.gz ipk && sync && sudo rm -rf ipk
	fi
	__info_msg "重命名固件名称"
	if [[ `ls -1 | grep -c "armvirt"` -eq '0' ]]; then
		rename -v "s/^openwrt/${COMPILE_DATE_MD}-${SOURCE}-${LUCI_EDITION}-${LINUX_KERNEL}/" *
	fi
	
	release_info	
}

################################################################################################################
# 准备发布固件页面信息显示
################################################################################################################
function release_info() {
	cd ${MATRIX_TARGET_PATH}
	__yellow_color "开始准备固件发布信息..."
	local diy_part_ipaddr=`awk '{print $3}' ${MATRIX_TARGET_PATH}/$DIY_PART_SH | awk -F= '$1 == "network.lan.ipaddr" {print $2}' | sed "s/'//g" 2>/dev/null`
	local release_ipaddr=${diy_part_ipaddr:-192.168.1.1}
	
	sed -i "s#release_device#${TARGET_PROFILE}#" ${RELEASEINFO_MD} > /dev/null 2>&1
	sed -i "s#default_ip#${release_ipaddr}#" ${RELEASEINFO_MD} > /dev/null 2>&1
	sed -i "s#default_password#-#" ${RELEASEINFO_MD} > /dev/null 2>&1
	sed -i "s#release_source#${LUCI_EDITION}-${SOURCE}#" ${RELEASEINFO_MD} > /dev/null 2>&1
	sed -i "s#release_kernel#${LINUX_KERNEL}#" ${RELEASEINFO_MD} > /dev/null 2>&1
	sed -i "s#repository#${GITHUB_REPOSITORY}#" ${RELEASEINFO_MD} > /dev/null 2>&1
	sed -i "s#matrixtarget#${MATRIX_TARGET}#" ${RELEASEINFO_MD} > /dev/null 2>&1
	
	if [[ "${FIRMWARE_TYPE}" == "lxc" ]]; then
		cat >> ${RELEASEINFO_MD} <<-EOF
		注：「lxc容器专用」
		EOF
	fi

	cat ${RELEASEINFO_MD}
}

################################################################################################################
# 解锁固件分区：Bootloader、Bdata、factory、reserved0，ramips系列路由器专用(固件编译前)
################################################################################################################
function unlock_bootloader() {
	if [[ ${TARGET_BOARD} == "ramips" ]]; then		
		if [[ -f "target/linux/${TARGET_BOARD}/dts/${TARGET_SUBTARGET}_${TARGET_DEVICE}.dts" ]]; then
			local dts_file="target/linux/${TARGET_BOARD}/dts/${TARGET_SUBTARGET}_${TARGET_DEVICE}.dts"
		elif [[ -f "target/linux/${TARGET_BOARD}/dts/${TARGET_SUBTARGET}_${TARGET_PROFILE}.dts" ]]; then
			local dts_file="target/linux/${TARGET_BOARD}/dts/${TARGET_SUBTARGET}_${TARGET_PROFILE}.dts"	
		else
			return
		fi
		__info_msg "dts文件：${dts_file}"
		sed -i "/read-only;/d" ${dts_file}
		if [[ `grep -c "read-only;" ${dts_file}` -eq '0' ]]; then
			__success_msg "固件分区已经解锁！"
			echo UNLOCK="true" >> ${GITHUB_ENV}
		else
			__error_msg "固件分区解锁失败！"
		fi
	else
		__warning_msg "非ramips系列，暂不支持！"
	fi
}
