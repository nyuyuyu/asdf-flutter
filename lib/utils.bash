#!/usr/bin/env bash

set -euo pipefail

FLUTTER_LIST_BASE_URL="https://storage.googleapis.com"
TOOL_NAME="flutter"
TOOL_TEST="flutter --help"

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

tar_decompression_option() {
	case "$(uname -s)" in
	"Linux")
		echo "-xJf"
		;;
	*)
		echo "-xzf"
		;;
	esac
}

curl_opts=(-fsSL)

sort_versions() {
	sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
		LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

list_released_versions() {
	curl "${curl_opts[@]}" "$(flutter_download_list_url)" | jq -r '.releases[].version |= gsub("^v"; "") | .releases'
}

list_filter_by_archtecture() {
	local arch="$1"
	local query=".[] | select(.dart_sdk_arch == \"$arch\")"
	if [ "$arch" == "x64" ]; then
		query=".[] | select(.dart_sdk_arch == \"$arch\" or (has(\"dart_sdk_arch\") | not))"
	fi

	list_released_versions | jq -r "$query"
}

list_all_versions() {
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

	if [ "$install_type" != "version" ]; then
		fail "asdf-$TOOL_NAME supports release installs only"
	fi

	(
		rmdir "$install_path"
		mv "$ASDF_DOWNLOAD_PATH" "$install_path"

		local tool_cmd
		tool_cmd="$(echo "$TOOL_TEST" | cut -d' ' -f1)"
		test -x "$bin_path/$tool_cmd" || fail "Expected $bin_path/$tool_cmd to be executable."

		echo "$TOOL_NAME $version installation was successful!"
	) || (
		rm -rf "$install_path"
		fail "An error occurred while installing $TOOL_NAME $version."
	)
}
