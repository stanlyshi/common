#!/bin/bash

function __error_msg() {
	echo -e "\033[31m[ERROR]\033[0m $*"
}
function __success_msg() {
	echo -e "\033[32m[SUCCESS]\033[0m $*"
}
function __warning_msg() {
	echo -e "\033[33m[WARNING]\033[0m $*"
}
function __info_msg() {
	echo -e "\033[36m[INFO]\033[0m $*"
}
function __red_color() {
	echo -e "\033[31m$*\033[0m"
}
function __green_color() {
	echo -e "\033[32m$*\033[0m"
}
function __yellow_color() {
	echo -e "\033[33m$*\033[0m"
}
function __blue_color() {
	echo -e "\033[34m$*\033[0m"
}
function __magenta_color() {
	echo -e "\033[35m$*\033[0m"
}
function __cyan_color() {
	echo -e "\033[36m$*\033[0m"
}
function __white_color() {
	echo -e "\033[37m$*\033[0m"
}

################################################################################################################
# 环境变量
################################################################################################################
function parse_settings() {
	source build/$MATRIX_TARGET/settings.ini
	if [[ -n "$INPUTS_SOURCE_BRANCH" ]]; then
		[[ $INPUTS_SOURCE_BRANCH =~ (default|DEFAULT|Default) ]] && SOURCE_BRANCH="$SOURCE_BRANCH" || SOURCE_BRANCH="$INPUTS_SOURCE_BRANCH"
		[[ $INPUTS_CONFIG_FILE =~ (default|DEFAULT|Default) ]] && CONFIG_FILE="$CONFIG_FILE" || CONFIG_FILE="$INPUTS_CONFIG_FILE"
		[[ $INPUTS_BIOS_MODE =~ (default|DEFAULT|Default) ]] && BIOS_MODE="$BIOS_MODE" || BIOS_MODE="$INPUTS_BIOS_MODE"
		[[ $INPUTS_ENABLE_CCACHE =~ (default|DEFAULT|Default) ]] && ENABLE_CCACHE="$ENABLE_CCACHE" || ENABLE_CCACHE="$INPUTS_ENABLE_CCACHE"
		[[ $INPUTS_UPLOAD_FIRMWARE =~ (default|DEFAULT|Default) ]] && UPLOAD_FIRMWARE="$UPLOAD_FIRMWARE" || UPLOAD_FIRMWARE="$INPUTS_UPLOAD_FIRMWARE"
		[[ $INPUTS_UPLOAD_RELEASE =~ (default|DEFAULT|Default) ]] && UPLOAD_RELEASE="$UPLOAD_RELEASE" || UPLOAD_RELEASE="$INPUTS_UPLOAD_RELEASE"

		ENABLE_SSH="$INPUTS_ENABLE_SSH"
	fi
	
	if [[ $NOTICE_TYPE =~ (TG|telegram|Telegram|TELEGRAM) ]]; then
		NOTICE_TYPE="TG"
	elif [[ $NOTICE_TYPE =~ (PUSH|pushplus|Pushplus|PUSHPLUS) ]]; then
		NOTICE_TYPE="PUSH"
	else
		NOTICE_TYPE="false"
	fi
	
	if [[ $PACKAGES_REPO =~ (default|DEFAULT|Default) || -z $PACKAGES_REPO ]]; then
		PACKAGES_REPO="roacn/openwrt-packages"
	fi
	
	local package_repo_owner=`echo "$PACKAGES_REPO" | awk -F/ '{print $1}'` 2>/dev/null
	if [[ $package_repo_owner == $GITHUB_ACTOR ]]; then
		ENABLE_PACKAGES_UPDATE="true"
		update_packages
	else
		ENABLE_PACKAGES_UPDATE="false"
	fi
	
	case "$SOURCE_ABBR" in
	lede|Lede|LEDE)
		SOURCE_URL="https://github.com/coolsnowwolf/lede"
		SOURCE="lede"
		SOURCE_OWNER="Lean's"
		LUCI_EDITION="18.06"
	;;
	openwrt|Openwrt|OpenWrt|OpenWRT|OPENWRT|official|Official|OFFICIAL)
		SOURCE_URL="https://github.com/openwrt/openwrt"
		SOURCE="official"
		SOURCE_OWNER="openwrt's"
		LUCI_EDITION="$(echo $SOURCE_BRANCH |sed 's/openwrt-//g')"
	;;
	lienol|Lienol|LIENOL)
		SOURCE_URL="https://github.com/Lienol/openwrt"
		SOURCE="lienol"
		SOURCE_OWNER="Lienol's"
		LUCI_EDITION="$(echo $SOURCE_BRANCH)"
	;;
	immortalwrt|Immortalwrt|IMMORTALWRT|mortal|immortal)
		SOURCE_URL="https://github.com/immortalwrt/immortalwrt"
		SOURCE="Immortalwrt"
		SOURCE_OWNER="Immortalwrt's"
		LUCI_EDITION="$(echo $SOURCE_BRANCH |sed 's/openwrt-//g')"
	;;
	*)
		__error_msg "不支持$SOURCE_ABBR源码"
		exit 1
	;;
	esac
	
	# 基础设置
	echo "SOURCE_BRANCH=$SOURCE_BRANCH" >> $GITHUB_ENV
	echo "CONFIG_FILE=$CONFIG_FILE" >> $GITHUB_ENV
	echo "FIRMWARE_TYPE=$FIRMWARE_TYPE" >> $GITHUB_ENV
	echo "BIOS_MODE=$BIOS_MODE" >> $GITHUB_ENV
	echo "ENABLE_CCACHE=$ENABLE_CCACHE" >> $GITHUB_ENV
	echo "ENABLE_SSH=$ENABLE_SSH" >> $GITHUB_ENV
	echo "UPLOAD_CONFIG=$UPLOAD_CONFIG" >> $GITHUB_ENV
	echo "UPLOAD_FIRMWARE=$UPLOAD_FIRMWARE" >> $GITHUB_ENV
	echo "UPLOAD_RELEASE=$UPLOAD_RELEASE" >> $GITHUB_ENV
	echo "NOTICE_TYPE=$NOTICE_TYPE" >> $GITHUB_ENV
	echo "DIY_PART_SH=$DIY_PART_SH" >> $GITHUB_ENV
	echo "PACKAGES_REPO=$PACKAGES_REPO" >> $GITHUB_ENV
	echo "PACKAGES_BRANCH=$PACKAGES_BRANCH" >> $GITHUB_ENV	

	echo "REPOSITORY=${GITHUB_REPOSITORY##*/}" >> $GITHUB_ENV
	echo "SOURCE=$SOURCE" >> $GITHUB_ENV
	echo "SOURCE_URL=$SOURCE_URL" >> $GITHUB_ENV
	echo "SOURCE_OWNER=$SOURCE_OWNER" >> $GITHUB_ENV
	echo "LUCI_EDITION=$LUCI_EDITION" >> $GITHUB_ENV
	echo "ENABLE_PACKAGES_UPDATE=$ENABLE_PACKAGES_UPDATE" >> $GITHUB_ENV
	echo "ENABLE_REPO_UPDATE=false" >> $GITHUB_ENV
	echo "GITHUB_API=zzz_api" >> $GITHUB_ENV
	
	# 日期时间
	echo "COMPILE_DATE_MD=$(date +%m.%d)" >> $GITHUB_ENV
	echo "COMPILE_DATE_HM=$(date +%Y%m%d%H%M)" >> $GITHUB_ENV
	echo "COMPILE_DATE_HMS=$(date +%Y%m%d%H%M%S)" >> $GITHUB_ENV
	echo "COMPILE_DATE_CN=$(date +%Y年%m月%d日%H时%M分)" >> $GITHUB_ENV
	echo "COMPILE_DATE_STAMP=$(date -d "$(date +'%Y-%m-%d %H:%M:%S')" +%s)" >> $GITHUB_ENV
	
	# 路径
	HOME_PATH="$GITHUB_WORKSPACE/openwrt"
	echo "HOME_PATH=$HOME_PATH" >> $GITHUB_ENV
	echo "BIN_PATH=$HOME_PATH/bin" >> $GITHUB_ENV
	echo "AUTOUPDATE_PATH=$HOME_PATH/bin/autoupdate" >> $GITHUB_ENV
	echo "FEEDS_PATH=$HOME_PATH/feeds" >> $GITHUB_ENV
	echo "BUILD_PATH=$HOME_PATH/build" >> $GITHUB_ENV
	echo "COMMON_PATH=$HOME_PATH/build/common" >> $GITHUB_ENV
	echo "MATRIX_TARGET_PATH=$HOME_PATH/build/$MATRIX_TARGET" >> $GITHUB_ENV
	echo "CONFIG_PATH=$HOME_PATH/build/$MATRIX_TARGET/config" >> $GITHUB_ENV
	
	# 文件
	echo "DIFFCONFIG_TXT=$HOME_PATH/diffconfig.txt" >> $GITHUB_ENV
	echo "RELEASE_MD=$HOME_PATH/release.md" >> $GITHUB_ENV
	echo "RELEASEINFO_MD=$HOME_PATH/build/$MATRIX_TARGET/release/releaseinfo.md" >> $GITHUB_ENV
	echo "SETTINGS_INI=$HOME_PATH/build/$MATRIX_TARGET/settings.ini" >> $GITHUB_ENV
	echo "FILES_TO_CLEAR=$HOME_PATH/default_clear" >> $GITHUB_ENV
	echo "CONFFLICTIONS=$HOME_PATH/confflictions" >> $GITHUB_ENV
	
	# 源码files文件夹
	# https://github.com/coolsnowwolf/lede/tree/master/package/base-files/files
	echo "FILES_PATH=$HOME_PATH/package/base-files/files" >> $GITHUB_ENV
	echo "FILE_DEFAULT_UCI=$HOME_PATH/package/base-files/files/etc/default_uci" >> $GITHUB_ENV
	echo "FILES_TO_DELETE=$HOME_PATH/package/base-files/files/etc/default_delete" >> $GITHUB_ENV
	echo "FILES_TO_KEEP=$HOME_PATH/package/base-files/files/lib/upgrade/keep.d/base-files-essential" >> $GITHUB_ENV
	echo "FILENAME_DEFAULT_UCI=default_uci" >> $GITHUB_ENV
	echo "FILENAME_DEFAULT_SETTINGS=default_settings" >> $GITHUB_ENV
	echo "FILENAME_DEFAULT_RUNONCE=default_settings_runonce" >> $GITHUB_ENV
	echo "FILENAME_CONFIG_GEN=config_generate" >> $GITHUB_ENV
	echo "FILENAME_TO_DELETE=default_delete" >> $GITHUB_ENV
	
	local cpu_name=$(cat /proc/cpuinfo | grep name | cut -d: -f2 | uniq | sed 's/^[[:space:]]\+//')
	echo "::notice title=GithubCPU::$cpu_name"
	echo "::notice title=编译时间::$(date +'%Y-%m-%d %H:%M:%S')"
	echo "::notice title=源码链接::$SOURCE_URL"
	echo "::notice title=源码分支::$SOURCE_BRANCH"
	echo "::notice title=固件类型::$FIRMWARE_TYPE"
	echo "::notice title=LUCI版本::$LUCI_EDITION"
}

################################################################################################################
# 编译开始通知
################################################################################################################
function notice_begin() {
	if [[ "$NOTICE_TYPE" == "TG" ]]; then
		curl -k --data chat_id="$TELEGRAM_CHAT_ID" --data "text=✨主人✨：您正在使用【$REPOSITORY】仓库【$MATRIX_TARGET】文件夹编译【$SOURCE-$LUCI_EDITION】固件,请耐心等待...... 😋" "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage"
	elif [[ "$NOTICE_TYPE" == "PUSH" ]]; then
		curl -k --data token="$PUSH_PLUS_TOKEN" --data title="开始编译【$SOURCE-$MATRIX_TARGET】" --data "content=✨主人✨：您正在使用【$REPOSITORY】仓库【$MATRIX_TARGET】文件夹编译【$SOURCE-$LUCI_EDITION】固件,请耐心等待...... 😋" "http://www.pushplus.plus/send"
	fi
}

################################################################################################################
# 编译完成通知
################################################################################################################
function notice_end() {
	if [[ "$NOTICE_TYPE" == "TG" ]]; then
		curl -k --data chat_id="$TELEGRAM_CHAT_ID" --data "text=🎉 我亲爱的✨主人✨：您使用【$REPOSITORY】仓库【$MATRIX_TARGET】文件夹编译的【$FIRMWARE_NAME_PREFIX】固件顺利编译完成了！💐 https://github.com/$GITHUB_REPOSITORY/releases" "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage"
	elif [[ "$NOTICE_TYPE" == "PUSH" ]]; then
		curl -k --data token="$PUSH_PLUS_TOKEN" --data title="【$SOURCE-$TARGET_PROFILE】编译成功" --data "content=🎉 我亲爱的✨主人✨：您使用【$REPOSITORY】仓库【$MATRIX_TARGET】文件夹编译的【$FIRMWARE_NAME_PREFIX】固件顺利编译完成了！💐 https://github.com/$GITHUB_REPOSITORY/releases" "http://www.pushplus.plus/send"
	fi
}

################################################################################################################
# 初始化编译环境
################################################################################################################
function init_environment() {
	sudo -E apt-get -qq update -y
	#sudo -E apt-get -qq full-upgrade -y
	sudo -E apt-get -qq install -y ack antlr3 aria2 asciidoc autoconf automake autopoint binutils bison \
	build-essential bzip2 ccache cmake cpio curl device-tree-compiler fastjar flex g++-multilib gawk \
	gcc-multilib gettext git git-core gperf haveged help2man intltool lib32stdc++6 libc6-dev-i386 libelf-dev \
	libfuse-dev libglib2.0-dev libgmp3-dev libltdl-dev libmpc-dev libmpfr-dev libncurses5-dev libncursesw5-dev \
	libpcap0.8-dev libpython3-dev libreadline-dev libssl-dev libtool libz-dev lrzsz mkisofs msmtp \
	nano ninja-build p7zip p7zip-full patch pkgconf python2.7 python3 python3-pip qemu-utils rename rsync \
	scons squashfs-tools subversion swig texinfo tree uglifyjs unzip upx upx-ucl vim wget xmlto xxd zlib1g-dev
	#sudo -E apt-get -qq autoremove -y --purge
	#sudo -E apt-get -qq clean
	sudo timedatectl set-timezone "$TZ"
	# "/"目录创建文件夹$MATRIX_TARGET
	sudo mkdir -p /$MATRIX_TARGET
	sudo chown $USER:$GROUPS /$MATRIX_TARGET
	git config --global user.email "41898282+github-actions[bot]@users.noreply.github.com"
	git config --global user.name "github-actions[bot]"
}

################################################################################################################
# 下载源码
################################################################################################################
function git_clone_source() {
	# 在每matrix.target目录下下载源码
	git clone -b $SOURCE_BRANCH $SOURCE_URL openwrt > /dev/null 2>&1
	ln -sf /$MATRIX_TARGET/openwrt $HOME_PATH
	
	# 将build等文件夹复制到openwrt文件夹下
	cd $GITHUB_WORKSPACE
	cp -rf $(find ./ -maxdepth 1 -type d ! -path './openwrt' ! -path './') $HOME_PATH/
	
	# 下载common仓库
	sudo rm -rf $COMMON_PATH && git clone -b main --depth 1 https://github.com/stanlyshi/common $COMMON_PATH
	chmod -Rf +x $BUILD_PATH
	
}

################################################################################################################
# 插件源仓库更新
################################################################################################################
function update_packages() {
	local gitdate=$(curl -H "Authorization: token $REPO_TOKEN" -s "https://api.github.com/repos/$PACKAGES_REPO/actions/runs" | jq -r '.workflow_runs[0].created_at')
	local gitdate_timestamp=$(date -d "$gitdate" +%s)
	local gitdate_hms="$(date -d "$gitdate" '+%Y-%m-%d %H:%M:%S')"
	echo "github latest merge upstream timestamp: $gitdate_timestamp, time: $gitdate_hms"
	local now_hms="$(date '+%Y-%m-%d %H:%M:%S')"
	local now_timestamp=$(date -d "$now_hms" +%s)
	echo "time now timestamp: $now_timestamp, time: $now_hms"
	if [[ $(($gitdate_timestamp+1800)) < $now_timestamp ]]; then
		curl -X POST https://api.github.com/repos/$PACKAGES_REPO/dispatches \
		-H "Accept: application/vnd.github.everest-preview+json" \
		-H "Authorization: token $REPO_TOKEN" \
		--data "{\"event_type\": \"updated by ${GITHUB_REPOSITORY##*/}\"}"
	fi
	__info_msg "packages url: https://github.com/$PACKAGES_REPO"
}

################################################################################################################
# 加载源,补丁和自定义设置
################################################################################################################
function do_diy() {
	cd $HOME_PATH

	# 添加插件源、更新插件源
	update_feeds
	
	# 执行公共脚本
	diy_public
	
	# 执行私有脚本
	if [[ $SOURCE =~ (lede|Lede|LEDE) ]]; then
		diy_lede
	elif [[ $SOURCE =~ (openwrt|Openwrt|OpenWrt|OpenWRT|OPENWRT|official|Official|OFFICIAL) ]]; then
		diy_openwrt
	elif [[ $SOURCE =~ (lienol|Lienol|LIENOL) ]]; then
		diy_lienol
	elif [[ $SOURCE =~ (immortalwrt|Immortalwrt|IMMORTALWRT|mortal|immortal) ]]; then
		diy_immortalwrt
	fi
	
	# 执行diy_part.sh脚本
	/bin/bash "$MATRIX_TARGET_PATH/$DIY_PART_SH"
	
	# 再次更新插件源，并安装插件源
	./scripts/feeds update -a > /dev/null 2>&1 && ./scripts/feeds install -a > /dev/null 2>&1
		
	# 修改.config文件
	modify_config
	
	# 编译机型CPU架构、内核版本等信息，替换内核等
	firmware_settings
}

################################################################################################################
# 插件源
################################################################################################################
function update_feeds() {
	echo "--------------common_update_feeds start--------------"
	echo
	
	cd $HOME_PATH
	
	# 添加插件源
	__yellow_color "开始添加插件源..."
	local packages_url="https://github.com/$PACKAGES_REPO.git"
	local packages_branch="$PACKAGES_BRANCH"
	local packages="pkg$GITHUB_ACTOR"
	__info_msg "源码：$SOURCE 插件源仓库：$packages_url 插件源分支：$packages_branch 插件源文件夹：$packages"
	
	sed -i "/${packages}/d; /#/d; /^$/d; /ssrplus/d; /helloworld/d; /passwall/d; /OpenClash/d" "feeds.conf.default"
	
	# 当插件源添加至 feeds.conf.default 首行时，优先安装自己添加的插件源
	#sed -i "1i src-git $packages $packages_url;$packages_branch" "feeds.conf.default"
	
	# 当插件源添加至 feeds.conf.default 结尾时，重复插件，先删除相应文件，操作完毕后，再一次运行./scripts/feeds update -a，即可更新对应的.index与target.index文件
	if [[ -z "$packages_branch" ]]; then
		cat >> "feeds.conf.default" <<-EOF
		src-git $packages $packages_url
		EOF
	else
		cat >> "feeds.conf.default" <<-EOF
		src-git $packages $packages_url;$packages_branch
		EOF
	fi
	
	# 更新插件源
	__yellow_color "开始更新插件源..."
	./scripts/feeds clean
	./scripts/feeds update -a > /dev/null 2>&1
	sudo rm -rf $FEEDS_PATH/$packages/{LICENSE,*README*,*readme*,.git,.github,.gitignore} > /dev/null 2>&1
	
	# 删除自己插件源不用的文件
	local files_to_delete=(".git" ".github")
	for X in $files_to_delete[*]; do
		find $FEEDS_PATH -maxdepth 3 -type d -name "$X" | grep "$packages" | xargs sudo rm -rf {}
	done
	
	# 删除源码中重复插件及依赖
	for X in $(ls $FEEDS_PATH/$packages); do
		find $FEEDS_PATH -maxdepth 3 -type d -name "$X" | grep -v "$packages" | xargs sudo rm -rf {}
	done
	
	# 设置中文语言包(官方：zh_Hans，Lede：zh-cn；对缺失相应文件的插件进行补充)
	__yellow_color "开始设置中文语言包..."	
	for e in $(ls -d $FEEDS_PATH/$packages/luci-*/po); do
		if [[ -d $e/zh-cn && ! -d $e/zh_Hans ]]; then
			rm -rf $e/zh_Hans && ln -s zh-cn $e/zh_Hans 2>/dev/null
		elif [[ -d $e/zh_Hans && ! -d $e/zh-cn ]]; then
			rm -rf $e/zh-cn && ln -s zh_Hans $e/zh-cn 2>/dev/null
		fi
	done	
	
	echo
	echo "--------------common_update_feeds end--------------"
}

################################################################################################################
# 各源码库的公共脚本(文件检测、添加插件源、diy、files、patch等，以及Openwrt编译完成后的首次运行设置)
################################################################################################################
function diy_public() {
	echo "--------------common_diy_public start--------------"
	echo
	
	cd $HOME_PATH

	__yellow_color "开始检测文件是否存在..."
	# 检查.config文件是否存在
	if [ -z "$(ls -A "$CONFIG_PATH/$CONFIG_FILE" 2>/dev/null)" ]; then
		__error_msg "编译脚本的[$MATRIX_TARGET配置文件夹内缺少$CONFIG_FILE文件],请在[$MATRIX_TARGET/config/]文件夹内补齐"
		exit 1
	fi
	
	# 检查diy_part.sh文件是否存在
	if [ -z "$(ls -A "$MATRIX_TARGET_PATH/$DIY_PART_SH" 2>/dev/null)" ]; then
		__error_msg "编译脚本的[$MATRIX_TARGET文件夹内缺少$DIY_PART_SH文件],请在[$MATRIX_TARGET]文件夹内补齐"
		exit 1
	fi

	__yellow_color "开始替换diy文件夹内文件..."
	# 替换编译前源码中对应目录文件
	sudo rm -rf $MATRIX_TARGET_PATH/diy/{*README*,*readme*} > /dev/null 2>&1
	if [ -n "$(ls -A "$MATRIX_TARGET_PATH/diy" 2>/dev/null)" ]; then
		cp -rf $MATRIX_TARGET_PATH/diy/* $HOME_PATH > /dev/null 2>&1
	fi
	
	__yellow_color "开始替换files文件夹内文件..."
	# 替换编译后固件中对应目录文件（备用）
	sudo rm -rf $MATRIX_TARGET_PATH/files/{*README*,*readme*} > /dev/null 2>&1
	if [ -n "$(ls -A "$MATRIX_TARGET_PATH/files" 2>/dev/null)" ]; then
		cp -rf $MATRIX_TARGET_PATH/files $HOME_PATH > /dev/null 2>&1
	fi
	
	__yellow_color "开始执行补丁文件..."
	# 打补丁
	sudo rm -rf $MATRIX_TARGET_PATH/patches/{*README*,*readme*} > /dev/null 2>&1
	if [ -n "$(ls -A "$MATRIX_TARGET_PATH/patches" 2>/dev/null)" ]; then
		find "$MATRIX_TARGET_PATH/patches" -type f -name '*.patch' -print0 | sort -z | xargs -I % -t -0 -n 1 sh -c "cat '%'  | patch -d './' -p1 --forward --no-backup-if-mismatch"
	fi
	
	#__yellow_color "开始添加openwrt.sh(或openwrt.lxc.sh)..."
	# openwrt.sh
	#[[ ! -d "$FILES_PATH/usr/bin" ]] && mkdir -p $FILES_PATH/usr/bin
	#if [[ "$FIRMWARE_TYPE" == "lxc" ]]; then
	#	wget https://raw.githubusercontent.com/stanlyshi/pve/main/openwrt.lxc.sh -O /usr/bin/openwrt $FILES_PATH/usr/bin/openwrt && sudo chmod +x $FILES_PATH/usr/bin/openwrt
	#else
	#	wget https://raw.githubusercontent.com/stanlyshi/luci-app-autoupdate/main/root/usr/bin/autoupdate -O  $FILES_PATH/usr/bin/openwrt && sudo chmod +x $FILES_PATH/usr/bin/openwrt
	#fi
	
	__yellow_color "开始设置自动更新插件..."
	# 自动更新插件（luci-app-autoupdate）
	if [[ $FIRMWARE_TYPE == "lxc" ]]; then
		find $HOME_PATH/feeds -type d -name "luci-app-autoupdate" | xargs -i sudo rm -rf {}
		find $HOME_PATH/package -type d -name "luci-app-autoupdate" | xargs -i sudo rm -rf {}
		if [[ -n "$(grep "luci-app-autoupdate" $HOME_PATH/include/target.mk)" ]]; then
			sed -i 's/luci-app-autoupdate//g' $HOME_PATH/include/target.mk
		fi
		__info_msg "lxc固件，删除自动更新插件"
	else
		find $HOME_PATH/feeds -type d -name "luci-app-autoupdate" | xargs -i sudo rm -rf {}
		find $HOME_PATH/package -type d -name "luci-app-autoupdate" | xargs -i sudo rm -rf {}
		git clone https://github.com/stanlyshi/luci-app-autoupdate $HOME_PATH/package/luci-app-autoupdate 2>/dev/null
		if [[ `grep -c "luci-app-autoupdate" $HOME_PATH/include/target.mk` -eq '0' ]]; then
			sed -i 's/DEFAULT_PACKAGES:=/DEFAULT_PACKAGES:=luci-app-autoupdate luci-app-ttyd /g' $HOME_PATH/include/target.mk
		fi
		if [[ -d "$HOME_PATH/package/luci-app-autoupdate" ]]; then
			__info_msg "增加定时更新固件的插件成功"
		else
			__error_msg "插件源码下载失败"
		fi
		# autoupdate插件版本
		if [[ -f "$HOME_PATH/package/luci-app-autoupdate/root/usr/bin/autoupdate" ]]; then
			AUTOUPDATE_VERSION=$(grep -Eo "Version=V[0-9.]+" "$HOME_PATH/package/luci-app-autoupdate/root/usr/bin/autoupdate" |grep -Eo [0-9.]+)
			echo "AUTOUPDATE_VERSION=$AUTOUPDATE_VERSION" >> $GITHUB_ENV
			__info_msg "luci-app-autoupdate版本：$AUTOUPDATE_VERSION"
		fi
	fi

	# "默认设置文件..."
	# https://github.com/coolsnowwolf/lede/blob/master/package/lean/default-settings/files/zzz-default-settings
	export ZZZ_PATH="$(find "$HOME_PATH/package" -type f -name "*-default-settings" | grep files)"
	if [[ -n "$ZZZ_PATH" ]]; then  
		echo "ZZZ_PATH=$ZZZ_PATH" >> $GITHUB_ENV
	fi
	
	__yellow_color "开始修改IP设置..."
	# 修改源码中IP设置
	local def_ipaddress="$(grep "ipaddr:-" "$FILES_PATH/bin/$FILENAME_CONFIG_GEN" | grep -v 'addr_offset' | grep -Eo "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+")"
	local new_ipaddress="$(grep -E "^uci set network.lan.ipaddr" $MATRIX_TARGET_PATH/$DIY_PART_SH | grep -Eo "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+")"
	if [[ -n "$def_ipaddress" && -n "$new_ipaddress" ]]; then
		sed -i "s/${def_ipaddress}/${new_ipaddress}/g" $FILES_PATH/bin/$FILENAME_CONFIG_GEN
		__info_msg "IP地址从[$def_ipaddress]替换为[$new_ipaddress]"
	else
		__info_msg "使用默认IP地址：$def_ipaddress"
	fi
	
	__yellow_color "开始执行其它设置..."
	# Openwrt初次运行初始化设置	
	# default_uci文件，UCI基础设置
	echo "#!/bin/sh" > $FILES_PATH/etc/$FILENAME_DEFAULT_UCI && sudo chmod +x $FILES_PATH/etc/$FILENAME_DEFAULT_UCI
	
	cp -rf $COMMON_PATH/custom/$FILENAME_DEFAULT_RUNONCE $FILES_PATH/etc/init.d/$FILENAME_DEFAULT_RUNONCE && sudo chmod +x $FILES_PATH/etc/init.d/$FILENAME_DEFAULT_RUNONCE
	cp -rf $COMMON_PATH/custom/$FILENAME_DEFAULT_SETTINGS $FILES_PATH/etc/$FILENAME_DEFAULT_SETTINGS && sudo chmod +x $FILES_PATH/etc/$FILENAME_DEFAULT_SETTINGS

	cat >> $FILES_PATH/etc/$FILENAME_DEFAULT_SETTINGS <<-EOF
	rm -rf /etc/init.d/$FILENAME_DEFAULT_RUNONCE
	rm -rf /etc/$FILENAME_DEFAULT_UCI
	rm -rf /etc/$FILENAME_TO_DELETE
	rm -rf /etc/$FILENAME_DEFAULT_SETTINGS
	exit 0
	EOF
	
	# default_delete文件，Openwrt固件升级时需要删除的文件
	echo "#!/bin/sh" > $FILES_PATH/etc/$FILENAME_TO_DELETE && sudo chmod +x "$FILES_PATH/etc/$FILENAME_TO_DELETE"
	
	# base-files-essential文件，Openwrt固件升级时需要保留的文件
	if [[ -z "$(grep "background" $FILES_TO_KEEP)" ]]; then
		cat >> "$FILES_TO_KEEP" <<-EOF
		/www/luci-static/argon/background/
		/etc/smartdns/custom.conf
		EOF
	fi
	
	echo
	echo "--------------common_diy_public end--------------"
}

################################################################################################################
# LEDE源码库的私有脚本(LEDE源码对应的修改，请在此处)
################################################################################################################
function diy_lede() {
	echo "--------------common_diy_lede start--------------"
	echo
	
	cd $HOME_PATH
	
	if [[ -n "$ZZZ_PATH" ]]; then  
		#__info_msg "去除防火墙规则"
		#sed -i '/to-ports 53/d' $ZZZ_PATH

		__info_msg "设置密码为空"
		sed -i '/CYXluq4wUazHjmCDBCqXF/d' $ZZZ_PATH
	fi

	# 修复后台管理页面无法打开，降级openssl到1.1.1版本
	#if [[ "$FIRMWARE_TYPE" == "lxc" ]]; then
	#	__info_msg "修复lxc固件openssl"
	#	sudo rm -rf "$HOME_PATH/include/openssl-module.mk"
	#	sudo rm -rf "$HOME_PATH/package/libs/openssl"
	#	cp -rf "$HOME_PATH/build/common/share/include/openssl-engine.mk" "$HOME_PATH/include/openssl-engine.mk"
	#	cp -rf "$HOME_PATH/build/common/share/package/libs/openssl" "$HOME_PATH/package/libs/openssl"
	#fi

	echo
	echo "--------------common_diy_lede end--------------"
}

################################################################################################################
# 官方源码库的私有脚本(官方源码对应的修改，请在此处)
################################################################################################################
function diy_openwrt() {
	echo "--------------common_diy_openwrt start--------------"
	echo
	
	cd $HOME_PATH

	echo "Reserved for Future Use."
	
	echo
	echo "--------------common_diy_openwrt end--------------"
}

################################################################################################################
# LIENOL源码库的私有脚本(LIENOL源码对应的修改，请在此处)
################################################################################################################
function diy_lienol() {
	echo "--------------common_diy_lienol start--------------"
	echo
	
	cd $HOME_PATH

	echo "Reserved for Future Use."
	
	echo
	echo "--------------common_diy_lienol end--------------"
}

################################################################################################################
# IMMORTALWRT源码库的私有脚本(IMMORTALWRT源码对应的修改，请在此处)
################################################################################################################
function diy_immortalwrt() {
	echo "--------------common_diy_immortalwrt start--------------"
	echo
	
	cd $HOME_PATH

	echo "Reserved for Future Use."
	
	echo
	echo "--------------common_diy_immortalwrt end--------------"
}

################################################################################################################
# 修改.config文件配置
################################################################################################################
function modify_config() {
	echo "--------------common_modify_config start--------------"
	echo
	cd $HOME_PATH
	rm -rf $CONFFLICTIONS && touch $CONFFLICTIONS

	__yellow_color "开始处理.config文件..."
	
	# 复制自定义.config文件
	cp -rf $CONFIG_PATH/$CONFIG_FILE $HOME_PATH/.config
	make defconfig > /dev/null 2>&1
	
	# 缓存加速
	if [[ $ENABLE_CCACHE =~ (fast|Fast|FAST) ]]; then
		__info_msg "快速缓存加速，如编译出错，请尝试删除缓存，或切换为普通加速，或关闭缓存加速"
		sed -i '/CONFIG_DEVEL/d' $HOME_PATH/.config > /dev/null 2>&1
		sed -i '/CONFIG_CCACHE/d' $HOME_PATH/.config > /dev/null 2>&1
		sed -i '$a CONFIG_DEVEL=y' $HOME_PATH/.config > /dev/null 2>&1
		sed -i '$a CONFIG_CCACHE=y' $HOME_PATH/.config > /dev/null 2>&1
	elif [[ $ENABLE_CCACHE =~ (true|True|TRUE|normal|Normal|NORMAL) ]]; then
		__info_msg "普通缓存加速，如编译出错，请尝试删除缓存，或关闭缓存加速"
		sed -i '/CONFIG_DEVEL/d' $HOME_PATH/.config > /dev/null 2>&1
		sed -i '/CONFIG_CCACHE/d' $HOME_PATH/.config > /dev/null 2>&1
	else
		__info_msg "关闭缓存加速，希望快速编译，请在settings.ini中开启缓存加速"
		sed -i '/CONFIG_DEVEL/d' $HOME_PATH/.config > /dev/null 2>&1
		sed -i '/CONFIG_CCACHE/d' $HOME_PATH/.config > /dev/null 2>&1
	fi
	
	# lxc模式下编译.tar.gz固件
	if [[ "$FIRMWARE_TYPE" == "lxc" ]]; then
		sed -Ei 's/.*(CONFIG_TARGET_ROOTFS_TARGZ).*/\1=y/g' $HOME_PATH/.config
		__info_msg "lxc固件，添加对openwrt-generic-rootfs.tar.gz文件编译"
	fi
	
	# https连接，检测修正，主要针对官方源码
	# CONFIG_PACKAGE_ca-bundle=y 默认已经选择
	# liubustream-mbedtls、liubustream-openssl、libustream-wolfssl，三者在后面设置
	if [[ $SOURCE =~ (openwrt|Openwrt|OpenWrt|OpenWRT|OPENWRT|official|Official|OFFICIAL) ]]; then
		sed -Ei 's/.*(CONFIG_PACKAGE_ca-certificates).*/\1=y/g' $HOME_PATH/.config
		sed -Ei 's/.*(CONFIG_PACKAGE_libustream-openssl).*/\1=y/g' $HOME_PATH/.config
		sed -Ei 's/.*(CONFIG_PACKAGE_libustream-mbedtls).*/# \1 is not set/g' $HOME_PATH/.config
		sed -Ei 's/.*(CONFIG_PACKAGE_libustream-wolfssl).*/# \1 is not set/g' $HOME_PATH/.config
		__info_msg "官方源码，已经设置为支持https连接"
	fi
	
	# 官方源码：'状态'、'网络'、'系统'等主菜单，在默认情况下是未选中状态，进行修正
	if [[ $SOURCE =~ (openwrt|Openwrt|OpenWrt|OpenWRT|OPENWRT|official|Official|OFFICIAL) ]]; then
		sed -Ei 's/.*(CONFIG_PACKAGE_luci-mod-admin-full).*/\1=y/g' $HOME_PATH/.config
		#sed -Ei 's/.*(CONFIG_PACKAGE_luci-mod-dsl).*/\1=y/g' $HOME_PATH/.config
		sed -Ei 's/.*(CONFIG_PACKAGE_luci-mod-network).*/\1=y/g' $HOME_PATH/.config
		sed -Ei 's/.*(CONFIG_PACKAGE_luci-mod-status).*/\1=y/g' $HOME_PATH/.config
		sed -Ei 's/.*(CONFIG_PACKAGE_luci-mod-system).*/\1=y/g' $HOME_PATH/.config
		__info_msg "官方源码，'状态'、'系统'等主菜单检测设置"
	fi
	
	# Lede源码：修复lxc固件openssl无法打开后台管理界面，以wolfssl替代openssl(仅lede源码需要修改，官方不需要)
	if [[ $FIRMWARE_TYPE == "lxc" &&  $SOURCE =~ (lede|Lede|LEDE) ]]; then
		# 依赖关系
		# LuCI -> Collections ->  [ ] luci-ssl(依赖libustream-mbedtls)
		# LuCI -> Collections ->  [ ] luci-ssl-openssl(依赖libustream-openssl)
		# Utilities           ->  [ ] cache-domains-mbedtls(依赖libustream-mbedtls)
		# Utilities           ->  [ ] cache-domains-openssl(依赖libustream-openssl)
		# Utilities           ->      cache-domains-wolfssl(依赖libustream-wolfssl)
		# 库
		# Libraries           ->  [ ] libustream-mbedtls(库文件，三选一，依赖libmbedtls)
		# Libraries           ->  [ ] libustream-openssl(库文件，三选一，依赖libopenssl)
		# Libraries           ->  [*] libustream-wolfssl(库文件，三选一，依赖libwolfssl)
		# Libraries  ->  SSL  ->  [*] libmbedtls(库文件，自动勾选，无需关注)
		# Libraries  ->  SSL  ->  [*] libopenssl(库文件，自动勾选，无需关注)
		# Libraries  ->  SSL  ->  [*] libwolfssl(库文件，自动勾选，无需关注)
		# 插件
		# LuCI->Applications  ->  [ ] luci-app-cshark(依赖Network->cshark,cshark依赖libustream-mbedtls)
		
		sed -Ei 's/.*(CONFIG_PACKAGE_libustream-wolfssl).*/\1=y/g' $HOME_PATH/.config
		sed -Ei 's/.*(CONFIG_PACKAGE_libustream-mbedtls).*/# \1 is not set/g' $HOME_PATH/.config
		sed -Ei 's/.*(CONFIG_PACKAGE_libustream-openssl).*/# \1 is not set/g' $HOME_PATH/.config
		sed -i '/CONFIG_PACKAGE_luci-ssl-openssl=y/d' $HOME_PATH/.config
		sed -i '/CONFIG_PACKAGE_luci-ssl=y/d' $HOME_PATH/.config
		sed -i '/CONFIG_PACKAGE_luci-app-cshark=y/d' $HOME_PATH/.config
		#sed -i '$a # CONFIG_PACKAGE_luci-ssl-openssl is not set' $HOME_PATH/.config
		#sed -i '$a # CONFIG_PACKAGE_luci-ssl is not set' $HOME_PATH/.config
		#sed -i '$a # CONFIG_PACKAGE_luci-app-cshark is not set' $HOME_PATH/.config
		
		if [[ `grep -c "CONFIG_PACKAGE_cache-domains-mbedtls=y" $HOME_PATH/.config` -ge '1' || `grep -c "CONFIG_PACKAGE_cache-domains-openssl=y" $HOME_PATH/.config` -ge '1' ]]; then
			sed -Ei 's/.*(CONFIG_PACKAGE_cache-domains-wolfssl).*/\1=y/g' $HOME_PATH/.config
			sed -Ei 's/.*(CONFIG_PACKAGE_cache-domains-mbedtls).*/# \1 is not set/g' $HOME_PATH/.config
			sed -Ei 's/.*(CONFIG_PACKAGE_cache-domains-openssl).*/# \1 is not set/g' $HOME_PATH/.config
			echo "__error_msg \"lxc固件下，您选择cache-domains-mbedtls或cache-domains-openssl，与cache-domains-wolfssl库有冲突，替换为cache-domains-wolfssl\"" >> $CONFFLICTIONS
			echo "" >> $CONFFLICTIONS
		fi
	else
		# 非lede源码lxc模式的其它固件：openwrt的所有固件、lede普通固件		
		# 非强制使用openssl，由.config决定，只解决冲突
		if [[ `grep -c "CONFIG_PACKAGE_libustream-openssl=y" $HOME_PATH/.config` -ge '1' ]]; then
			if [[ `grep -c "CONFIG_PACKAGE_libustream-mbedtls=y" $HOME_PATH/.config` -ge '1' ]]; then
				sed -Ei 's/.*(CONFIG_PACKAGE_libustream-mbedtls).*/# \1 is not set/g' $HOME_PATH/.config
				echo "__error_msg \"您同时选择libustream-mbedtls和libustream-openssl，库有冲突，只能二选一，已删除libustream-mbedtls库\"" >> $CONFFLICTIONS
				echo "" >> $CONFFLICTIONS
			fi
			# libustream-wolfssl可能处于=y或=m状态
			if [[ `grep -c "CONFIG_PACKAGE_libustream-wolfssl=y" $HOME_PATH/.config` -ge '1' || `grep -c "CONFIG_PACKAGE_libustream-wolfssl=m" $HOME_PATH/.config` -ge '1' ]]; then
				sed -Ei 's/.*(CONFIG_PACKAGE_libustream-wolfssl).*/# \1 is not set/g' $HOME_PATH/.config
				echo "__error_msg \"您同时选择libustream-wolfssl和libustream-openssl，库有冲突，只能二选一，已删除libustream-wolfssl库\"" >> $CONFFLICTIONS
				echo "" >> $CONFFLICTIONS
			fi
			# luci-ssl(依赖于旧的libustream-mbedtls)，替换为luci-ssl-openssl(依赖于libustream-openssl)
			if [[ `grep -c "CONFIG_PACKAGE_luci-ssl=y" $HOME_PATH/.config` -ge '1' ]]; then
				sed -i 's/CONFIG_PACKAGE_luci-ssl=y/# CONFIG_PACKAGE_luci-ssl is not set/g' $HOME_PATH/.config
				sed -Ei 's/.*(CONFIG_PACKAGE_luci-ssl-openssl).*/\1=y/g' $HOME_PATH/.config
				echo "__error_msg \"您选择luci-ssl(依赖于旧的libustream-mbedtls)，与libustream-openssl库有冲突，替换为luci-ssl-openssl(依赖于libustream-openssl)\"" >> $CONFFLICTIONS
				echo "" >> $CONFFLICTIONS
			fi
			# cache-domains-mbedtls(依赖于旧的libustream-mbedtls)，cache-domains-wolfssl（依赖于libustream-wolfssl）
			# 替换为cache-domains-openssl（依赖于libustream-openssl）
			if [[ `grep -c "CONFIG_PACKAGE_cache-domains-mbedtls=y" $HOME_PATH/.config` -ge '1' || `grep -c "CONFIG_PACKAGE_cache-domains-wolfssl=y" $HOME_PATH/.config` -ge '1' ]]; then
				sed -i '/CONFIG_PACKAGE_cache-domains-mbedtls/d' $HOME_PATH/.config
				sed -i '/CONFIG_PACKAGE_cache-domains-wolfssl/d' $HOME_PATH/.config
				sed -Ei 's/.*(CONFIG_PACKAGE_cache-domains-openssl).*/\1=y/g' $HOME_PATH/.config
				echo "__error_msg \"您选择cache-domains-mbedtls或cache-domains-wolfssl，与cache-domains-openssl库有冲突，替换为cache-domains-openssl\"" >> $CONFFLICTIONS
				echo "" >> $CONFFLICTIONS
			fi
		fi
	fi
	
	if [[ `grep -c "CONFIG_TARGET_x86=y" $HOME_PATH/.config` -eq '1' || `grep -c "CONFIG_TARGET_rockchip=y" $HOME_PATH/.config` -eq '1' || `grep -c "CONFIG_TARGET_bcm27xx=y" $HOME_PATH/.config` -eq '1' ]]; then
		#sed -Ei 's/.*(CONFIG_TARGET_IMAGES_GZIP).*/\1=y/g' $HOME_PATH/.config
		#sed -Ei 's/.*(CONFIG_PACKAGE_snmpd).*/\1=y/g' $HOME_PATH/.config
		sed -Ei 's/.*(CONFIG_PACKAGE_openssh-sftp-server).*/\1=y/g' $HOME_PATH/.config
		if [[ `grep -c "CONFIG_TARGET_ROOTFS_PARTSIZE=" $HOME_PATH/.config` -eq '1' ]]; then
			local partsize="$(grep -Eo "CONFIG_TARGET_ROOTFS_PARTSIZE=[0-9]+" $HOME_PATH/.config |cut -f2 -d=)"
			if [[ "$partsize" -lt "400" ]];then
				sed -i '/CONFIG_TARGET_ROOTFS_PARTSIZE/d' $HOME_PATH/.config
				sed -i '$a CONFIG_TARGET_ROOTFS_PARTSIZE=400' $HOME_PATH/.config
			fi
		fi
	fi
	
	if [[ `grep -c "CONFIG_TARGET_mxs=y" $HOME_PATH/.config` -eq '1' || `grep -c "CONFIG_TARGET_sunxi=y" $HOME_PATH/.config` -eq '1' || `grep -c "CONFIG_TARGET_zynq=y" $HOME_PATH/.config` -eq '1' ]]; then	
		#sed -Ei 's/.*(CONFIG_TARGET_IMAGES_GZIP).*/\1=y/g' $HOME_PATH/.config
		sed -Ei 's/.*(CONFIG_PACKAGE_openssh-sftp-server).*/\1=y/g' $HOME_PATH/.config
		if [[ `grep -c "CONFIG_TARGET_ROOTFS_PARTSIZE=" $HOME_PATH/.config` -eq '1' ]]; then
			local partsize="$(grep -Eo "CONFIG_TARGET_ROOTFS_PARTSIZE=[0-9]+" $HOME_PATH/.config |cut -f2 -d=)"
			if [[ "$partsize" -lt "400" ]];then
				sed -i '/CONFIG_TARGET_ROOTFS_PARTSIZE/d' $HOME_PATH/.config
				sed -i '$a CONFIG_TARGET_ROOTFS_PARTSIZE=400' $HOME_PATH/.config
			fi
		fi
	fi
	
	if [[ `grep -c "CONFIG_TARGET_armvirt=y" $HOME_PATH/.config` -eq '1' || `grep -c "CONFIG_TARGET_armsr=y" $HOME_PATH/.config` -eq '1' ]]; then
		sed -Ei 's/.*(CONFIG_PACKAGE_luci-app-autoupdate).*/# \1 is not set/g' $HOME_PATH/.config
		sed -Ei 's/.*(CONFIG_TARGET_ROOTFS_TARGZ).*/\1=y/g' $HOME_PATH/.config
	fi
	
	if [[ `grep -c "CONFIG_PACKAGE_luci-app-adblock=y" $HOME_PATH/.config` -eq '1' ]]; then
		if [[ `grep -c "CONFIG_PACKAGE_luci-app-adblock-plus=y" $HOME_PATH/.config` -eq '1' ]]; then
			sed -i 's/CONFIG_PACKAGE_luci-app-adblock=y/# CONFIG_PACKAGE_luci-app-adblock is not set/g' $HOME_PATH/.config
			sed -i 's/CONFIG_PACKAGE_adblock=y/# CONFIG_PACKAGE_adblock is not set/g' $HOME_PATH/.config
			sed -i '/luci-i18n-adblock/d' $HOME_PATH/.config
			echo "__error_msg \"您同时选择luci-app-adblock-plus和luci-app-adblock，插件有依赖冲突，只能二选一，已删除luci-app-adblock\"" >> $CONFFLICTIONS
			echo "" >> $CONFFLICTIONS
		fi
	fi
	
	if [[ `grep -c "CONFIG_PACKAGE_luci-app-dockerman=y" $HOME_PATH/.config` -eq '1' ]]; then
 		# 修复官方源码dockerman未选中文语言包
		sed -Ei 's/.*(CONFIG_PACKAGE_luci-i18n-dockerman-zh-cn).*/\1=y/g' $HOME_PATH/.config
  		# 修复官方源码dockerman无法启动(没有关联选中dockerd)
		sed -Ei 's/.*(CONFIG_PACKAGE_dockerd).*/\1=y/g' $HOME_PATH/.config
  		# 解决Lede源码插件双选冲突(取消luci-app-docker选中状态)
		if [[ `grep -c "CONFIG_PACKAGE_luci-app-docker=y" $HOME_PATH/.config` -eq '1' ]]; then
			sed -i 's/CONFIG_PACKAGE_luci-app-docker=y/# CONFIG_PACKAGE_luci-app-docker is not set/g' $HOME_PATH/.config
			sed -i 's/CONFIG_PACKAGE_luci-i18n-docker-zh-cn=y/# CONFIG_PACKAGE_luci-i18n-docker-zh-cn is not set/g' $HOME_PATH/.config
			echo "__error_msg \"您同时选择luci-app-docker和luci-app-dockerman，插件有冲突，相同功能插件只能二选一，已删除luci-app-docker\"" >> $CONFFLICTIONS
			echo "" >> $CONFFLICTIONS
		fi
	fi
	
	if [[ `grep -c "CONFIG_PACKAGE_luci-app-dockerman=y" $HOME_PATH/.config` -eq '0' ]]; then
		if [[ `grep -c "CONFIG_PACKAGE_luci-app-docker=y" $HOME_PATH/.config` -eq '0' ]]; then
			sed -i 's/CONFIG_PACKAGE_luci-lib-docker=y/# CONFIG_PACKAGE_luci-lib-docker is not set/g' $HOME_PATH/.config
			sed -i 's/CONFIG_PACKAGE_luci-i18n-dockerman-zh-cn=y/# CONFIG_PACKAGE_luci-i18n-dockerman-zh-cn is not set/g' $HOME_PATH/.config
			sed -i 's/CONFIG_PACKAGE_docker=y/# CONFIG_PACKAGE_docker is not set/g' $HOME_PATH/.config
			sed -i 's/CONFIG_PACKAGE_dockerd=y/# CONFIG_PACKAGE_dockerd is not set/g' $HOME_PATH/.config
		fi
	fi
	
	if [[ `grep -c "CONFIG_PACKAGE_luci-app-ipsec-server=y" $HOME_PATH/.config` -eq '1' ]]; then
		if [[ `grep -c "CONFIG_PACKAGE_luci-app-ipsec-vpnd=y" $HOME_PATH/.config` -eq '1' ]]; then
			sed -i 's/CONFIG_PACKAGE_luci-app-ipsec-vpnd=y/# CONFIG_PACKAGE_luci-app-ipsec-vpnd is not set/g' $HOME_PATH/.config
			echo "__error_msg \"您同时选择luci-app-ipsec-vpnd和luci-app-ipsec-server，插件有冲突，相同功能插件只能二选一，已删除luci-app-ipsec-vpnd\""  >> $CONFFLICTIONS
			echo "" >> $CONFFLICTIONS
		fi
	fi
	
	if [[ `grep -c "CONFIG_PACKAGE_luci-app-qbittorrent=y" $HOME_PATH/.config` -eq '1' ]]; then
		if [[ `grep -c "CONFIG_PACKAGE_luci-app-qbittorrent-simple=y" $HOME_PATH/.config` -eq '1' ]]; then
			sed -i 's/CONFIG_PACKAGE_luci-app-qbittorrent-simple=y/# CONFIG_PACKAGE_luci-app-qbittorrent-simple is not set/g' $HOME_PATH/.config
			sed -i 's/CONFIG_PACKAGE_luci-i18n-qbittorrent-simple-zh-cn=y/# CONFIG_PACKAGE_luci-i18n-qbittorrent-simple-zh-cn is not set/g' $HOME_PATH/.config
			sed -i 's/CONFIG_PACKAGE_qbittorrent=y/# CONFIG_PACKAGE_qbittorrent is not set/g' $HOME_PATH/.config
			echo "__error_msg \"您同时选择luci-app-qbittorrent和luci-app-qbittorrent-simple，插件有冲突，相同功能插件只能二选一，已删除luci-app-qbittorrent-simple\"" >> $CONFFLICTIONS
			echo "" >> $CONFFLICTIONS
		fi
	fi
	
	if [[ `grep -c "CONFIG_PACKAGE_luci-app-samba4=y" $HOME_PATH/.config` -eq '1' ]]; then
		if [[ `grep -c "CONFIG_PACKAGE_luci-app-samba=y" $HOME_PATH/.config` -eq '1' ]]; then
			sed -i 's/CONFIG_PACKAGE_luci-app-samba=y/# CONFIG_PACKAGE_luci-app-samba is not set/g' $HOME_PATH/.config
			sed -i 's/CONFIG_PACKAGE_luci-i18n-samba-zh-cn=y/# CONFIG_PACKAGE_luci-i18n-samba-zh-cn is not set/g' $HOME_PATH/.config
			sed -i 's/CONFIG_PACKAGE_samba36-server=y/# CONFIG_PACKAGE_samba36-server is not set/g' $HOME_PATH/.config
			echo "__error_msg \"您同时选择luci-app-samba和luci-app-samba4，插件有冲突，相同功能插件只能二选一，已删除luci-app-samba\"" >> $CONFFLICTIONS
			echo "" >> $CONFFLICTIONS
		fi
	fi
	
	if [[ `grep -c "CONFIG_PACKAGE_luci-app-cshark=y" $HOME_PATH/.config` -eq '1' ]]; then
		if [[ `grep -c "CONFIG_PACKAGE_luci-app-ssr-plus=y" $HOME_PATH/.config` -eq '1' ]]; then
			sed -i 's/CONFIG_PACKAGE_luci-app-cshark=y/# CONFIG_PACKAGE_luci-app-cshark is not set/g' $HOME_PATH/.config
			sed -i 's/CONFIG_PACKAGE_cshark=y/# CONFIG_PACKAGE_cshark is not set/g' $HOME_PATH/.config
			sed -i 's/CONFIG_PACKAGE_libustream-mbedtls=y/# CONFIG_PACKAGE_libustream-mbedtls is not set/g' $HOME_PATH/.config
			echo "__error_msg \"您同时选择luci-app-ssr-plus和luci-app-cshark，插件有依赖冲突，只能二选一，已删除luci-app-cshark\"" >> $CONFFLICTIONS
			echo "" >> $CONFFLICTIONS
		fi
	fi
	
	if [[ `grep -c "CONFIG_PACKAGE_luci-app-turboacc_INCLUDE_SHORTCUT_FE=y" $HOME_PATH/.config` -eq '1' ]]; then
		if [[ `grep -c "CONFIG_PACKAGE_luci-app-turboacc_INCLUDE_SHORTCUT_FE_CM=y" $HOME_PATH/.config` -eq '1' ]]; then
			sed -i 's/CONFIG_PACKAGE_luci-app-turboacc_INCLUDE_SHORTCUT_FE=y/# CONFIG_PACKAGE_luci-app-turboacc_INCLUDE_SHORTCUT_FE is not set/g' $HOME_PATH/.config
			sed -i 's/CONFIG_PACKAGE_kmod-fast-classifier=y/# CONFIG_PACKAGE_kmod-fast-classifier is not set/g' $HOME_PATH/.config
			echo "__error_msg \"luci-app-turboacc同时选择Include Shortcut-FE CM和Include Shortcut-FE，有冲突，只能二选一，已删除Include Shortcut-FE\"" >> $CONFFLICTIONS
			echo "" >> $CONFFLICTIONS
		fi
	fi
	
	if [[ `grep -c "CONFIG_PACKAGE_luci-app-unblockneteasemusic=y" $HOME_PATH/.config` -eq '1' ]]; then
		if [[ `grep -c "CONFIG_PACKAGE_luci-app-unblockmusic=y" $HOME_PATH/.config` -eq '1' ]]; then
			sed -i 's/CONFIG_PACKAGE_luci-app-unblockmusic=y/# CONFIG_PACKAGE_luci-app-unblockmusic is not set/g' $HOME_PATH/.config
			echo "__error_msg \"您选择了luci-app-unblockmusic，会和luci-app-unblockneteasemusic冲突导致编译错误，已删除luci-app-unblockmusic\"" >> $CONFFLICTIONS
			echo "" >> $CONFFLICTIONS
		fi
		if [[ `grep -c "CONFIG_PACKAGE_luci-app-unblockneteasemusic-go=y" $HOME_PATH/.config` -eq '1' ]]; then
			sed -i 's/CONFIG_PACKAGE_luci-app-unblockneteasemusic-go=y/# CONFIG_PACKAGE_luci-app-unblockneteasemusic-go is not set/g' $HOME_PATH/.config
			echo "__error_msg \"您选择了luci-app-unblockneteasemusic-go，会和luci-app-unblockneteasemusic冲突导致编译错误，已删除luci-app-unblockneteasemusic-go\"" >> $CONFFLICTIONS
			echo "" >> $CONFFLICTIONS
		fi
	fi
	
	if [[ `grep -c "CONFIG_PACKAGE_luci-theme-argon=y" $HOME_PATH/.config` -eq '1' ]]; then
		if [[ `grep -c "CONFIG_PACKAGE_luci-theme-argon_new=y" $HOME_PATH/.config` -eq '1' ]]; then
			sed -i 's/CONFIG_PACKAGE_luci-theme-argon_new=y/# CONFIG_PACKAGE_luci-theme-argon_new is not set/g' $HOME_PATH/.config
			echo "__error_msg \"您同时选择luci-theme-argon和luci-theme-argon_new，插件有冲突，相同功能插件只能二选一，已删除luci-theme-argon_new\"" >> $CONFFLICTIONS
			echo "" >> $CONFFLICTIONS
		fi
		if [[ `grep -c "CONFIG_PACKAGE_luci-theme-argonne=y" $HOME_PATH/.config` -eq '1' ]]; then
			sed -i 's/CONFIG_PACKAGE_luci-theme-argonne=y/# CONFIG_PACKAGE_luci-theme-argonne is not set/g' $HOME_PATH/.config
			echo "__error_msg \"您同时选择luci-theme-argon和luci-theme-argonne，插件有冲突，相同功能插件只能二选一，已删除luci-theme-argonne\"" >> $CONFFLICTIONS
			echo "" >> $CONFFLICTIONS
		fi
		if [[ `grep -c "CONFIG_PACKAGE_luci-app-argon-config=y" $HOME_PATH/.config` -eq '0' ]]; then
			sed -Ei 's/.*(CONFIG_PACKAGE_luci-app-argon-config).*/\1=y/g' $HOME_PATH/.config
		fi
	else
		sed -Ei 's/.*(CONFIG_PACKAGE_luci-app-argon-config).*/# \1 is not set/g' $HOME_PATH/.config
	fi
	
	if [[ `grep -c "CONFIG_PACKAGE_luci-app-zerotier=y" $HOME_PATH/.config` -eq '0' ]]; then
		sed -Ei 's/.*(CONFIG_PACKAGE_zerotier).*/# \1 is not set/g' $HOME_PATH/.config
	fi
	
	if [[ `grep -c "CONFIG_PACKAGE_dnsmasq=y" $HOME_PATH/.config` -eq '1' || `grep -c "CONFIG_PACKAGE_dnsmasq-dhcpv6=y" $HOME_PATH/.config` -eq '1' ]]; then
		if [[ `grep -c "CONFIG_PACKAGE_dnsmasq-full=y" $HOME_PATH/.config` -eq '1' ]]; then
			sed -i 's/CONFIG_PACKAGE_dnsmasq=y/# CONFIG_PACKAGE_dnsmasq is not set/g' $HOME_PATH/.config
			sed -i 's/CONFIG_PACKAGE_dnsmasq-dhcpv6=y/# CONFIG_PACKAGE_dnsmasq-dhcpv6 is not set/g' $HOME_PATH/.config
		fi
	fi
	
	if [[ -s $CONFFLICTIONS ]]; then
		chmod +x $CONFFLICTIONS && source $CONFFLICTIONS
	fi
	
	echo
	echo "--------------common_modify_config end--------------"
}

################################################################################################################
# 编译机型CPU机型架构、内核版本、固件名称、固件自动更新相关信息等（依赖于make defconfig，须在生成.config之后）
################################################################################################################
function firmware_settings() {
	echo "--------------firmware_settings start--------------"
	echo
	
	cd $HOME_PATH
	
	# x86、ramips...
	TARGET_BOARD="$(awk -F '[="]+' '/CONFIG_TARGET_BOARD/{print $2}' $HOME_PATH/.config)"
	# 64、generic、legacy、mt7621...
	TARGET_SUBTARGET="$(awk -F '[="]+' '/CONFIG_TARGET_SUBTARGET/{print $2}' $HOME_PATH/.config)"
	# x86_64、i386_pentium4、i386_pentium-mmx、mipsel_24kc...
	ARCHITECTURE="$(awk -F '[="]+' '/CONFIG_TARGET_ARCH_PACKAGES/{print $2}' $HOME_PATH/.config)"
	
	# 机型架构
	__yellow_color "开始获取固件机型架构信息..."
	if [ `grep -c "CONFIG_TARGET_x86_64=y" .config` -eq '1' ]; then
		TARGET_PROFILE="x86-64"
	elif [[ `grep -c "CONFIG_TARGET_x86=y" .config` == '1' &&  `grep -c "CONFIG_TARGET_x86_64=y" .config` == '0' ]]; then
		TARGET_PROFILE="x86-32"
	elif [[ -n "$(grep -Eo 'CONFIG_TARGET.*armsr.*armv8.*=y' $HOME_PATH/.config)" ]]; then
		TARGET_PROFILE="Armvirt_64"
	elif [[ -n "$(grep -Eo 'CONFIG_TARGET.*armvirt.*64.*=y' $HOME_PATH/.config)" ]]; then
		TARGET_PROFILE="Armvirt_64"
	elif [[ -n "$(grep -Eo 'CONFIG_TARGET.*DEVICE.*=y' $HOME_PATH/.config)" ]]; then
		TARGET_PROFILE="$(grep -Eo "CONFIG_TARGET.*DEVICE.*=y" $HOME_PATH/.config | sed -r 's/.*DEVICE_(.*)=y/\1/')"
	else
		TARGET_PROFILE="$(awk -F '[="]+' '/TARGET_PROFILE/{print $2}' $HOME_PATH/.config | sed 's/DEVICE_//')"
	fi
	TARGET_DEVICE="$TARGET_PROFILE"
	# 修改TARGET_PROFILE
	if [[ $TARGET_PROFILE =~ (phicomm_k3|phicomm-k3) ]]; then		
		TARGET_PROFILE="phicomm-k3"
	elif [[ $TARGET_PROFILE =~ (k2p|phicomm_k2p|phicomm-k2p) ]]; then
		TARGET_PROFILE="phicomm-k2p"
	elif [[ $TARGET_PROFILE =~ (xiaomi_mi-router-3g-v2|xiaomi_mir3g_v2) ]]; then
		TARGET_PROFILE="xiaomi_mir3g-v2"
	elif [[ $TARGET_PROFILE == "xiaomi_mi-router-3g" ]]; then
		TARGET_PROFILE="xiaomi_mir3g"
	elif [[ $TARGET_PROFILE == "xiaomi_mi-router-3-pro" ]]; then
		TARGET_PROFILE="xiaomi_mir3p"
	fi

	__info_msg "CPU架构：$ARCHITECTURE"
	
	# 内核版本
	__yellow_color "开始获取内核版本信息、替换内核等..."
	KERNEL_PATCHVER="$(grep "KERNEL_PATCHVER" "$HOME_PATH/target/linux/$TARGET_BOARD/Makefile" |grep -Eo "[0-9]+\.[0-9]+")"
	
	# 内核替换
	if [[ -n "$NEW_KERNEL_PATCHVER" ]]; then
		if [[ "$NEW_KERNEL_PATCHVER" == "0" ]]; then
			__info_msg "编译固件内核：[ $KERNEL_PATCHVER ]"
		elif [[ `ls -1 "$HOME_PATH/target/linux/$TARGET_BOARD" |grep -c "kernel-$NEW_KERNEL_PATCHVER"` -eq '1' ]]; then
			sed -i "s/${KERNEL_PATCHVER}/${NEW_KERNEL_PATCHVER}/g" $HOME_PATH/target/linux/$TARGET_BOARD/Makefile
			KERNEL_PATCHVER=$NEW_KERNEL_PATCHVER
			__success_msg "内核[ $NEW_KERNEL_PATCHVER ]更换完成"
		else
			__error_msg "没发现与$TARGET_PROFILE机型对应[ $NEW_KERNEL_PATCHVER ]内核，使用默认内核[ $KERNEL_PATCHVER ]编译"
		fi
	else
		__info_msg "编译固件内核：[ $KERNEL_PATCHVER ]"
	fi
	
	local kernel_version_file="kernel-$KERNEL_PATCHVER"
	if [[ -f "$HOME_PATH/include/$kernel_version_file" ]]; then
		LINUX_KERNEL=$(egrep -o "$KERNEL_PATCHVER\.[0-9]+" $HOME_PATH/include/$kernel_version_file)
		[[ -z $LINUX_KERNEL ]] && LINUX_KERNEL="unknown"
	else
		LINUX_KERNEL=$(egrep -o "$KERNEL_PATCHVER\.[0-9]+" $HOME_PATH/include/kernel-version.mk)
		[[ -z $LINUX_KERNEL ]] && LINUX_KERNEL="unknown"
	fi
	
	echo "::notice title=内核版本::$LINUX_KERNEL"
	echo "::notice title=固件机型::$TARGET_PROFILE"
	
	# BIOS引导模式
	if [[ $BIOS_MODE =~ (uefi|UEFI|Uefi) ]]; then
		sed -i '/CONFIG_GRUB_IMAGES/d' $HOME_PATH/.config > /dev/null 2>&1
		sed -i '$a # CONFIG_GRUB_IMAGES is not set' $HOME_PATH/.config > /dev/null 2>&1
		sed -i '/CONFIG_GRUB_EFI_IMAGES/d' $HOME_PATH/.config > /dev/null 2>&1
		sed -i '$a CONFIG_GRUB_EFI_IMAGES=y' $HOME_PATH/.config > /dev/null 2>&1
		__info_msg "编译uefi固件"
	elif [[ $BIOS_MODE =~ (legacy|LEGACY|Legacy) ]]; then
		sed -i '/CONFIG_GRUB_IMAGES/d' $HOME_PATH/.config > /dev/null 2>&1
		sed -i '$a CONFIG_GRUB_IMAGES=y' $HOME_PATH/.config > /dev/null 2>&1
		sed -i '/CONFIG_GRUB_EFI_IMAGES/d' $HOME_PATH/.config > /dev/null 2>&1
		sed -i '$a # CONFIG_GRUB_EFI_IMAGES is not set' $HOME_PATH/.config > /dev/null 2>&1
		__info_msg "编译legacy固件"
	elif [[ $BIOS_MODE =~ (both|BOTH|Both|all|ALL|All) ]]; then
		sed -i '/CONFIG_GRUB_IMAGES/d' $HOME_PATH/.config > /dev/null 2>&1
		sed -i '$a CONFIG_GRUB_IMAGES=y' $HOME_PATH/.config > /dev/null 2>&1
		sed -i '/CONFIG_GRUB_EFI_IMAGES/d' $HOME_PATH/.config > /dev/null 2>&1
		sed -i '$a CONFIG_GRUB_EFI_IMAGES=y' $HOME_PATH/.config > /dev/null 2>&1
		__info_msg "编译uefi及legacy固件"
	else
		__info_msg "编译uefi、legacy固件由.config文件决定"
	fi

	# 固件相关
	__yellow_color "开始设置固件名称、后缀等相关信息..."
	# 固件路径
	FIRMWARE_PATH=$HOME_PATH/bin/targets/$TARGET_BOARD/$TARGET_SUBTARGET
	__info_msg "固件保存路径：$FIRMWARE_PATH"
	# 固件版本 如：lede-x86-64-202310011001
	FIRMWARE_BRIEF="$SOURCE-$TARGET_PROFILE-$COMPILE_DATE_HM"
	# 固件名称前缀 如：lede-18.06-x86-64，方便自动更新固件搜寻可更新固件
	FIRMWARE_NAME_PREFIX="$SOURCE-$LUCI_EDITION-$TARGET_PROFILE"
	# 固件名称（简写，x86区分legacy、uefi）如：lede-18.06-x86-64-202310101010	
	FIRMWARE_NAME="$FIRMWARE_NAME_PREFIX-$COMPILE_DATE_HM"
	# 固件名称与后缀
	case "$TARGET_BOARD" in
	x86)
		ROOTFS_EXT=".tar.gz"
		FIRMWARE_EXT=".img.gz"		
		# 18.06-lede-x86-64-1695553941-legacy
		# FIRMWARE_NAME_LEGACY="$FIRMWARE_NAME-legacy"
		# 18.06-lede-x86-64-1695553941-uefi
		# FIRMWARE_NAME_UEFI="$FIRMWARE_NAME-uefi"
		# 18.06-lede-x86-64-1695647548-rootfs
		# FIRMWARE_NAME_ROOTFS="$FIRMWARE_NAME-rootfs"
		echo "ROOTFS_EXT=$ROOTFS_EXT" >> $GITHUB_ENV
	;;
	ramips | reltek | ath* | ipq* | bcm47xx | bmips | kirkwood | mediatek)
		FIRMWARE_EXT=".bin"
		FIRMWARE_NAME="$FIRMWARE_NAME-sysupgrade"
	;;
	rockchip | bcm27xx | mxs | sunxi | zynq)
		FIRMWARE_EXT=".img.gz"
	;;
	mvebu)
		case "$TARGET_SUBTARGET" in
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
	if [[ "$FIRMWARE_TYPE" == "lxc" ]]; then
		RELEASE_TAG="$SOURCE-$TARGET_PROFILE-lxc"
		AUTOUPDATE_TAG="AutoUpdate-$TARGET_BOARD-lxc"
	else
		RELEASE_TAG="$SOURCE-$TARGET_PROFILE"
		AUTOUPDATE_TAG="AutoUpdate-$TARGET_BOARD"
	fi
	# release地址
	GITHUB_RELEASE_URL="$GITHUB_REPOSITORY_URL/releases/tag/$AUTOUPDATE_TAG"
	GITHUB_RELEASE_DOWNLOAD_URL="$GITHUB_REPOSITORY_URL/releases/download/$AUTOUPDATE_TAG"

	echo "TARGET_BOARD=$TARGET_BOARD" >> $GITHUB_ENV
	echo "TARGET_SUBTARGET=$TARGET_SUBTARGET" >> $GITHUB_ENV
	echo "TARGET_PROFILE=$TARGET_PROFILE" >> $GITHUB_ENV
	echo "TARGET_DEVICE=$TARGET_DEVICE" >> $GITHUB_ENV
	echo "ARCHITECTURE=$ARCHITECTURE" >> $GITHUB_ENV	
	echo "FIRMWARE_NAME=$FIRMWARE_NAME" >> $GITHUB_ENV
	echo "FIRMWARE_NAME_PREFIX=$FIRMWARE_NAME_PREFIX" >> $GITHUB_ENV
	echo "FIRMWARE_BRIEF=$FIRMWARE_BRIEF" >> $GITHUB_ENV
	echo "FIRMWARE_EXT=$FIRMWARE_EXT" >> $GITHUB_ENV
	echo "FIRMWARE_PATH=$FIRMWARE_PATH" >> $GITHUB_ENV
	echo "KERNEL_PATCHVER=$KERNEL_PATCHVER" >> $GITHUB_ENV
	echo "LINUX_KERNEL=$LINUX_KERNEL" >> $GITHUB_ENV
	echo "RELEASE_TAG=$RELEASE_TAG" >> $GITHUB_ENV
	echo "AUTOUPDATE_TAG=$AUTOUPDATE_TAG" >> $GITHUB_ENV
	echo "GITHUB_RELEASE_URL=$GITHUB_RELEASE_URL" >> $GITHUB_ENV
	
	__yellow_color "开始设置自动更新固件相关信息..."
	# 固件自动更新相关信息等(用于luci-app-autoupdate插件)
	local file_openwrt_autoupdate="$FILES_PATH/etc/openwrt_autoupdate"
	local github_api_origin="$GITHUB_REPOSITORY_URL/releases/download/$AUTOUPDATE_TAG/$GITHUB_API"
	local github_api_ghproxy="https://mirror.ghproxy.com/$GITHUB_REPOSITORY_URL/releases/download/$AUTOUPDATE_TAG/$GITHUB_API"
	local github_api_fastgit="https://download.fastgit.org/$GITHUB_REPOSITORY/releases/download/$AUTOUPDATE_TAG/$GITHUB_API"
	local release_download_origin="$GITHUB_REPOSITORY_URL/releases/download/$AUTOUPDATE_TAG"
	local release_download_ghproxy="https://mirror.ghproxy.com/$GITHUB_REPOSITORY_URL/releases/download/$AUTOUPDATE_TAG"
	cat > "$file_openwrt_autoupdate" <<-EOF
	GITHUB_REPOSITORY="$GITHUB_REPOSITORY"
	GITHUB_REPOSITORY_URL="https://github.com/$GITHUB_REPOSITORY"
	GITHUB_RELEASE_URL="$GITHUB_RELEASE_URL"
	GITHUB_RELEASE_DOWNLOAD_URL="$GITHUB_RELEASE_DOWNLOAD_URL"
	GITHUB_TAG="$AUTOUPDATE_TAG"
	GITHUB_API="$GITHUB_API"
	GITHUB_API_URL_ORIGIN="$github_api_origin"
	GITHUB_API_URL_FASTGIT="$github_api_fastgit"
	GITHUB_API_URL_GHPROXY="$github_api_ghproxy"
	FRIMWARE_URL_ORIGIN="$release_download_origin"
	FRIMWARE_URL_GHPROXY="$release_download_ghproxy"
	# lede
	SOURCE="$SOURCE"
	# x86-64
	TARGET_PROFILE="$TARGET_PROFILE"
	# x86
	TARGET_BOARD="$TARGET_BOARD"
	# 64
	TARGET_SUBTARGET="$TARGET_SUBTARGET"
	# 18.06
	LUCI_EDITION="$LUCI_EDITION"
	# 202310011221
	COMPILE_DATE="$COMPILE_DATE_HM"
	# .img.gz
	FIRMWARE_EXT="$FIRMWARE_EXT"
	# lede-x86-64-202310011001
	FIRMWARE_BRIEF="$FIRMWARE_BRIEF"
	# lede-18.06-x86-64
	FIRMWARE_NAME_PREFIX="$FIRMWARE_NAME_PREFIX"
	# lede-18.06-x86-64-202310011001
	CURRENT_FIRMWARE="$FIRMWARE_NAME"
	# luci-app-autoupdate version
	AUTOUPDATE_VERSION="$AUTOUPDATE_VERSION"
	FILES_TO_DELETE="/etc/$FILENAME_TO_DELETE"
	EOF

	sudo chmod 1777 $file_openwrt_autoupdate
	cat $file_openwrt_autoupdate
		
	echo
	echo "--------------firmware_settings end--------------"
}

################################################################################################################
# 生成.config文件
################################################################################################################
function make_defconfig() {
	cd $HOME_PATH
	echo "files under $HOME_PATH:"
	tree -L 2 --dirsfirst
	
	# 生成.config文件
	make defconfig > /dev/null
	# 生成diffconfig文件
	bash $HOME_PATH/scripts/diffconfig.sh > $DIFFCONFIG_TXT
}

################################################################################################################
# 编译信息
################################################################################################################
function compile_info() {	
	echo
	__red_color "固件信息"
	echo "--------------------------------------------------------------------------------"
	__blue_color "编译源码: $SOURCE"
	__blue_color "源码链接: $SOURCE_URL"
	__blue_color "源码分支: $SOURCE_BRANCH"
	__blue_color "源码作者: $SOURCE_OWNER"
	__blue_color "内核版本: $LINUX_KERNEL"
	__blue_color "LUCI版本: $LUCI_EDITION"
	__blue_color "机型信息: $TARGET_PROFILE"
	__blue_color "CPU 架构: $ARCHITECTURE"
	__blue_color "固件作者: $GITHUB_ACTOR"
	__blue_color "仓库地址: $GITHUB_REPOSITORY_URL"
	__blue_color "编译时间: $COMPILE_DATE_CN"
	__blue_color "友情提示：您当前使用【$MATRIX_TARGET】文件夹编译【$TARGET_PROFILE】固件"
	echo

	echo
	__red_color "固件类型"
	echo "--------------------------------------------------------------------------------"
	if [[ "$FIRMWARE_TYPE" == "lxc" ]]; then
		__blue_color "LXC固件：开启"
		echo
		echo
		__red_color "固件更新"
		echo "--------------------------------------------------------------------------------"
		__white_color "1、PVE运行："
		__green_color "wget https://mirror.ghproxy.com/https://raw.githubusercontent.com/stanlyshi/pve/main/openwrt.lxc.sh -O /usr/bin/openwrt && chmod +x /usr/bin/openwrt"
		__white_color "2、PVE运行："
		__green_color "openwrt"
		echo
	else
		__white_color "LXC固件：关闭"
		echo
		echo
		__red_color "固件更新"
		echo "--------------------------------------------------------------------------------"
		__blue_color "插件版本: $AUTOUPDATE_VERSION"
		
		if [[ "$TARGET_BOARD" == "x86" ]]; then
			__blue_color "传统固件: $FIRMWARE_NAME-legacy$FIRMWARE_EXT"
			__blue_color "UEFI固件: $FIRMWARE_NAME-uefi$FIRMWARE_EXT"
			__blue_color "固件后缀: $FIRMWARE_EXT"
		else
			__blue_color "固件名称: $FIRMWARE_NAME-sysupgrade$FIRMWARE_EXT"
			__blue_color "固件后缀: $FIRMWARE_EXT"
		fi
		__blue_color "固件版本: $FIRMWARE_NAME"
		__blue_color "云端路径: $GITHUB_RELEASE_URL"
		__white_color "在线更新，请输入命令：autoupdate，详见命令行说明"
	fi
	
	echo
	__red_color "编译选项"
	echo "--------------------------------------------------------------------------------"
	if [[ "$UPLOAD_RELEASE" == "true" ]]; then
		__blue_color "发布firmware+ipk至Github Relese: 开启"
	else
		__white_color "发布firmware+ipk至Github Relese: 关闭"
	fi
	if [[ "$UPLOAD_FIRMWARE" == "true" ]]; then
		__blue_color "上传firmware+ipk至Github Artifacts: 开启"
	else
		__white_color "上传firmware+ipk至Github Artifacts: 关闭"
	fi
	if [[ "$UPLOAD_CONFIG" == "true" ]]; then
		__blue_color "上传.config配置文件至Github Artifacts: 开启"
	else
		__white_color "上传.config配置文件至Github Artifacts: 关闭"
	fi
	if [[ $NOTICE_TYPE =~ (TG|telegram|PUSH|pushplus|WX|WeChat) ]]; then
		__blue_color "Pushplus/Telegram通知: 开启"
	else
		__white_color "Pushplus/Telegram通知: 关闭"
	fi
	if [[ $ENABLE_CCACHE =~ (fast|Fast|FAST) ]]; then
		__blue_color "缓存加速：快速加速"
		__white_color "如编译出错，请尝试删除缓存，或切换为普通加速，或关闭缓存加速"
	elif [[ $ENABLE_CCACHE =~ (true|True|TRUE|normal|Normal|NORMAL) ]]; then
		__blue_color "缓存加速：普通加速"
		__white_color "如编译出错，请尝试删除缓存，或关闭缓存加速"
	else
		__white_color "缓存加速：关闭"
	fi
	echo
	
	echo
	__red_color "CPU信息"
	echo "--------------------------------------------------------------------------------"
	local cpu=$(grep "physical id" /proc/cpuinfo| sort| uniq| wc -l)
	local cores=$(grep "cores" /proc/cpuinfo|uniq|awk '{print $4}')
	local processor=$(grep -c "processor" /proc/cpuinfo)
	local name=$(cat /proc/cpuinfo | grep name | cut -d: -f2 | uniq | sed 's/^[[:space:]]\+//')
	echo "物理CPU:$cpu	核心/线程:$cores/$processor"
	echo -e "CPU型号:\033[34m$name\033[0m"
	echo
	echo -e "Github在线编译，常见CPU性能排行:
	AMD EPYC 7763 64-Core Processor
	Intel(R) Xeon(R) Platinum 8370C CPU @ 2.80GHz
	Intel(R) Xeon(R) Platinum 8272CL CPU @ 2.60GHz
	Intel(R) Xeon(R) Platinum 8171M CPU @ 2.60GHz
	Intel(R) Xeon(R) CPU E5-2673 v4 @ 2.30GHz
	Intel(R) Xeon(R) CPU E5-2673 v3 @ 2.40GHz"
	echo
	echo
	__red_color "内存信息"
	echo "--------------------------------------------------------------------------------"
	free -m
	echo
	echo
	__red_color "硬盘信息"
	echo "--------------------------------------------------------------------------------"
	echo " 系统空间       类型   总数   已用   可用   使用率"
	df -hT
	echo
	
	echo
	cd $HOME_PATH
	local plugins="$(grep -Eo "CONFIG_PACKAGE_luci-app-.*=y|CONFIG_PACKAGE_luci-theme-.*=y" $HOME_PATH/.config |grep -v 'INCLUDE\|_Proxy\|_static\|_dynamic' |sed 's/=y//' |sed 's/CONFIG_PACKAGE_//g')"
	
	echo "$plugins" > $HOME_PATH/plugins_info
	echo "#### 插件列表 :rocket:" >> $GITHUB_STEP_SUMMARY
	nl $HOME_PATH/plugins_info >> $GITHUB_STEP_SUMMARY
	
	local pluginsnr="$(nl $HOME_PATH/plugins_info |sed 's/$/\"/g' |sed 's/^/__blue_color \"/g')"
	echo "$pluginsnr" > $HOME_PATH/plugins_info
	if [ -s $HOME_PATH/plugins_info ]; then
		__red_color "插件列表"
		echo "--------------------------------------------------------------------------------"
		chmod -Rf +x $HOME_PATH/plugins_info
		source $HOME_PATH/plugins_info
		rm -rf $HOME_PATH/plugins_info
		echo
	fi
	
	if [[ -s $CONFFLICTIONS ]]; then
		__red_color "冲突信息"
		echo "--------------------------------------------------------------------------------"
		chmod +x $CONFFLICTIONS && source $CONFFLICTIONS
		rm -rf $CONFFLICTIONS
	fi
}

################################################################################################################
# 更新编译仓库
################################################################################################################
function update_repo() {
	local repo_path="$GITHUB_WORKSPACE/repo"
	local repo_matrix_target_path="$repo_path/build/$MATRIX_TARGET"
	local repo_config_file="$repo_matrix_target_path/config/$CONFIG_FILE"
	local repo_settings_ini="$repo_matrix_target_path/settings.ini"
	local repo_plugins="$repo_matrix_target_path/release/plugins"
	
	[[ -d "$repo_path" ]] && rm -rf $repo_path

	cd $GITHUB_WORKSPACE	
	git clone https://github.com/$GITHUB_REPOSITORY.git repo
	
	cd $repo_path

	# 更新settings.ini文件
	local settings_array=(SOURCE_BRANCH CONFIG_FILE FIRMWARE_TYPE BIOS_MODE UPLOAD_CONFIG UPLOAD_FIRMWARE UPLOAD_RELEASE ENABLE_CCACHE)
	for x in $settings_array[*]; do
		local settings_key="$(grep -E "$x=" $SETTINGS_INI |sed 's/^[ ]*//g' |grep -v '^#' | awk '{print $1}' | awk -F'=' '{print $1}')"
		local settings_val="$(grep -E "$x=" $SETTINGS_INI |sed 's/^[ ]*//g' |grep -v '^#' | awk '{print $1}' | awk -F'=' '{print $2}' | sed 's#"##g')"
		eval eval env_settings_val=\$$x
		if [[ -n "$settings_key" ]]; then
			sed -i "s#$x=\"${settings_val}\"#$x=\"${env_settings_val}\"#g" $SETTINGS_INI
		fi
	done
	if [[ "$(cat $SETTINGS_INI)" != "$(cat $repo_settings_ini)" ]]; then
		ENABLE_REPO_UPDATE="true"
		cp -rf $SETTINGS_INI $repo_settings_ini
	fi
	
	# 更新.config文件
	# $HOME_PATH/scripts/diffconfig.sh > $DIFFCONFIG_TXT
	if [[ "$(cat $DIFFCONFIG_TXT)" != "$(cat $repo_config_file)" ]]; then
		ENABLE_REPO_UPDATE="true"
		cp -rf $DIFFCONFIG_TXT $repo_config_file
	fi
	
	# 更新plugins插件列表
	local plugins="$(grep -Eo "CONFIG_PACKAGE_luci-app-.*=y|CONFIG_PACKAGE_luci-theme-.*=y" $HOME_PATH/.config |grep -v 'INCLUDE\|_Proxy\|_static\|_dynamic' |sed 's/=y//' |sed 's/CONFIG_PACKAGE_//g')"
	if [[ "$plugins" != "$(cat $repo_plugins)" ]]; then
		ENABLE_REPO_UPDATE="true"
		echo "$plugins" > $repo_plugins
	fi
	
	# 提交commit，更新repo
	cd $repo_path
	local branch_head="$(git rev-parse --abbrev-ref HEAD)"
	if [[ "$ENABLE_REPO_UPDATE" == "true" ]]; then
		git add .
		git commit -m "[$MATRIX_TARGET] Update plugins, $CONFIG_FILE and settings.ini, etc. "
		git push --force "https://$REPO_TOKEN@github.com/$GITHUB_REPOSITORY" HEAD:$branch_head
		__success_msg "Your branch origin/$branch_head is now up to the latest."
	else
		__info_msg "Your branch is already up to date with origin/$branch_head. Nothing to commit, working tree clean."
	fi
}

################################################################################################################
# 整理固件
################################################################################################################
function organize_firmware() {
	cd $FIRMWARE_PATH
	echo "files under $HOME_PATH:"
	ls -Agho /$MATRIX_TARGET/openwrt
	echo "files under $FIRMWARE_PATH:"
	ls -Agho $FIRMWARE_PATH

	# 清理无关文件
	__yellow_color "开始清理无关文件..."
	for X in $(cat $FILES_TO_CLEAR | sed '/^#/d'); do		
		sudo rm -rf *"$X"* > /dev/null 2>&1
		__info_msg "delete $X"
	done
	sudo rm -rf packages > /dev/null 2>&1
	sudo rm -rf $FILES_TO_CLEAR

	__yellow_color "开始准备固件自动更新相关固件..."
	[[ ! -d $AUTOUPDATE_PATH ]] && mkdir -p $AUTOUPDATE_PATH || rm -rf $AUTOUPDATE_PATH/*
	case "$TARGET_BOARD" in
	x86)
		if [[ "$FIRMWARE_TYPE" == "lxc" ]]; then
			local firmware_rootfs_img="$(ls -1 |grep -Eo ".*squashfs.*rootfs.*img.gz")"
			[[ -f $firmware_rootfs_img ]] && {
				local rootfs_img_md5="$(md5sum $firmware_rootfs_img |cut -c1-3)$(sha256sum $firmware_rootfs_img |cut -c1-3)"
				cp -rf $firmware_rootfs_img $AUTOUPDATE_PATH/$FIRMWARE_NAME-rootfs-$rootfs_img_md5$FIRMWARE_EXT
				__info_msg "copy $firmware_rootfs_img to $AUTOUPDATE_PATH/$FIRMWARE_NAME-rootfs-$rootfs_img_md5$FIRMWARE_EXT"
			}
			local firmware_rootfs_tar="$(ls -1 |grep -Eo ".*rootfs.*tar.gz")"
			[[ -f $firmware_rootfs_tar ]] && {
				local rootfs_tar_md5="$(md5sum $firmware_rootfs_tar |cut -c1-3)$(sha256sum $firmware_rootfs_tar |cut -c1-3)"
				cp -rf $firmware_rootfs_tar $AUTOUPDATE_PATH/$FIRMWARE_NAME-rootfs-$rootfs_tar_md5$ROOTFS_EXT
				__info_msg "copy $firmware_rootfs_tar to $AUTOUPDATE_PATH/$FIRMWARE_NAME-rootfs-$rootfs_tar_md5$ROOTFS_EXT"
			}
		else
			if [[ `ls -1 | grep -c "efi"` -ge '1' ]]; then
				local firmware_uefi="$(ls -1 |grep -Eo ".*squashfs.*efi.*img.gz")"
				[[ -f $firmware_uefi ]] && {
					local uefimd5="$(md5sum $firmware_uefi |cut -c1-3)$(sha256sum $firmware_uefi |cut -c1-3)"
					cp -rf "$firmware_uefi" "$AUTOUPDATE_PATH/$FIRMWARE_NAME-uefi-$uefimd5$FIRMWARE_EXT"
					__info_msg "copy $firmware_uefi to $AUTOUPDATE_PATH/$FIRMWARE_NAME-uefi-$uefimd5$FIRMWARE_EXT"
				}
			fi
			if [[ `ls -1 | grep -c "squashfs"` -ge '1' ]]; then
				local firmware_legacy="$(ls -1 |grep -Eo ".*squashfs.*img.gz" |grep -v ".vm\|.vb\|.vh\|.qco\|efi\|root")"
				[[ -f $firmware_legacy ]] && {
					local legacymd5="$(md5sum $firmware_legacy |cut -c1-3)$(sha256sum $firmware_legacy |cut -c1-3)"
					cp -rf "$firmware_legacy" "$AUTOUPDATE_PATH/$FIRMWARE_NAME-legacy-$legacymd5$FIRMWARE_EXT"
					__info_msg "copy $firmware_legacy to $AUTOUPDATE_PATH/$FIRMWARE_NAME-legacy-$legacymd5$FIRMWARE_EXT"
				}
			fi
		fi
	;;
	*)
		if [[ `ls -1 | grep -c "sysupgrade"` -ge '1' ]]; then
			local firmware_sysupgrade="$(ls -1 |grep -Eo ".*$TARGET_PROFILE.*sysupgrade.*$FIRMWARE_EXT" |grep -v "rootfs\|ext4\|factory")"
		else
			local firmware_sysupgrade="$(ls -1 |grep -Eo ".*$TARGET_PROFILE.*squashfs.*$FIRMWARE_EXT" |grep -v "rootfs\|ext4\|factory")"
		fi
		if [[ -f "$firmware_sysupgrade" ]]; then
			local sysupgrademd5="$(md5sum $firmware_sysupgrade | cut -c1-3)$(sha256sum $firmware_sysupgrade | cut -c1-3)"
			cp -rf "$firmware_sysupgrade" "$AUTOUPDATE_PATH/$FIRMWARE_NAME-sysupgrade-$sysupgrademd5$FIRMWARE_EXT"
			__info_msg "copy $firmware_sysupgrade to $AUTOUPDATE_PATH/$FIRMWARE_NAME-sysupgrade-$sysupgrademd5$FIRMWARE_EXT"
		else
			__error_msg "没有找到可用的sysupgrade格式$FIRMWARE_EXT固件！"
		fi
	;;
	esac

	__yellow_color "开始准备固件发布文件..."
	__info_msg "准备ipk压缩包"
	if [[ "$UPLOAD_FIRMWARE" == "true" || "$UPLOAD_RELEASE" == "true" ]]; then
		[[ ! -d $FIRMWARE_PATH/ipk ]] && mkdir -p $FIRMWARE_PATH/ipk || rm -rf $FIRMWARE_PATH/ipk/*
		cp -rf $(find $HOME_PATH/bin/packages/ -type f -name "*.ipk") $FIRMWARE_PATH/ipk/ && sync
		sudo tar -czf ipk.tar.gz ipk && sync && sudo rm -rf ipk
		
		echo "$COMPILE_DATE_CN" > $RELEASE_MD
	fi
	__info_msg "重命名固件名称"
	if [[ `ls -1 | grep -c "armvirt"` -eq '0' ]]; then
		rename -v "s/^openwrt/$COMPILE_DATE_MD-$SOURCE-$LUCI_EDITION-$LINUX_KERNEL/" *
	fi
	
	release_info	
}

################################################################################################################
# 准备发布固件页面信息显示
################################################################################################################
function release_info() {
	cd $MATRIX_TARGET_PATH
	__yellow_color "开始准备固件发布信息..."
	local diy_part_ipaddr=`awk '{print $3}' $MATRIX_TARGET_PATH/$DIY_PART_SH | awk -F= '$1 == "network.lan.ipaddr" {print $2}' | sed "s/'//g" 2>/dev/null`
	local release_ipaddr=${diy_part_ipaddr:-192.168.1.1}
	
	sed -i "s#release_device#${TARGET_PROFILE}#" $RELEASEINFO_MD > /dev/null 2>&1
	sed -i "s#default_ip#${release_ipaddr}#" $RELEASEINFO_MD > /dev/null 2>&1
	sed -i "s#default_password#-#" $RELEASEINFO_MD > /dev/null 2>&1
	sed -i "s#release_source#${SOURCE}-${LUCI_EDITION}#" $RELEASEINFO_MD > /dev/null 2>&1
	sed -i "s#release_kernel#${LINUX_KERNEL}#" $RELEASEINFO_MD > /dev/null 2>&1
	sed -i "s#\/repository\/#\/${GITHUB_REPOSITORY}\/#" $RELEASEINFO_MD > /dev/null 2>&1
	sed -i "s#\/branch\/#\/${GITHUB_REPOSITORY_REFNAME}\/#" $RELEASEINFO_MD > /dev/null 2>&1
	sed -i "s#\/matrixtarget\/#\/${MATRIX_TARGET}\/#" $RELEASEINFO_MD > /dev/null 2>&1
	
	if [[ "$FIRMWARE_TYPE" == "lxc" ]]; then
		cat >> $RELEASEINFO_MD <<-EOF
		注：「lxc容器专用」
		EOF
	fi

	cat $RELEASEINFO_MD
}

################################################################################################################
# 解锁固件分区：Bootloader、Bdata、factory、reserved0，ramips系列路由器专用(固件编译前)
################################################################################################################
function unlock_bootloader() {
	if [[ $TARGET_BOARD == "ramips" ]]; then		
		if [[ -f "target/linux/$TARGET_BOARD/dts/${TARGET_SUBTARGET}_${TARGET_DEVICE}.dts" ]]; then
			local dts_file="target/linux/$TARGET_BOARD/dts/${TARGET_SUBTARGET}_${TARGET_DEVICE}.dts"
		elif [[ -f "target/linux/$TARGET_BOARD/dts/${TARGET_SUBTARGET}_${TARGET_PROFILE}.dts" ]]; then
			local dts_file="target/linux/$TARGET_BOARD/dts/${TARGET_SUBTARGET}_${TARGET_PROFILE}.dts"	
		else
			return
		fi
		__info_msg "dts文件：$dts_file"
		sed -i "/read-only;/d" $dts_file
		if [[ `grep -c "read-only;" $dts_file` -eq '0' ]]; then
			__success_msg "固件分区已经解锁！"
			echo "UNLOCK=true" >> $GITHUB_ENV
		else
			__error_msg "固件分区解锁失败！"
		fi
	else
		__warning_msg "非ramips系列，暂不支持！"
	fi
}
