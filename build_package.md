# How to build a GCC installer for MacOS

These are my notes on how to build a gfortran / GCC installer for macOS. The goal is to obtain a nice Apple installer, that puts a complete GCC installation in `/usr/local/gfortran`. It then symlinks `gfortran` into `/usr/local/bin`.

The focus is on `gfortran`, as the Fortran community is a heavy user, because Apple's Xcode includes a nice C compiler (`clang`), but no Fortran compiler.

----

To build a package :

- I work in a work directory called `$ROOT`
- I have static GMP, MPFR, MPC and ISL libraries in `$ROOT/deps`. These can be take from the respective Homebrew packages, removing the shared libraries (`*.dylib`).

The steps are the following:

1. Edit `PATH` to make sure I don't have custom software (Homebrew, Anaconda, texlive, `/opt`, etc.)

2. Get the GCC sources (e.g. `gcc-8.2.0.tar.xz`), extract them to `$ROOT/gcc-8.2.0`. Create a `$ROOT/build` and go there.

3. Configure the build:

  ```
../gcc-8.2.0/configure --prefix=/usr/local/gfortran --with-gmp=$ROOT/deps --enable-languages=c,c++,fortran,objc,obj-c++ --build=x86_64-apple-darwin16
```

  On Mojave and later, the following flags need to be added:

  ```
--disable-multilib --with-native-system-header-dir=/usr/include --with-sysroot=/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk
```

4. Build by running `make`.

5. Check that the build worked by running `make check-gcc` and `make check-gfortran` inside `$ROOT/build/gcc`. (Or run `make check` at the toplevel, but it needs additional dependencies, such as `autogen`.)

6. Install with: `DESTDIR=$ROOT/package make install`

7. Strip some binaries, remove some hard links:
  ```
cd $ROOT/package/usr/local/gfortran
rm bin/*-apple-darwin* bin/c++
strip bin/*
strip libexec/gcc/*/*/*1* libexec/gcc/*/*/*2
strip libexec/gcc/*/*/install-tools/fixincl
```

8. Build a signed installer:
  ```
cd $ROOT
pkgbuild --root package --scripts package_resources --identifier com.gnu.gfortran --version 8.2.0 --install-location / --sign "Developer ID Installer: Francois-Xavier Coudert" gfortran.pkg
```

  This requires a `postinstall` script inside `package_resources/`.

9. Verify the signature: `spctl --assess --type install gfortran.pkg`, which should exit with status code 0.

10. Create a DMG for the installer:
  ```
mkdir gfortran-8.2-Mojave
mv gfortran.pkg gfortran-8.2-Mojave/
cp package-README.html gfortran-8.2-Mojave/README.html
./mkdmg.pl gfortran-8.2-Mojave.dmg gfortran-8.2-Mojave/
```

  During that step, look at the `README.html` file and update it if necessary!

11. Cleanup!
  ```
  rm -rf gfortran-8.2-Mojave/
  rm -rf package/*/
```
