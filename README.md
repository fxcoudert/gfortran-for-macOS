# gfortran for macOS

The goal of this repository is to host GNU Fortran packages for macOS. These are simple installers, that will install the GCC compilers (including gfortran) in `/usr/local/gfortran`.

### Downloads

| GCC/gfortran version | macOS version | download links |
| --------------------- | ------------ | -------------- |
| GCC 16.2 | for macOS 26 (Tahoe) | [Apple Silicon](https://github.com/fxcoudert/gfortran-for-macOS/releases/download/16.2-tahoe/gfortran-16.2-Tahoe.dmg) |
| GCC 15.3 | for macOS 26 (Tahoe) | [Apple Silicon](https://github.com/fxcoudert/gfortran-for-macOS/releases/download/15.3-tahoe/gfortran-15.3-Tahoe.dmg) |
| GCC 14.2 | for macOS 15 (Sequoia) | [Apple Silicon](https://github.com/fxcoudert/gfortran-for-macOS/releases/download/14.2-sequoia/gfortran-14.2-ARM-Sequoia.dmg) or [Intel](https://github.com/fxcoudert/gfortran-for-macOS/releases/download/14.2-sequoia/gfortran-14.2-Intel-Sequoia.dmg) |
| GCC 14.2 | for macOS 14 (Sonoma) | [Apple Silicon](https://github.com/fxcoudert/gfortran-for-macOS/releases/download/14.2-sonoma/gfortran-ARM-14.2-Sonoma.dmg) or [Intel](https://github.com/fxcoudert/gfortran-for-macOS/releases/download/14.2-sonoma/gfortran-Intel-14.2-Sonoma.dmg) |
| GCC 13.2 | for macOS 14 (Sonoma) | [Apple Silicon](https://github.com/fxcoudert/gfortran-for-macOS/releases/download/13.2-sonoma/gfortran-ARM-13.2-Sonoma.dmg) |


Follow [this link to download for older versions](https://github.com/fxcoudert/gfortran-for-macOS/releases).

----

### How to uninstall?

```
sudo rm -rf /usr/local/gfortran /usr/local/bin/gfortran
sudo pkgutil --forget com.gnu.gfortran
```

----

*If you are interested in how these installers are built, the documentation is [here](build_package.md).*
