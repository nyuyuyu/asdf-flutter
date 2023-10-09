#!/usr/bin/env bash

set -euo pipefail

# TODO: Ensure this is the correct GitHub homepage where releases can be downloaded for flutter.
GH_REPO="https://github.com/flutter/flutter"
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
	local version filename url
	version="$1"
	filename="$2"

	# TODO: Adapt the release URL convention for flutter
	url="$GH_REPO/archive/v${version}.tar.gz"

	echo "* Downloading $TOOL_NAME release $version..."
	curl "${curl_opts[@]}" -o "$filename" -C - "$url" || fail "Could not download $url"
}

install_version() {
	local install_type="$1"
	local version="$2"
	local install_path="${3%/bin}/bin"

	if [ "$install_type" != "version" ]; then
		fail "asdf-$TOOL_NAME supports release installs only"
	fi

	(
		mkdir -p "$install_path"
		cp -r "$ASDF_DOWNLOAD_PATH"/* "$install_path"

		# TODO: Assert flutter executable exists.
		local tool_cmd
		tool_cmd="$(echo "$TOOL_TEST" | cut -d' ' -f1)"
		test -x "$install_path/$tool_cmd" || fail "Expected $install_path/$tool_cmd to be executable."

		echo "$TOOL_NAME $version installation was successful!"
	) || (
		rm -rf "$install_path"
		fail "An error occurred while installing $TOOL_NAME $version."
	)
}
