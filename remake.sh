#!/bin/env bash

# Copyright (c) Ruhollah 2016
# Copyright (c) mast3rz3ro 2024
# This fork are licensed under GNU GPL-2.0-only
# USING THIS FORK WILL ENFORCE YOU TO FOLLOW THE GNU GPL-2.0-only LICENSE.

			_deps()
						{
								local x
							for x in file unzip aapt jq; do
								if ! command -v "$x" >/dev/null 2>&1; then
									echo "[!] Error missing utility: $x"
									exit 1
								fi
							done
						}
			_usage()
						{
							local m
							m="Usage: apksorter [parameters]\n"
							m+=" Finds and organizes Android apps.\n\n"
							m+="Parameters:\n"
							m+=" -i, Input (where to find APK).\n"
							m+=" -o, Output (where to store after renamed).\n"
							m+=" -a, Archive mode (store APK in more reliable way).\n"
							m+=" -c, Clean empty dirs (only used with archive mode).\n"
							m+=" -g, Category name (store apps to category).\n"
							m+=" -d, Don't rename If app category is not defined.\n\n"
							m+="Examples:\n"
							m+=" Rename apps inside: /sdcard/Download\n"
							m+=" apksorter -i /sdcard/Download\n\n"
							m+=" Rename apps inside: /sdcard/Download and move renamed into: /sdcard/Backup/Apps/\n"
							m+=" apksorter -i /sdcard/Download -o /sdcard/Backup/Apps\n"
							_echo "$m" 3; exit 1
						}
			_echo()
						{
							if [ "$verbose" = "yes" ] && [ "$2" != "3" ]; then
								echo -ne "- [v]: $1"
							fi

							if [ "$2" = "0" ]; then
								echo -ne "\t\t${0}: ${1}" >>"$tmp/opertion.log"
							elif [ "$2" = "1" ]; then
								echo -ne "${0}: ${1}" >>"$tmp/opertion.log"
							elif [ "$2" = "2" ]; then
								echo -ne "\t${0}: ${1}" >>"$tmp/opertion.log"
							elif [ "$2" = "3" ]; then
								echo -ne "$1"
							else
								echo -ne "\t\t${0}: warnning unknown value is used: '${2}' for message: '${1}'" >>"$tmp/opertion.log"
							fi
						}
			_mkdir()
						{
								local d
							for d in $@; do
								if [ ! -d "$d" ]; then
									_echo "- Creating directory: '$d'\n" 0
									mkdir -p "$d"
								fi
								if [ ! -w "$d" ]; then
									_echo "- Error can not write into: '$d'.\n" 0
									exit 1
								fi
							done
						}
			_stats()
						{
									index[6]=$((mv_err[1]+mv_err[2]+mv_err[3]))
									index[5]=$((index[0]-index[1])); index[5]=$((index[5] < 0 ? 0 : index[5]))
								_echo "- Total proccedd APK: ${index[1]}\n" 3
								_echo "- Total skipped none APK: ${index[5]}\n" 3
								_echo "- Total proccedd single-split: ${index[2]}\n" 0
								_echo "- Total proccedd combined-apk: ${index[3]}\n" 0
								_echo "- Total failed to detect APK: ${index[4]}\n" 0
								_echo "- Total rename success: ${mv_err[0]}\n" 3
								_echo "- Total rename fails: ${index[6]}\n" 0
								_echo "- Total rename exists: ${mv_err[2]}\n" 0
								_echo "- Total rename permission denied: ${mv_err[3]}\n" 0
								_echo "- Total rename unknown errors: ${mv_err[1]}\n" 0
						}
			_config()
						{
									local host library_dir
									mv_err=(0 0 0 0) # success, exists, permission, unknown
									index=(0 0 0 0 0 0 0) # files, apps, splits, combined, unknown, ignored
									_deps
								if [ -z "$1" ] || [ "$1" = "--help" ] || [ "$1" = "--h" ]; then
									_usage
								fi
							while getopts i:o:g:acd option; do
								case "${option}"
										in
									i) target_dir="${OPTARG}";;
									o) output_dir="${OPTARG}";;
									a) archive_mode="yes";;
									c) clean_mode="yes";;
									d) category_required="yes";;
									g) category_name="${OPTARG}";;
									?) _usage;;
								esac
							done

							if [[ "$PREFIX" = *"com.termux"* ]]; then
								host="termux-android"
								tmp="/sdcard/Android/media/tmp"
								library_dir="/sdcard/Android/media"
							else
								host="Linux/GNU"
								tmp=~/tmp
								library_dir=~/
							fi

								_mkdir "$tmp"
							if [ -z "$target_dir" ]; then
								_usage
							elif [ ! -w "$target_dir" ]; then
								_echo "Error cannot move from target dir: $target_dir\n" 0
								exit 1
							elif [ "$archive_mode" = "yes" ]; then
								output_dir="$library_dir/APK-Library"
							elif [ -z "$output_dir" ]; then
								output_dir="dynamic"
							elif [ -n "$output_dir" ]; then
								_mkdir "$output_dir"
							fi

								_echo "_config: operation date: $(date)\n${0}: _config: running on host: ${host}\n" 1
								_echo "_config: target directory: '${target_dir}'\n" 1
								_echo "_config: output directory: '${output_dir}'\n" 1
								_echo "- - - - - - - - - - - - - - - - - - - -\n" 3

								_find_apps "$target_dir"
							if [ "$archive_mode" = "yes" ] && [ "$clean_mode" = "yes" ]; then
								_echo "- Cleaning-up Library directory: '$output_dir' " 2
								find "$output_dir" -mindepth 1 -type d -empty -delete
							fi
						}
		_find_apps()
						{
								local x o
							while read -r x; do
									[ ! -f "$x" ] && [ ! -s "$x" ] && { index[0]=$((index[0]+1)); _echo "_find_apps: skipping none/empty file: '${f}'\n" 0; continue; }
								if [ "$output_dir" = "dynamic" ]; then
									o="${x%/*}"; [ "$x" = "$o" ] && o="."
									_process_apps "$x" "$o"
								else
									_process_apps "$x" "$output_dir"
								fi
							done< <(find "$1" -type f)
								#_stats
						}
	_process_apps()
							{

										_check_file()
															{
																	local f
																	_echo "_process_apps: checking file type: '${1}'\n" 1
																	f="$(file "${1}")"
																if [[ "$f" != *"Zip archive"* ]]; then
																	if [[ "$f" != *"Android package"* ]]; then
																		if [[ "$f" != *"Java archive"* ]]; then
																			_echo "_process_apps: skipping since it is not zip nor apk or even a jar: '${1}'\n" 0
																			return 1
																		fi
																	fi
																fi
																	_echo "_process_apps: processing possible apk: '${1}'\n" 2
																	return 0
															}
								_check_contents()
															{
																		local c
																	_echo "_process_apps: testing app file: $1\n" 2
																	c=$(unzip -qql "$1" 2>&1)
																if [  $? -ge 1 ]; then
																	_echo "_process_apps: skipping damaged zipfile: ${1}\n" 2
																	return 1
																elif [[ ! "$c" =~ (.apk|resources.arsc|AndroidManifest.xml) ]]; then
																	_echo "_process_apps: skipping none apk file: ${1}\n" 2
																	return 1
																fi

																if [[ "$c" =~ (resources.arsc|AndroidManifest.xml) ]]; then
																		manifest=$(aapt d badging "$1")
																	if [[ "$manifest" =~ (split=) ]]; then
																		mode="split"
																		index[2]=$((index[2]+1))
																	elif [[ "$manifest" =~ (name=) ]]; then
																		mode="normal"
																		index[1]=$((index[1]+1))
																	fi
																elif [[ "$c" =~ (.apk) ]]; then
																	mode="bundle"
																	echo "- error currently cannot proccess: $mode"
																	return 1
																	#func_extract_apk "$1"
																else
																	echo "- unexpected error cannot proccess: $1"
																	echo "- returned result: ${c}"
																	return 1
																fi
																	_echo "_process_apps: target type: $mode\n" 2
															}
								_parse_app_info()
															{
																local n
																	n[0]=$(echo "$2" | grep -Po "(?<=package: name=')(.+?)(?=')")
																		[ -n "$category_name" ] && \
																			_category_add_value "${n[0]}" "$category_name" && \
																			_echo "_process_apps: saved package name: ${n[0]} into: $tmp/ids.log\n" 0 && \
																			return 1
																		[ "$archive_mode" = "yes" ] && \
																			_category_check_value "${n[0]}"
																	n[2]=$(echo "$2" | grep -Po "(?<=versionName=')(.+?)(?=')")
																	n[3]=$(echo "$2" | grep -Po "(?<=versionCode=')(.+?)(?=')")
																if [ "$1" = "split" ]; then
																	n[4]=$(echo "$2" | grep -Po "(?<=split=')(.+?)(?=')") && \
																	appname="${n[0]}_(${n[3]})/${n[4]}.apk"
																elif [ -d "${output_dir}/${category}/${n[0]}_(${n[3]})" ]; then
																	mode="bundle"
																	appname="$category/${n[0]}_(${n[3]})/base.apk"
																elif [ "$1" = "normal" ]; then
																	n[1]=$(echo "$2" | grep -Po "(?<=application: label=')(.+?)(?=')")
																			[ -z "${n[1]}" ] && \
																				n[1]=$(echo "$2" | grep -Po "(?<=application-label:')(.+?)(?=')")
																			_echo "_process_apps: label name: ${n[1]}\n" 2
																			n[1]="$(echo -n "${n[1]}" | sed 's#:# -#g; s#\.#+#g; s#\&#and#g; s#\/#-#g')"
																			_echo "_process_apps: label name (filtered): ${n[1]}\n" 2
																	appname="$category/${n[1]}_v${n[2]}(${n[3]}).apk"
																fi

																	_echo "_process_apps: generated name: $appname\n" 2
															}
									_apply_rename()
															{
																		_index_rename()
																									{
																											local x y s i
																											x="$2"; y="${x%.*}"; s="${x##*.}"; i=0
																										while true; do
																												i=$((i+1))
																											if [ ! -e "$x" ]; then
																												_safe_rename "$1" "$x"
																												return 0
																											elif [ -e "$2" ]; then
																												x="${y}_${i}.${s}"
																												continue
																											fi
																										done
																									}
																		_safe_rename()
																									{
																											local mv_src mv_dst src_file dst_file src_dir dst_dir

																											mv_src="$1"; mv_dst="$2"
																											src_file="${mv_src##*/}"; dst_file="${mv_dst##*/}"
																											src_dir="${mv_src%/*}"; dst_dir="${mv_dst%/*}"
	
																											# visual output
																											_echo "- Old name: $src_file\n" 3
																											_echo "- New name: $dst_file\n" 3

																											_mkdir "$dst_dir"
																										while read -r x; do
																												_echo "func_rename: mv_cmd: ${x}\n" 2
																											if [[ "$x" = "renamed "* ]]; then
																												mv_err[0]=$((mv_err[0]+1))
																												_echo "func_rename: mv_err[0]: $x\n" 2
																											elif [[ "$x" = *"are the same file"* ]] || [[ "$x" = *"Skipping overwritting"* ]]; then
																												mv_err[2]=$((mv_err[2]+1))
																												_echo "func_rename: mv_err[2]: $x\n" 2
																											elif [[ "$x" = *"Operation not permitted"* ]]; then
																												mv_err[3]=$((mv_err[3]+1))
																												_echo "func_rename: mv_err[3]: $x\n" 2
																											else
																												mv_err[1]=$((mv_err[1]+1))
																												_echo "func_rename: mv_err[1]: $x\n" 2
																											fi
																										done< <( if [ -s "$mv_dst" ]; then _echo "func_rename: skipping overwritting: '$mv_dst'\n" 2; else mv -v "$mv_src" "$mv_dst" 2>&1; fi)
																									}
																if [ "$mode" = "normal" ]; then
																	output="$2/${appname}"
																elif [ "$mode" = "split" ]; then
																	output="$2/${appname}"
																elif [ "$mode" = "bundle" ]; then
																	output="$2/${appname}"
																fi
																if [ "$category_required" = "yes" ] && [ -z "$category" ]; then
																	echo "- Could not detect category for $1 aboring.."
																	return 1
																elif [ "$archive_mode" = "yes" ]; then
																	_index_rename "$1" "$output"
																else
																	_safe_rename "$1" "$output"
																fi
															}

								_check_file "$1" && \
								_check_contents "$1" && \
								_parse_app_info "$mode" "$manifest" && \
								_apply_rename "$1" "$2"
							}













							_category_init()
													{
															category_file="./category.json"
														if [ ! -s "$category_file" ]; then
															_category_create_db "$category_file"
														elif [ "$(jq 'has("category")' "$category_file")" != "true" ]; then
															echo "- Error $category_file file is malformed."; exit 1
														fi
													}
				_category_create_db()
													{
														echo
														db='{"category":{"Files-Manager":[],"Files-Download":[],"Xposed-Modules":[],"Apps-Require-Root":[],"Miscellaneous":[],"Launchers":[],"Google-Apps":[],"Browsers":[],"Games":[],"Navigation":[],"Educational":[],"Social-Apps":[],"Media-Players":[]}}'
														echo "$db" | jq . >"${1}" || exit 1
													}
				_category_add_value()
													{
																local x g f c tmp
																_category_init; f="$category_file"; x="$1"; g="$2"
																c=$(jq -r '.category | keys[]' "$f" | tr "\n" " ")
															if [[ "$c" != *"$g"* ]]; then
																echo -e "- You passed $g but it is invalid category.\n- Please select valid category and try again:\n   $c"
																exit 1
															fi
															if [ -n "$x" ]; then
																	c=$(jq --arg value "$x" '.category."'$g'" | any(. == $value)' "$f")
																if [ "$c" = "true" ]; then
																	echo "- $x already stored to category $g"
																	return 0
																elif [ "$c" = "false" ]; then
																	c=$(grep -Fcm1 "$x" "$f"); [ $c -ge 1 ] && { echo "- Error $x already stored in different category."; exit 1; }
																	echo "- Storing $x into category $g"
																	tmp="$(mktemp)"
																	jq --arg value "$x" '.category."'$g'"? += [$value]' "$f" >"${tmp}" && mv "${tmp}" "${f}" || exit 1
																	return 0
																fi
															fi
													}
			_category_check_value()
													{
															local i c g f
															_category_init; f="$category_file"; i=0
														while read g; do
																c=$(jq --arg value "$1" '.category."'$g'" | any(. == $value)' "$f")
															if [ "$c" = "true" ]; then
																echo "- the value $1 exists in $g"
																category="$g"; i=$((i+1))
															fi
														done< <(jq -r '.category | keys[]' "$f")
															if [ $i -eq 1 ]; then
																return 0
															elif [ $i -eq 0 ]; then
																unset category
															elif [ $i -ge 2 ]; then
																echo "- Error $1 are stored in different category $i times."; exit 1
															fi
													}



_iferr()
{ # returns: null
		
		local msg
		local cmd_err
	if [ "$?" = "0" ]; then
		return 0
	else
		msg="$1"
		cmd_err="$(sed -z 's/\n/_LF_/g' "${tmp}/err")"
		_echo "${msg} cmd_stderr: ${cmd_err}\n" 1
		return 1
	fi

}



func_get_sdkver()
{ # returns: $min_sdk, $max_sdk

	local min_sdk
	local max_sdk
	min_sdk="$1"
	max_sdk="$2"

	# SDK reversion to Android reversion
sdk_list="\
	sdk35=15 \
	sdk34=14 \
	sdk33=13 \
	sdk32=12.1L \
	sdk31=12 \
	sdk30=11 \
	sdk29=10 \
	sdk28=9 \
	sdk27=8.1 \
	sdk26=8.0 \
	sdk25=7.1 \
	sdk24=7.0 \
	sdk23=6.0 \
	sdk22=5.1.1 \
	sdk21=5.0 \
	sdk20=4.4W \
	sdk19=4.4 \
	sdk18=4.3 \
	sdk17=4.2 \
	sdk16=4.1 \
	sdk15=4.0.3 \
	sdk14=4.0 \
	sdk13=3.2 \
	sdk12=3.1.x \
	sdk11=3.0.x \
	sdk10=2.3.3 \
	sdk9=2.3 \
	sdk8=2.2.2 \
	sdk7=2.1.x \
	sdk6=2.0.1 \
	sdk5=2.0
"

		# find version
	for sdk in $sdk_list; do
		if [[ "$sdk" = "sdk${min_sdk}"* ]]; then
			min_ver="android-$(echo -n "$sdk" | sed 's/.*=//')"
		elif [[ "$sdk" = "sdk${max_sdk}"* ]]; then
			max_ver="android-$(echo -n "$sdk" | sed 's/.*=//')"
		fi
	done
			# if no ver found !
		if [ -z "$min_ver" ]; then
			min_ver="sdk${min_sdk}"
		elif [ -z "$max_ver" ]; then
			max_ver="sdk${max_sdk}"
		fi

}


func_signtrue_check()
{ # returns: signture, stamp

		local x; x="$1"
		_echo "_process_apps: checking the signature: '$x'\n" 2
		#cert="$(unzip -lqq "$x" | grep -E "\.RSA|\.DSA")"
		signature="$(grep -Fcm1 "android@android.com" "$x")"
	if [ -n "$cert" ]; then
		signature="$(unzip -pqq "$x" "$cert" | grep -Fcm1 "android@android.com")"
	else
		signature="$(grep -Fcm1 "android@android.com" "$x")"
	fi
	if [ "$signature" = "1" ]; then
		#stamp="$(md5 "$x" | awk '{print $2}')"
		stamp="modified"
		_echo "_process_apps: detected signature: 'Android Debug'\n" 2
	else
		stamp="vertified"
		_echo "_process_apps: detected signature: 'Private'\n" 2
	fi

}


func_detect_category()
{ # returns: $category
		
		# determine category (need improve !)
		local x
		local src
		local list
		local f
		x="$1"
		src="$2"

	if [ "$archive_mode" = "yes" ]; then
			_echo "func_detect_category: detecting category target: '$x' source: '$src'\n" 2
			list="$(unzip -l "$x" lib/* -- *.dex AndroidManifest.xml -- *xposed_init* | sed '/Name/d; /----/d; /Archive: /d' | awk '{print $4}' | tr '\n' ' ')"
				if [ -z "$(echo -n $list | tr -d ' ')" ]; then
					list="null"
					_echo "func_detect_category: possibly invalid apk: 'null' for: '$src'\n" 2
					return 1
				fi
			_echo "func_detect_category: found files: '$list' inside: '$src'\n" 2
		for i in $list; do
				# apparently most apps unnecessary includes getObbDir, should we blame androidSDK for that?
				#result="$(unzip -pqq "$x" "$t" | grep -cao "getObbDir.[^s]")" # look for dir(X) but not dir(s), getObbDir and getObbDirs are totally different. matching libs(.so) are accurate but not for .dex !
				f="${i##*/}"
			if [ "$f" = "libunity.so" ] || [ "$f" = "libUE4.so" ]; then
				category="APK-Games"
				_echo "func_detect_category: found (libunity.so/libUE4.so) in target: '$x' of: '$src'\n" 2
				break
			elif [ "$f" = "xposed_init" ]; then
				category="Xposed-Apps"
				_echo "func_detect_category: found (xposed_init) in target: '$x' of: '$src'\n" 2
				break
			elif [ "$f" = "AndroidManifest.xml" ]; then
							# shipping axmldec binary may considered in feature
							# androidSDK provides an atttibute in manifest which can declare the app category.
							# however many apps perfers to not use this attribute and instead rely on PlayStore scheme (domains ids?).
							r="$(unzip -pqq "$x" "$f" | tr -d "\0" | grep -Eoc "category\.GAME|android\.hardware\.gamepad|com\.google\.android\.gms\.games\.APP_ID|com\.facebook\.unity\.FBUnityGameRequestActivity")"
						if [ "$r" -ge "1" ]; then
							category="APK-Games"
							_echo "func_detect_category: found (possbile game attribute) in target: '$x' of: '$src'\n" 2
							break
						fi
							r="$(unzip -pqq "$x" "$f" | tr -d "\0" | grep -Eoc "android\.permission\.WRITE_MEDIA_STORAGE|android\.permission\.WRITE_EXTERNAL_STORAGE|android\.permission\.MANAGE_EXTERNAL_STORAGE")"
						if [ "$r" -ge "1" ]; then
							category="File-Managers"
							_echo "func_detect_category: found (possible file-manager attribute) in target: '$x' of: '$src'\n" 2
							break
						fi
						category="Other-Apps"
						_echo "func_detect_category: could not detect category for target: '$x' of: '$src'\n" 2
			fi
		done
	fi
}


func_parse_arch()
{ # returns: native_arch

		native_arch="$(echo -n "$1" | grep -iE "x86|arm|mips" | awk -F 'config.' '{print $2}' | sort | uniq -c | awk '{print $2}' | tr -d " \n" | sed 's/\.apk//g')"
		#local native_arch="$(echo -ne -- "$file_content" | grep -iE "x86|arm|mips" | awk -F 'config.' '{print $2}' | sort | uniq -c | awk '{print $2}' | tr -d " \n" | sed 's/\.apk//g; s/aarm/a+arm/g; s/abia/abi+a/g; s/ax86/a+x86/g; s/x86x86/x86+x86/g')"
		if [ -z "$native_arch" ]; then
			native_arch="NoNative"
		fi
		_echo "func_parse_arch: native arch: '$native_arch'\n" 2

}


func_extract_apk()
{ # returns: null

		local mode
		local x
		local c
		
		mode="$1"
		x="$2"
		c="$3"
	if [ "$mode" = "main" ]; then
		local t="$(echo -n "$c" | grep -F ".apk")"
		_echo "func_extract_apk: extracting main APK: '$t'\n" 2
		_echo "func_extract_apk: extracting as: '${tmp}/base.apk'\n" 2
		unzip -pqq "$x" "$t">"${tmp}/base.apk" 2>"${tmp}/err"
		_iferr "func_extract_apk: failed extracting (unzip_main): ${t}" 2
		_echo "func_extract_apk: moving unneedeed file: '$x' into: '${tmp}/base_bak.apk'\n" 2
		mv --backup=t "$x" "$tmp/base_bak.apk"
	elif [ "$mode" = "base" ]; then
		_echo "func_extract_apk: extracting base APK: '$c'\n" 2
		_echo "func_extract_apk: extracting as: '${tmp}/base.apk'\n" 2
		unzip -pqq "$x" "$c">"${tmp}/base.apk" 2>"${tmp}/err"
		_iferr "func_extract_apk: failed extracting (unzip_base): ${c}"
	elif [ "$mode" = "obb" ]; then
		#local t="$(echo -ne -- "$c" | grep -vF ".obb")"
		_echo "func_extract_apk: extracting combined APK: '$c'\n" 2
		_echo "func_extract_apk: extracting as: '${tmp}/base.apk'\n" 2
		unzip -pqq "$x" "$c">"${tmp}/base.apk" 2>"${tmp}/err"
		_iferr "func_extract_apk: failed extracting (unzip_obb): ${c}"
	fi
}


		_config "$@"
