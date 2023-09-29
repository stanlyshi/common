#!/bin/bash

DEFAULT_COLOR="\033[0m"
BLUE_COLOR="\033[36m"
GREEN_COLOR="\033[32m"
RED_COLOR="\033[31m"
YELLOW_COLOR="\033[33m"

function __error_msg() {
	echo -e "${RED_COLOR}[ERROR]${DEFAULT_COLOR} $*"
}

function __info_msg() {
	echo -e "${BLUE_COLOR}[INFO]${DEFAULT_COLOR} $*"
}

function __success_msg() {
	echo -e "${GREEN_COLOR}[SUCCESS]${DEFAULT_COLOR} $*"
}

function __warning_msg() {
	echo -e "${YELLOW_COLOR}[WARNING]${DEFAULT_COLOR} $*"
}

function __red_msg() {
	echo -e "${RED_COLOR}${DEFAULT_COLOR} $*"
}

function __blue_msg() {
	echo -e "${BLUE_COLOR}${DEFAULT_COLOR} $*"
}

function __green_msg() {
	echo -e "${GREEN_COLOR}${DEFAULT_COLOR} $*"
}

function __yellow_msg() {
	echo -e "${YELLOW_COLOR}${DEFAULT_COLOR} $*"
}

################################################################################################################
# 环境变量
################################################################################################################
function parse_settings() {
	echo "REPOSITORY=${GITHUB_REPOSITORY##*/}" >> ${GITHUB_ENV}
	echo "DIY_PART_SH=${DIY_PART_SH}" >> ${GITHUB_ENV}
	echo "UPLOAD_CONFIG=${UPLOAD_CONFIG}" >> ${GITHUB_ENV}
	
	if [[ "${NOTICE_TYPE}" =~ 'false' ]]; then
		NOTICE_TYPE="false"
	elif [[ -n "$(echo "${NOTICE_TYPE}" |grep -i 'TG\|telegram')" ]]; then
		NOTICE_TYPE="TG"
	elif [[ -n "$(echo "${NOTICE_TYPE}" |grep -i 'PUSH\|pushplus')" ]]; then
		NOTICE_TYPE="PUSH"
	elif [[ -n "$(echo "${NOTICE_TYPE}" |grep -i 'WX\|WeChat')" ]]; then
		NOTICE_TYPE="WX"
	else
		NOTICE_TYPE="false"
	fi
	echo "NOTICE_TYPE=${NOTICE_TYPE}" >> ${GITHUB_ENV}
	
	if [[ FIRMWARE_TYPE == "lxc" ]]; then
		RELEASE_TAG="AutoUpdate-lxc"
	else
		RELEASE_TAG="AutoUpdate"
	fi
	echo "RELEASE_TAG=${RELEASE_TAG}" >> ${GITHUB_ENV}
	
	if [[ ${PACKAGES_ADDR} == "default" ]] || [[ ${ENABLE_PACKAGES_UPDATE} == "false" ]]; then
		echo "PACKAGES_ADDR=default" >> ${GITHUB_ENV}
		echo "ENABLE_PACKAGES_UPDATE=false" >> ${GITHUB_ENV}
	else
		git_packages=`echo "${PACKAGES_ADDR}" | awk -F/ '{print $1}'` 2>/dev/null
		if [[ ${git_packages} == ${GITHUB_ACTOR} ]]; then
			echo "PACKAGES_ADDR=${PACKAGES_ADDR}" >> ${GITHUB_ENV}
			echo "ENABLE_PACKAGES_UPDATE=${ENABLE_PACKAGES_UPDATE}" >> ${GITHUB_ENV}
		else
			echo "插件库所有者：${git_packages}"
			__warning_msg "没有权限更新插件库，关闭\"插件库更新\"！"
			echo "ENABLE_PACKAGES_UPDATE=false" >> ${GITHUB_ENV}
		fi
	fi
	
	echo "SOURCE_ABBR=${SOURCE_ABBR}" >> ${GITHUB_ENV}
	case "${SOURCE_ABBR}" in
	lede|LEDE|Lede)
		export SOURCE_URL="https://github.com/coolsnowwolf/lede"
		export SOURCE_OWNER="Lean's"
		export LUCI_EDITION="18.06"
		export PACKAGE_BRANCH="Lede"
	;;
	openwrt|OPENWRT|Openwrt|OpenWrt|OpenWRT)
		export SOURCE_URL="https://github.com/openwrt/openwrt"
		export SOURCE_OWNER="openwrt's"
		export LUCI_EDITION="$(echo "${SOURCE_BRANCH}" |sed 's/openwrt-//g')"
		export PACKAGE_BRANCH="Official"

	;;
	*)
		__error_msg "不支持${SOURCE_ABBR}源码"
		exit 1
	;;
	esac
	
	# 路径
	echo "HOME_PATH=${GITHUB_WORKSPACE}/openwrt" >> ${GITHUB_ENV}
	echo "BIN_PATH=${GITHUB_WORKSPACE}/openwrt/bin" >> ${GITHUB_ENV}
	echo "UPLOAD_PATH=${GITHUB_WORKSPACE}/openwrt/upgrade" >> ${GITHUB_ENV}
	echo "BUILD_PATH=${GITHUB_WORKSPACE}/openwrt/build" >> ${GITHUB_ENV}
	echo "COMMON_PATH=${GITHUB_WORKSPACE}/openwrt/build/common" >> ${GITHUB_ENV}
	echo "MATRIX_TARGET_PATH=${GITHUB_WORKSPACE}/openwrt/build/${MATRIX_TARGET}" >> ${GITHUB_ENV}
	echo "CONFIG_PATH=${GITHUB_WORKSPACE}/openwrt/build/${MATRIX_TARGET}/config" >> ${GITHUB_ENV}
	echo "CLEAR_FILE_PATH=${GITHUB_WORKSPACE}/openwrt/Clear" >> ${GITHUB_ENV}
	
	# https://github.com/coolsnowwolf/lede/tree/master/package/base-files/files
	echo "FILES_PATH=${GITHUB_WORKSPACE}/openwrt/package/base-files/files" >> ${GITHUB_ENV}
	echo "FILE_BASE_FILES=${GITHUB_WORKSPACE}/openwrt/package/base-files/files/lib/upgrade/keep.d/base-files-essential" >> ${GITHUB_ENV}
	echo "FILE_DELETE=${GITHUB_WORKSPACE}/openwrt/package/base-files/files/etc/deletefile" >> ${GITHUB_ENV}
	echo "FILE_DEFAULT_UCI=${GITHUB_WORKSPACE}/openwrt/package/base-files/files/etc/default_uci" >> ${GITHUB_ENV}
	echo "FILE_DEFAULT_SETTINGS=${GITHUB_WORKSPACE}/openwrt/package/base-files/files/etc/default_settings" >> ${GITHUB_ENV}
	echo "FILE_OPENWRT_RELEASE=${GITHUB_WORKSPACE}/openwrt/package/base-files/files/etc/openwrt_release" >> ${GITHUB_ENV}
	echo "FILE_CONFIG_GEN=${GITHUB_WORKSPACE}/openwrt/package/base-files/files/bin/config_generate" >> ${GITHUB_ENV}
	
	echo "COMPILE_DATE=$(date +%Y%m%d%H%M)" >> ${GITHUB_ENV}
	echo "COMPILE_DATE_CN=$(date +%Y年%m月%d号%H时%M分)" >> ${GITHUB_ENV}
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
	ln -sf ${MATRIX_TARGET}/openwrt ${GITHUB_WORKSPACE}/openwrt
	
	# 将build等文件夹复制到openwrt文件夹下
	#cp -rf `find ./ -maxdepth 1 -type d ! -path './openwrt' ! -path './'` ${GITHUB_WORKSPACE}/openwrt
	cp -rf ${GITHUB_WORKSPACE}/build ${GITHUB_WORKSPACE}/openwrt
	
	# 下载common仓库
	sudo rm -rf ${BUILD_PATH}/common && git clone -b main --depth 1 https://github.com/stanlyshi/common ${BUILD_PATH}/common
	chmod -R +x ${BUILD_PATH}
	
}

################################################################################################################
# 插件库更新
################################################################################################################
function update_packages() {
	gitdate=$(curl -H "Authorization: token ${REPO_TOKEN}" -s "https://api.github.com/repos/${PACKAGES_ADDR}/actions/runs" | jq -r '.workflow_runs[0].created_at')
	gitdate=$(date -d "$gitdate" +%s)
	echo "gitdate=${gitdate}"
	now=$(date -d "$(date '+%Y-%m-%d %H:%M:%S')" +%s)
	echo "now=${now}"
	if [[ $(expr $gitdate + 60) < $now ]]; then
	curl -X POST https://api.github.com/repos/${PACKAGES_ADDR}/dispatches \
	-H "Accept: application/vnd.github.everest-preview+json" \
	-H "Authorization: token ${REPO_TOKEN}" \
	--data '{"event_type": "updated by ${REPOSITORY}"}'
	fi
	echo "packages url: https://github.com/${PACKAGES_ADDR}"
}

################################################################################################################
# 加载源,补丁和自定义设置
################################################################################################################
function do_diy() {
	# https://github.com/coolsnowwolf/lede/blob/master/package/lean/default-settings/files/zzz-default-settings
	export ZZZ_PATH="$(find "${HOME_PATH}/package" -type f -name "*-default-settings" |grep files)"

	cd ${HOME_PATH}
	
	# 检查.config文件是否存在
	if [ -z "$(ls -A "${CONFIG_PATH}/${CONFIG_FILE}" 2>/dev/null)" ]; then
		__error_msg "编译脚本的[${MATRIX_TARGET}配置文件夹内缺少${CONFIG_FILE}文件],请在[${MATRIX_TARGET}/config/]文件夹内补齐"
		echo
		exit 1
	fi
	
	# 检查diy_part.sh文件是否存在
	if [ -z "$(ls -A "${MATRIX_TARGET_PATH}/${DIY_PART_SH}" 2>/dev/null)" ]; then
		__error_msg "编译脚本的[${MATRIX_TARGET}文件夹内缺少${DIY_PART_SH}文件],请在[${MATRIX_TARGET}]文件夹内补齐"
		echo
		exit 1
	fi
	
	# 执行公共脚本
	diy_public
	
	
	# 执行源码库对应的私有脚本
	if [[ "${SOURCE_ABBR}" == "lede" ]]; then
		diy_lede
	elif [[ "${SOURCE_ABBR}" == "openwrt" ]]; then
		diy_openwrt
	fi
	
	# 执行diy_part.sh脚本
	/bin/bash "${MATRIX_TARGET_PATH}/${DIY_PART_SH}"
	
	# 安装插件源
	./scripts/feeds clean
	./scripts/feeds update -a
	./scripts/feeds install -a -p openwrt-packages
	./scripts/feeds install -a > /dev/null 2>&1
	
	# 复制自定义.config文件
	cp -rf "${CONFIG_PATH}/${CONFIG_FILE}" ${HOME_PATH}/.config
}

################################################################################################################
# 生成.config文件
################################################################################################################
function make_defconfig() {
	cd ${HOME_PATH}
	
	# 处理插件冲突
	resolve_conflictions > /dev/null 2>&1
	
	# 生成.config文件
	make defconfig > /dev/null 2>&1
	${HOME_PATH}./scripts/diffconfig.sh > ${GITHUB_WORKSPACE}/${CONFIG_FILE}
	
	export TARGET_BOARD="$(awk -F '[="]+' '/TARGET_BOARD/{print $2}' ${HOME_PATH}/.config)"
	export TARGET_SUBTARGET="$(awk -F '[="]+' '/TARGET_SUBTARGET/{print $2}' ${HOME_PATH}/.config)"
	export FIRMWARE_PATH=${HOME_PATH}/bin/targets/${TARGET_BOARD}/${TARGET_SUBTARGET}
	
	# CPU架构
	if [ `grep -c "CONFIG_TARGET_x86_64=y" .config` -eq '1' ]; then
		export TARGET_PROFILE="x86-64"
	elif [[ `grep -c "CONFIG_TARGET_x86=y" .config` == '1' ]] && [[ `grep -c "CONFIG_TARGET_x86_64=y" .config` == '0' ]]; then
		export TARGET_PROFILE="x86-32"
	elif [[ -n "$(grep -Eo 'CONFIG_TARGET.*armsr.*armv8.*=y' ${HOME_PATH}/.config)" ]]; then
		export TARGET_PROFILE="Armvirt_64"
	elif [[ -n "$(grep -Eo 'CONFIG_TARGET.*armvirt.*64.*=y' ${HOME_PATH}/.config)" ]]; then
		export TARGET_PROFILE="Armvirt_64"
	elif [[ -n "$(grep -Eo 'CONFIG_TARGET.*DEVICE.*=y' ${HOME_PATH}/.config)" ]]; then
		export TARGET_PROFILE="$(grep -Eo "CONFIG_TARGET.*DEVICE.*=y" ${HOME_PATH}/.config | sed -r 's/.*DEVICE_(.*)=y/\1/')"
	else
		export TARGET_PROFILE="$(awk -F '[="]+' '/TARGET_PROFILE/{print $2}' ${HOME_PATH}/.config)"
	fi
	__info_msg "固件CPU架构：${TARGET_PROFILE}"
	
	# 内核版本
	export KERNEL_PATCHVER="$(grep "KERNEL_PATCHVER" "${HOME_PATH}/target/linux/${TARGET_BOARD}/Makefile" |grep -Eo "[0-9]+\.[0-9]+")"
	export KERNEL_VERSION_FILE="kernel-${KERNEL_PATCHVER}"
	if [[ -f "${HOME_PATH}/include/${KERNEL_VERSION_FILE}" ]]; then
		export LINUX_KERNEL=$(egrep -o "${KERNEL_PATCHVER}\.[0-9]+" ${HOME_PATH}/include/${KERNEL_VERSION_FILE})
		[[ -z ${LINUX_KERNEL} ]] && export LINUX_KERNEL="unknown"
	else
		export LINUX_KERNEL=$(egrep -o "${KERNEL_PATCHVER}\.[0-9]+" ${HOME_PATH}/include/kernel-version.mk)
		[[ -z ${LINUX_KERNEL} ]] && export LINUX_KERNEL="unknown"
	fi
	
	__info_msg "内核版本：${LINUX_KERNEL}"
	
	# 内核替换
	if [[ -n "${NEW_KERNEL_PATCHVER}" ]]; then
		if [[ "${NEW_KERNEL_PATCHVER}" == "0" ]]; then
			__info_msg "使用默认内核[ ${KERNEL_PATCHVER} ]编译"
		elif [[ `ls -1 "${HOME_PATH}/target/linux/${TARGET_BOARD}" |grep -c "kernel-${NEW_KERNEL_PATCHVER}"` -eq '1' ]]; then
			sed -i "s/${KERNEL_PATCHVER}/${NEW_KERNEL_PATCHVER}/g" ${HOME_PATH}/target/linux/${TARGET_BOARD}/Makefile
			__success_msg "内核[ ${NEW_KERNEL_PATCHVER} ]更换完成"
		else
			__error_msg "没发现与${TARGET_PROFILE}机型对应[ ${NEW_KERNEL_PATCHVER} ]内核，使用默认内核[ ${KERNEL_PATCHVER} ]编译"
		fi
	fi
	#if [[ -n "${NEW_KERNEL_PATCHVER}" ]] && [[ "${KERNEL_PATCHVER}" != "unknown" ]]; then
	#	sed -i "s/${KERNEL_PATCHVER}/${NEW_KERNEL_PATCHVER}/g" ${HOME_PATH}/target/linux/${TARGET_BOARD}/Makefile
	#	__success_msg "内核从[${KERNEL_PATCHVER}]替换为[${NEW_KERNEL_PATCHVER}]"
	#fi
}

################################################################################################################
# 编译信息
################################################################################################################
function compile_info() {
	cd ${HOME_PATH}
	Plug_in1="$(grep -Eo "CONFIG_PACKAGE_luci-app-.*=y|CONFIG_PACKAGE_luci-theme-.*=y" .config |grep -v 'INCLUDE\|_Proxy\|_static\|_dynamic' |sed 's/=y//' |sed 's/CONFIG_PACKAGE_//g')"
	Plug_in2="$(echo "${Plug_in1}" |sed 's/^/、/g' |sed 's/$/\"/g' |awk '$0=NR$0' |sed 's/^/TIME g \"       /g')"
	echo "${Plug_in2}" >Plug-in
		
	echo
	__red_msg "OpenWrt固件信息"
	__blue_msg "编译源码: ${SOURCE_ABBR}"
	__blue_msg "源码链接: ${SOURCE_URL}"
	__blue_msg "源码分支: ${SOURCE_BRANCH}"
	__blue_msg "源码作者: ${SOURCE_OWNER}"
	__blue_msg "内核版本: ${KERNEL_PATCHVER}"
	__blue_msg "Luci版本: ${LUCI_EDITION}"
	__blue_msg "机型架构: ${TARGET_PROFILE}"
	__blue_msg "固件作者: ${GITHUB_ACTOR}"
	__blue_msg "仓库地址: ${GITHUB_REPO_URL}"
	__blue_msg "编译时间: ${COMPILE_DATE}"
	__green_msg "友情提示：您当前使用【${MATRIX_TARGET}】文件夹编译【${TARGET_PROFILE}】固件"
	echo
	echo
	__red_msg "Github在线编译配置"
	if [[ ${UPLOAD_FIRMWARE} == "true" ]]; then
		__yellow_msg "上传固件在github actions: 开启"
	else
		__blue_msg "上传固件在github actions: 关闭"
	fi
	if [[ ${UPLOAD_CONFIG} == "true" ]]; then
		__yellow_msg "上传[.config]配置文件: 开启"
	else
		__blue_msg "上传[.config]配置文件: 关闭"
	fi
	if [[ ${UPLOAD_BIN_DIR} == "true" ]]; then
		__yellow_msg "上传BIN文件夹(固件+IPK): 开启"
	else
		__blue_msg "上传BIN文件夹(固件+IPK): 关闭"
	fi
	if [[ ${NOTICE_TYPE} == "true" ]]; then
		__yellow_msg "微信/电报通知: 开启"
	else
		__blue_msg "微信/电报通知: 关闭"
	fi
	if [[ ${FIRMWARE_TYPE} == "lxc" ]]; then
		echo
		__yellow_msg "LXC固件：开启"
		echo
		__red_msg "LXC固件自动更新："
		echo " 1、PVE运行："
		__green_msg "pct pull xxx /sbin/openwrt.lxc /usr/sbin/openwrt && chmod +x /usr/sbin/openwrt"
		echo " 注意：将xxx改为个人OpenWrt容器的ID，如100"
		echo " 2、PVE运行："
		__green_msg "openwrt"
		echo
	else
		echo
		__red_msg "自动更新信息"
		TIME z "插件版本: ${AutoUpdate_Version}"
		if [[ ${TARGET_PROFILE} == "x86-64" ]]; then
			__yellow_msg "传统固件: ${Firmware_Legacy}"
			__yellow_msg "UEFI固件: ${Firmware_UEFI}"
			__yellow_msg "固件后缀: ${Firmware_sfx}"
		else
			__yellow_msg "固件名称: ${Up_Firmware}"
			__yellow_msg "固件后缀: ${Firmware_sfx}"
		fi
		__yellow_msg "固件版本: ${Openwrt_Version}"
		__yellow_msg "云端路径: ${Github_UP_RELEASE}"
		__green_msg "编译成功后，会自动把固件发布到指定地址，生成云端路径"
		__green_msg "修改IP、DNS、网关或者在线更新，请输入命令：openwrt"
	fi

	echo
	__red_msg "Github在线编译CPU型号"
	echo `cat /proc/cpuinfo | grep name | cut -f2 -d: | uniq -c`
	__yellow_msg "常见CPU类型及性能排行"
	echo -e "Intel(R) Xeon(R) Platinum 8370C CPU @ 2.80GHz
	Intel(R) Xeon(R) Platinum 8272CL CPU @ 2.60GHz
	Intel(R) Xeon(R) Platinum 8171M CPU @ 2.60GHz
	Intel(R) Xeon(R) CPU E5-2673 v4 @ 2.30GHz
	Intel(R) Xeon(R) CPU E5-2673 v3 @ 2.40GHz"
	echo
	__red_msg " 系统空间      类型   总数  已用  可用 使用率"
	cd ../ && df -hT $PWD && cd ${HOME_PATH}
	echo
	echo
	if [ -n "$(ls -A "${HOME_PATH}/EXT4" 2>/dev/null)" ]; then
		echo
		echo
		chmod -R +x ${HOME_PATH}/EXT4
		source ${HOME_PATH}/EXT4
		rm -rf ${HOME_PATH}/EXT4
	fi
	if [ -n "$(ls -A "${HOME_PATH}/Chajianlibiao" 2>/dev/null)" ]; then
		echo
		echo
		chmod -R +x ${HOME_PATH}/CHONGTU
		source ${HOME_PATH}/CHONGTU
		rm -rf ${HOME_PATH}/{CHONGTU,Chajianlibiao}
		echo
		echo
	fi
	if [ -n "$(ls -A "${HOME_PATH}/Plug-in" 2>/dev/null)" ]; then
		__red_msg "	      已选插件列表"
		chmod -R +x ${HOME_PATH}/Plug-in
		source ${HOME_PATH}/Plug-in
		rm -rf ${HOME_PATH}/{Plug-in,Plug-2}
		echo
	fi
}

################################################################################################################
# 更新仓库
################################################################################################################
function update_repo() {
	cd ${GITHUB_WORKSPACE}

	# 更新插件列表
	update_plugin_list
	
	# 更新COMPILE_YML文件中的matrix.target设置	
	bool_update_target="false"
	bool_update_config="false"
	git clone -b main https://github.com/${GITHUB_REPOSITORY}.git repo
	local COMPILE_YML_TARGET=$(grep 'target: \[' ${GITHUB_WORKSPACE}/.github/workflows/${COMPILE_YML} | sed 's/^[ ]*//g' |grep '^target' |cut -d '#' -f1 |sed 's/\[/\\&/' |sed 's/\]/\\&/') && echo "COMPILE_YML_TARGET=${COMPILE_YML_TARGET}"
	local BUILD_YML_TARGET=$(grep 'target: \[' ${GITHUB_WORKSPACE}/.github/workflows/${BUILD_YML}  |sed 's/^[ ]*//g' |grep '^target' |cut -d '#' -f1 |sed 's/\[/\\&/' |sed 's/\]/\\&/') && echo "BUILD_YML_TARGET=${BUILD_YML_TARGET}"
	if [[ -n "${COMPILE_YML_TARGET}" ]] && [[ -n "${BUILD_YML_TARGET}" ]] && [[ "${COMPILE_YML_TARGET}" != "${BUILD_YML_TARGET}" ]]; then
		sed -i "s/${COMPILE_YML_TARGET}/${BUILD_YML_TARGET}/g" repo/.github/workflows/${COMPILE_YML} && echo "change ${COMPILE_YML_TARGET} to ${BUILD_YML_TARGET}"
		bool_update_target="true"
	fi

	# 更新.config文件
	${HOME_PATH}./scripts/diffconfig.sh > ${GITHUB_WORKSPACE}/${CONFIG_FILE}
	
	cd ${GITHUB_WORKSPACE}/repo
	if [[ `cat ${GITHUB_WORKSPACE}/${CONFIG_FILE}` != `cat build/${MATRIX_TARGET}/config/${CONFIG_FILE}` ]]; then
		bool_update_config="true"
	fi
	cp -rf ${GITHUB_WORKSPACE}/${CONFIG_FILE} build/${MATRIX_TARGET}/config/${CONFIG_FILE}
	__info_msg "bool_update_target=${bool_update_target}; bool_update_config=${bool_update_config}"
	if [[ ${bool_update_target} == "true" ]] || [[ ${bool_update_config} == "true" ]]; then
		local BRANCH_HEAD="$(git rev-parse --abbrev-ref HEAD)"
		git add .
		git commit -m "Update plugins and ${CONFIG_FILE}"
		git push --force "https://${REPO_TOKEN}@github.com/${GITHUB_REPOSITORY}" HEAD:${BRANCH_HEAD}
	else
		__info_msg "Your branch is already up to date with 'origin/main'. Nothing to commit, working tree clean"
	fi
}

################################################################################################################
# 各源码库的公共脚本
################################################################################################################
function diy_public() {
	echo "--------------common_diy_public start--------------"
	echo
	cd ${HOME_PATH}
	
	# 增加插件源
	sed -i '/roacn/d; /stanlyshi/d; /281677160/d; /helloworld/d; /passwall/d; /OpenClash/d' "feeds.conf.default"
	
	if [[ "${SOURCE_ABBR}" == "lede" ]]; then
		cat >>"feeds.conf.default" <<-EOF
		src-git  diypackages https://github.com/roacn/openwrt-packages.git;main
		EOF
		#git clone --depth 1 -b "${SOURCE_BRANCH}" https://github.com/roacn/openwrt-packages ${HOME_PATH}/openwrt-package
		#rm -rf ${HOME_PATH}/openwrt-package/{diy,.github,.gitignore,LICENSE,README.md} 2>/dev/null
		#mv -f ${HOME_PATH}/openwrt-package/* ${HOME_PATH}/package/lean
	else
		cat >>"feeds.conf.default" <<-EOF
		src-git  diypackages https://github.com/281677160/openwrt-package.git;${PACKAGE_BRANCH}
		EOF
		#git clone --depth 1 -b "${SOURCE_BRANCH}" https://github.com/281677160/openwrt-package ${HOME_PATH}/openwrt-package
		#rm -rf ${HOME_PATH}/openwrt-package/{LICENSE,README.md} 2>/dev/null
		#mv -f ${HOME_PATH}/openwrt-package/* ${HOME_PATH}
	fi

	# openwrt.sh
	[[ ! -d "${FILES_PATH}/usr/bin" ]] && mkdir -p ${FILES_PATH}/usr/bin
	cp -rf ${COMMON_PATH}/custom/openwrt.sh ${FILES_PATH}/usr/bin/openwrt && sudo chmod +x ${FILES_PATH}/usr/bin/openwrt
	cp -rf ${COMMON_PATH}/custom/openwrt.lxc.sh ${FILES_PATH}/usr/bin/openwrt.lxc && sudo chmod +x ${FILES_PATH}/usr/bin/openwrt.lxc
	
	# 替换编译前源码中对应目录文件
	if [ -n "$(ls -A "${MATRIX_TARGET_PATH}/diy" 2>/dev/null)" ]; then
		cp -rf ${MATRIX_TARGET_PATH}/diy/* ${FILES_PATH} && chmod -R +x ${FILES_PATH}
	fi
	# 替换编译后固件中对应目录文件（备用）
	if [ -n "$(ls -A "${MATRIX_TARGET_PATH}/files" 2>/dev/null)" ]; then
		rm -rf ${MATRIX_TARGET_PATH}/files/{LICENSE,.*README}
		cp -rf ${MATRIX_TARGET_PATH}/files ${HOME_PATH}
	fi	
	# 打补丁
	if [ -n "$(ls -A "${MATRIX_TARGET_PATH}/patches" 2>/dev/null)" ]; then
		find "${MATRIX_TARGET_PATH}/patches" -type f -name '*.patch' -print0 | sort -z | xargs -I % -t -0 -n 1 sh -c "cat '%'  | patch -d './' -p1 --forward --no-backup-if-mismatch"
	fi
	
	# 自动更新插件（luci-app-autoupdate）
	if [[ ${FIRMWARE_TYPE} == "lxc" ]]; then
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
	

		
	# 修改源码中IP设置
	local def_ipaddress="$(grep "ipaddr:-" "${FILE_CONFIG_GEN}" | grep -v 'addr_offset' | grep -Eo "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+")"
	local new_ipaddress="$(grep "network.lan.ipaddr" ${MATRIX_TARGET_PATH}/${DIY_PART_SH} | grep -Eo "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+")"
	if [[ -n "${new_ipaddress}" ]]; then
		sed -i "s/${def_ipaddress}/${new_ipaddress}/g" ${FILE_CONFIG_GEN}
		__success_msg "IP地址从[${def_ipaddress}]替换为[${new_ipaddress}]"
	else
		__info_msg "使用默认IP地址：${def_ipaddress}"
	fi
	
	# UCI基础设置
	echo '#!/bin/bash' > "${FILE_DEFAULT_UCI}"
	sudo chmod +x "${FILE_DEFAULT_UCI}"
	
	# Openwrt固件升级时需要删除的文件
	echo '#!/bin/bash' > "${FILE_DELETE}"
	sudo chmod +x "${FILE_DELETE}"
	
	# Openwrt初次运行初始化设置
	cp -rf ${COMMON_PATH}/custom/default_settings ${FILE_DEFAULT_SETTINGS}
	sudo chmod +x ${FILE_DEFAULT_SETTINGS}	
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

	echo "reserved for test."
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
# 处理插件冲突
################################################################################################################
function resolve_conflictions() {
	cd ${HOME_PATH}
	echo
	echo "正在执行：判断插件有否冲突减少编译错误"
	make defconfig > /dev/null 2>&1
	rm -rf ${HOME_PATH}/CHONGTU && touch ${HOME_PATH}/CHONGTU
	echo "__blue_msg \"					插件冲突信息\"" > ${HOME_PATH}/CHONGTU
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
			echo "__green_msg \" \"" > ${HOME_PATH}/EXT4
			echo "__red_msg \"EXT4提示：请注意，您选择了ext4安装的固件格式,而检测到您的分配的固件系统分区过小\"" >> ${HOME_PATH}/EXT4
			echo "__yellow_msg \"为避免编译出错,建议修改成950或者以上比较好,已帮您修改成950M\"" >> ${HOME_PATH}/EXT4
			echo "__green_msg \" \"" >> ${HOME_PATH}/EXT4
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
# 获取安装插件信息
################################################################################################################
function update_plugin_list() {
	cd ${HOME_PATH}
	Plug_in1="$(grep -Eo "CONFIG_PACKAGE_luci-app-.*=y|CONFIG_PACKAGE_luci-theme-.*=y" .config |grep -v 'INCLUDE\|_Proxy\|_static\|_dynamic' |sed 's/=y//' |sed 's/CONFIG_PACKAGE_//g')"
	Plug_in2="$(echo "${Plug_in1}" |sed 's/^/、/g' |sed 's/$/\"/g' |awk '$0=NR$0' |sed 's/^/TIME g \"       /g')"
	echo "${Plug_in2}" >Plug-in
	
	# 覆盖原plugin文件
	cp -f Plug-in ${GITHUB_WORKSPACE}/repo/build/${MATRIX_TARGET}/plugin 2>/dev/null
	sed -i 's/ /\n\n/g' ${GITHUB_WORKSPACE}/repo/build/${MATRIX_TARGET}/plugin 2>/dev/null
}

################################################################################################################
# 准备发布固件页面信息显示
################################################################################################################
release_info() {
	cd ${MATRIX_TARGET_PATH}
	sed -i "s#release_device#${TARGET_PROFILE}#" ${MATRIX_TARGET_PATH}/releaseinfo.md 2>/dev/null
	ipaddr=`awk '{print $3}' ${MATRIX_TARGET_PATH}/$DIY_PART_SH | awk -F= '$1 == "network.lan.ipaddr" {print $2}' | sed "s/'//g" 2>/dev/null`
	ipaddr=${ipaddr:-192.168.1.1}
	sed -i "s#default_ip#${ipaddr}#" ${MATRIX_TARGET_PATH}/releaseinfo.md 2>/dev/null
	sed -i "s#default_password#-" ${MATRIX_TARGET_PATH}/releaseinfo.md 2>/dev/null
	sed -i "s#release_source#${LUCI_EDITION}-${SOURCE_ABBR}#" ${MATRIX_TARGET_PATH}/releaseinfo.md 2>/dev/null
	sed -i "s#release_kernel#${KERNEL_PATCHVER}#" ${MATRIX_TARGET_PATH}/releaseinfo.md 2>/dev/null
	sed -i "s#repository#${GITHUB_REPOSITORY}" ${MATRIX_TARGET_PATH}/releaseinfo.md 2>/dev/null
	sed -i "s#matrixtarget#${MATRIX_TARGET}" ${MATRIX_TARGET_PATH}/releaseinfo.md 2>/dev/null

	cat ${MATRIX_TARGET_PATH}/releaseinfo.md 2>/dev/null
}

################################################################################################################
# 整理固件
################################################################################################################
function organize_firmware() {
	[[ ! -d ${HOME_PATH}/upgrade ]] && mkdir -p ${HOME_PATH}/upgrade || rm -rf ${HOME_PATH}/upgrade/*
	echo
	cd ${FIRMWARE_PATH}
	echo "files under ${FIRMWARE_PATH}:"
	ls ${FIRMWARE_PATH}
	
	# 清理无关文件
	if [[ -e ${CLEAR_FILE} ]]; then
		cp -rf ${CLEAR_FILE} ./
		chmod +x ${CLEAR_FILE} && source ${CLEAR_FILE}
		rm -rf ${CLEAR_FILE}
	fi
	rm -rf packages
	sudo rm -rf ${CLEAR_PATH}
	
	case "${TARGET_BOARD}" in
	x86)
		export Firmware_sfx="img.gz"
		export Firmware_Legacy="openwrt-${TARGET_PROFILE}-generic-squashfs-combined.${Firmware_sfx}"
		export Firmware_UEFI="openwrt-${TARGET_PROFILE}-generic-squashfs-combined-efi.${Firmware_sfx}"
		export Firmware_Rootfs="openwrt-${TARGET_PROFILE}-generic-squashfs-rootfs.${Firmware_sfx}"
		export AutoBuild_Uefi="${LUCI_EDITION}-${SOURCE_ABBR}-${TARGET_PROFILE}-${COMPILE_DATE}-uefi"
		export AutoBuild_Legacy="${LUCI_EDITION}-${SOURCE_ABBR}-${TARGET_PROFILE}-${COMPILE_DATE}-legacy"
		export AutoBuild_Rootfs="${LUCI_EDITION}-${SOURCE_ABBR}-${TARGET_PROFILE}-${COMPILE_DATE}-rootfs"
		if [[ FIRMWARE_TYPE == "lxc" ]]; then
			[[ -f ${Firmware_Rootfs} ]] && {
				ROOTFSMD5="$(md5sum ${Firmware_Rootfs} |cut -c1-3)$(sha256sum ${Firmware_Rootfs} |cut -c1-3)"
				cp ${Firmware_Rootfs} ${UPLOAD_PATH}/${AutoBuild_Rootfs}-rootfs-${ROOTFSMD5}.${Firmware_sfx}
				echo "copy ${Firmware_Rootfs} to ${UPLOAD_PATH}/${AutoBuild_Rootfs}-${ROOTFSMD5}.${Firmware_sfx}"
			}
		else
			[[ -f ${Firmware_UEFI} ]] && {
				EFIMD5="$(md5sum ${Firmware_UEFI} |cut -c1-3)$(sha256sum ${Firmware_UEFI} |cut -c1-3)"
				cp -rf "${Firmware_UEFI}" "${UPLOAD_PATH}/${AutoBuild_Uefi}-${EFIMD5}${Firmware_SFX}"
				echo "copy ${Firmware_UEFI} to ${UPLOAD_PATH}/${AutoBuild_Uefi}-${EFIMD5}.${Firmware_sfx}"
			}
			[[ -f ${Firmware_Legacy} ]] && {
				LEGAMD5="$(md5sum ${Firmware_Legacy} |cut -c1-3)$(sha256sum ${Firmware_Legacy} |cut -c1-3)"
				cp -rf "${Firmware_Legacy}" "${UPLOAD_PATH}/${AutoBuild_Legacy}-${LEGAMD5}${Firmware_SFX}"
				echo "copy ${Firmware_Legacy} to ${UPLOAD_PATH}/${AutoBuild_Legacy}-${LEGAMD5}.${Firmware_sfx}"
			}
		fi
	;;
	*)
		export Firmware_sfx="bin"
		export Up_Firmware="openwrt-${TARGET_BOARD}-${TARGET_SUBTARGET}-${TARGET_PROFILE}-squashfs-sysupgrade.${Firmware_sfx}"
		if [[ `ls -1 | grep -c "sysupgrade"` -ge '1' ]]; then
			UP_ZHONGZHUAN="$(ls -1 |grep -Eo ".*${TARGET_PROFILE}.*sysupgrade.*${Firmware_SFX}" |grep -v "rootfs\|ext4\|factory")"
		else
			UP_ZHONGZHUAN="$(ls -1 |grep -Eo ".*${TARGET_PROFILE}.*squashfs.*${Firmware_SFX}" |grep -v "rootfs\|ext4\|factory")"
		fi
		if [[ -f "${UP_ZHONGZHUAN}" ]]; then
			MD5="$(md5sum ${UP_ZHONGZHUAN} | cut -c1-3)$(sha256sum ${UP_ZHONGZHUAN} | cut -c1-3)"
			cp -rf "${UP_ZHONGZHUAN}" "${UPLOAD_PATH}/${AutoBuild_Firmware}-${MD5}${Firmware_SFX}"
		fi
	;;
	esac

	release_info	
}



################################################################################################################
# 解锁固件分区：Bootloader、Bdata、factory、reserved0，ramips系列路由器专用
################################################################################################################
Diy_unlock() {
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
