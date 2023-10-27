<div align="center">

# asdf-flutter [![Build](https://github.com/nyuyuyu/asdf-flutter/actions/workflows/build.yml/badge.svg)](https://github.com/nyuyuyu/asdf-flutter/actions/workflows/build.yml) [![Lint](https://github.com/nyuyuyu/asdf-flutter/actions/workflows/lint.yml/badge.svg)](https://github.com/nyuyuyu/asdf-flutter/actions/workflows/lint.yml)

[Flutter](https://flutter.dev/) plugin for the [asdf version manager](https://asdf-vm.com).

</div>

# Contents

- [Dependencies](#dependencies)
- [Install](#install)
- [Support fvm](#support-fvm)
- [Contributing](#contributing)
- [Troubleshooting](#troubleshooting)
- [License](#license)

# Dependencies

- `bash`, `curl`, `tar`: generic POSIX utilities.
- `jq`: recommended.
- `xz`: only required for Linux.

# Install

Plugin:

```shell
asdf plugin add flutter https://github.com/nyuyuyu/asdf-flutter.git
```

flutter:

```shell
# Show all installable versions
asdf list-all flutter

# Install specific version
asdf install flutter latest

# Set a version globally (on your ~/.tool-versions file)
asdf global flutter latest

# Now flutter commands are available
flutter --help
```

Check [asdf](https://github.com/asdf-vm/asdf) readme for more instructions on how to
install & manage versions.

# Support fvm

If you have set `legacy_version_file = yes` in `$HOME/.asdfrc`, you can read the Flutter version from `.fvm/fvm_config.json`, the [fvm](https://fvm.app/) configuration file.

# Troubleshooting

## VS Code

<img width="668" alt="image" src="https://user-images.githubusercontent.com/877327/158042623-290554da-0b9d-4fe0-b91b-c85b9c48e2d1.png">

To fix the "Could not find a Flutter SDK" error, you can set the `FLUTTER_ROOT` environment variable in your `.bashrc` or `.zshrc` file:

```bash
export FLUTTER_ROOT="$(asdf where flutter)"
```

# Contributing

Contributions of any kind welcome! See the [contributing guide](contributing.md).

[Thanks goes to these contributors](https://github.com/nyuyuyu/asdf-flutter/graphs/contributors)!

# License

See [LICENSE](LICENSE) © [nyuyuyu](https://github.com/nyuyuyu/)
