# Contributing

Bug fixes and improvements are always welcome!

## Commit format

Prefix your commits with one of these strings followed up by a whitespace:

| Prefix | Example |
|--------------|----------------------------------------------------------------------------------------|
| `build:` | changes in build process |
| `doc:` | changes in documentation files |
| `installer:` | changes in installation process (can contain documentation changes if belonging to it) |
| `git:` | changes in `.gitignore` |
| `all:` | changes that have high impact on installer structure (moved directories, ...) |

Example: `doc: fix typo in readme`

## Pull requests

Please do your pull requests always against the [devel branch](https://github.comhttps://github.com/FooDeas/raspberrypi-ua-netinst/tree/devel).

**Note:**  
The [devel branch](https://github.com/FooDeas/raspberrypi-ua-netinst/tree/devel) should always contain stable and tested versions!

If the [devel branch](https://github.com/FooDeas/raspberrypi-ua-netinst/tree/devel) has "enough" or important changes, it will (selectively) get merged into [master](https://github.com/FooDeas/raspberrypi-ua-netinst), [tagged](https://github.com/FooDeas/raspberrypi-ua-netinst/tags) and [released](https://github.com/FooDeas/raspberrypi-ua-netinst/releases).
