#!/usr/bin/env bash

set -euo pipefail

FLUTTER_LIST_BASE_URL="https://storage.googleapis.com"
JQ_DOWNLOAD_BASE_URL="https://github.com/jqlang/jq/releases/latest/download"
TOOL_NAME="flutter"
TOOL_TEST="flutter --help"

curl_opts=(-fsSL)

fail() {
	echo -e "asdf-$TOOL_NAME: $*"
	exit 1
}

platform() {
	case "$(uname -s)" in
	"Darwin")
		echo "macos"
		;;
	"Linux")
		echo "linux"
		;;
	*)
		fail "Unsupported platform"
		;;
	esac
}

platform_extension() {
	case "$(uname -s)" in
	"Linux")
		echo "tar.xz"
		;;
	*)
		echo "zip"
		;;
	esac
}

platform_tar() {
	case "$(uname -s)" in
	"Darwin")
		echo "bsdtar"
		;;
	*)
		echo "tar"
		;;
	esac
}

machine_architecture() {
	case "$(uname -m)" in
	"x86_64")
		echo "x64"
		;;
	"arm64")
		echo "arm64"
		;;
	*)
		fail "Unsupported archtecture"
		;;
	esac
}

flutter_download_list_url() {
	echo "$FLUTTER_LIST_BASE_URL/flutter_infra_release/releases/releases_$(platform).json"
}

cache_dir() {
	local current_script_path plugin_dir
	current_script_path=${BASH_SOURCE[0]}
	plugin_dir=$(dirname "$(dirname "$current_script_path")")

	echo "$plugin_dir/.cache"
}

jq_bin_dir() {
	echo "$(cache_dir)/bin"
}

jq_filename() {
	case "$(uname -s)" in
	Darwin)
		case "$(uname -m)" in
		x86_64)
			echo "jq-macos-amd64"
			;;
		arm64)
			echo "jq-macos-arm64"
			;;
		*)
			fail "Unsupported archtecture"
			;;
		esac
		;;
	Linux)
		case "$(uname -m)" in
		x86_64)
			echo "jq-linux-amd64"
			;;
		*)
			fail "Unsupported archtecture"
			;;
		esac
		;;
	*)
		fail "Unsupported archtecture"
		;;
	esac
}

download_jq_if_not_exists() {
	if ! which jq >/dev/null 2>&1; then
		PATH="$PATH:$(jq_bin_dir)"
		export PATH
		if ! which jq >/dev/null 2>&1; then
			local url jq_path
			url="$JQ_DOWNLOAD_BASE_URL/$(jq_filename)"
			jq_path="$(jq_bin_dir)/jq"

			mkdir -p "$(jq_bin_dir)"
			curl "${curl_opts[@]}" "$url" -o "$jq_path"
			chmod +x "$jq_path"
		fi
	fi
}

sort_versions() {
	sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
		LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

list_released_versions() {
	# download `jq` if it is not in your PATH variable
	download_jq_if_not_exists

	curl "${curl_opts[@]}" "$(flutter_download_list_url)" | jq -r '.releases[].version |= gsub("^v"; "") | .releases'
}

list_filter_by_archtecture() {
	local arch="$1"
	local query=".[] | select(.dart_sdk_arch == \"$arch\")"
	if [ "$arch" == "x64" ]; then
		query=".[] | select(.dart_sdk_arch == \"$arch\" or (has(\"dart_sdk_arch\") | not))"
	fi

	# download `jq` if it is not in your PATH variable
	download_jq_if_not_exists

	list_released_versions | jq -r "$query"
}

list_all_versions() {
	# download `jq` if it is not in your PATH variable
	download_jq_if_not_exists

	list_filter_by_archtecture "$(machine_architecture)" | jq -r '.version + "-" + .channel'
}

download_release() {
	local version filename version_without_suffix channel url
	version="$1"
	filename="$2"
	version_without_suffix="$(echo "$version" | sed -E 's/-(stable|beta|dev)$//')"
	channel="$(echo "$version" | grep -oE '(stable|beta|dev)$')"
	if [ -z "$channel" ]; then
		channel="stable"
	fi

	# download `jq` if it is not in your PATH variable
	download_jq_if_not_exists

	local query=".[] | select(.channel == \"$channel\") | select(.version | test(\"^v?\" + \"$version_without_suffix\"))"
	local target
	target="$(list_released_versions | jq -r "$query")"
	if [ "$(echo "$target" | jq -s 'length')" -gt 1 ]; then
		query="select(.dart_sdk_arch == \"$(machine_architecture)\")"
		target=$(echo "$target" | jq -r "$query")
	fi

	local archive_file
	archive_file="$(echo "$target" | jq -r '.archive')"
	url="$FLUTTER_LIST_BASE_URL/flutter_infra_release/releases/$archive_file"

	echo "* Downloading $TOOL_NAME release $version..."
	curl "${curl_opts[@]}" -o "$filename" -C - "$url" || fail "Could not download $url"
}

install_version() {
	local install_type="$1"
	local version="$2"
	local install_path="${3%/bin}"
	local bin_path="$install_path/bin"

	echo "Install type: $install_type"
	echo "Version: $version"
	echo "Install path: $install_path"
	echo "Bin path: $bin_path"

	if [ "$install_type" != "version" ] && [ "$install_type" != "ref" ]; then
		fail "asdf-$TOOL_NAME supports release and ref installs only"
	fi

	if [ "$install_type" = "ref" ]; then
		git clone --depth 1 https://github.com/flutter/flutter "$install_path"
		cd "$install_path"
		git fetch --depth=1 origin "$version"
		git checkout "$version"
	elif [ "$install_type" = "version" ]; then
		rmdir "$install_path"
		mv "$ASDF_DOWNLOAD_PATH" "$install_path"
	fi

	(
		local tool_cmd
		tool_cmd="$(echo "$TOOL_TEST" | cut -d' ' -f1)"
		test -x "$bin_path/$tool_cmd" || fail "Expected $bin_path/$tool_cmd to be executable."

		echo "$TOOL_NAME $version installation was successful!"
	) || (
		rm -rf "$install_path"
		fail "An error occurred while installing $TOOL_NAME $version."
	)
}

parse_fvm_config() {
	local file_path file_name version
	file_path="$1"
	file_name="$(basename -- "$file_path")"
	version="unknown"

	# download `jq` if it is not in your PATH variable
	download_jq_if_not_exists

	if [ "$file_name" == ".fvmrc" ]; then
		version="$(jq <"$file_path" -r '.flutter |= gsub("^v"; "") | .flutter')"
	elif [ "$file_name" == "fvm_config.json" ]; then
		version="$(jq <"$file_path" -r '.flutterSdkVersion |= gsub("^v"; "") | .flutterSdkVersion')"
	fi
	echo "$version"
}

create_cache_file() {
	local file expire now file_time diff
	file="$1"
	expire="$2"

	if [ ! -e "$file" ]; then
		mkdir -p "$(cache_dir)"
		list_all_versions | sort_versions >"$file"
	else
		now="$(date +%s)"
		file_time="$(date -r "$file" +%s)"
		diff="$((now - file_time))"
		if [ "$diff" -gt "$expire" ]; then
			mkdir -p "$(cache_dir)"
			list_all_versions | sort_versions >"$file"
		fi
	fi
}
