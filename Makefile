#
# This Makefile builds and packages bottle-imp by invoking relevant sub-makefiles.
#

# Bottle-Imp version
IMPVERSION = 0.13

# Determine this makefile's path.
# Be sure to place this BEFORE `include` directives, if any.
THIS_FILE := $(lastword $(MAKEFILE_LIST))

# The values of these variables depend upon DESTDIR, set in the recursive call to
# the internal-package target.
DESTDIR = /usr/local
INSTALLDIR = $(DESTDIR)/lib/bottle-imp
BINDIR = $(DESTDIR)/bin
SVCDIR = $(DESTDIR)/lib/systemd/system
USRLIBDIR = $(DESTDIR)/lib

# used only by TAR installer
MAN8DIR = $(DESTDIR)/share/man/man8
DOCDIR = $(DESTDIR)/share/doc/bottle-imp
ETCSVCDIR = /etc/systemd/system

#
# Default target: list options
#

default:
	# Build options include:
	#
	# Build binaries only.
	#
	# make build-binaries
	#
	# Package
	#
	# make package
	#   make package-debian
	#     make package-debian-amd64
	#     make package-debian-arm64
	#   make package-tar
	#     make package-tar-amd64
	#     make package-tar-arm64
	#
	# make package-arch
	#
	# Clean up
	#
	# make clean
	#   make clean-debian
	#   make clean-tar
	#
	# make clean-arch

#
# Targets: individual end-product build.
#

clean: clean-debian clean-tar
	make -C binsrc clean
	rm -rf out

package: package-debian package-tar


#
# Debian packaging
#

package-debian: package-debian-amd64 package-debian-arm64

package-debian-amd64: make-output-directory
	mkdir -p out/debian
	debuild --no-sign
	mv ../bottle-imp_* out/debian

package-debian-arm64: make-output-directory
	mkdir -p out/debian
	debuild -aarm64 -b --no-sign
	mv ../bottle-imp_* out/debian

clean-debian:
	debuild -- clean

# Internal packaging functions

internal-debian-package:
	mkdir -p debian/bottle-imp
	@$(MAKE) -f $(THIS_FILE) DESTDIR=debian/bottle-imp/usr internal-package


#
# Tarball packaging
#

package-tar: package-tar-amd64 package-tar-arm64

package-tar-amd64: make-output-directory
	mkdir -p out/tar
	rm -rf tarball
	mkdir -p tarball

	$(MAKE) -f $(THIS_FILE) build-binaries

	fakeroot $(MAKE) -f $(THIS_FILE) DESTDIR=tarball internal-package
	fakeroot $(MAKE) -f $(THIS_FILE) DESTDIR=tarball internal-supplement

	fakeroot $(MAKE) -f $(THIS_FILE) DESTDIR=tarball TARCH=amd64 archive-tarfile

	mv bottle-imp-*-amd64.tar.gz out/tar

package-tar-arm64: make-output-directory
	mkdir -p out/tar
	rm -rf tarball
	mkdir -p tarball

	DEB_TARGET_ARCH=arm64 $(MAKE) -f $(THIS_FILE) build-binaries

	fakeroot $(MAKE) -f $(THIS_FILE) DESTDIR=tarball internal-package
	fakeroot $(MAKE) -f $(THIS_FILE) DESTDIR=tarball internal-supplement

	fakeroot $(MAKE) -f $(THIS_FILE) DESTDIR=tarball TARCH=arm64 archive-tarfile

	mv bottle-imp-*-arm64.tar.gz out/tar

clean-tar:
	rm -rf tarball

# Internal packaging functions

archive-tarfile:
	# tar it up
	tar zcvf bottle-imp-$(IMPVERSION)-$(TARCH).tar.gz tarball/* --transform='s/^tarball//'


#
# Arch packaging
#

package-arch:
	mkdir -p out/arch
	updpkgsums
	BUILDDIR=/tmp PKDEST=$(PWD)/out/arch makepkg
	rm -rf $(PWD)/bottle-imp
	mv *.zst out/arch

clean-arch:
	rm -rf $(PWD)/genie
	rm -rf out/arch


#
# Helpers: intermediate build stages.
#

# We can assume DESTDIR is set, due to how the following are called.

internal-systemd:
	# Systemd-as-container compensation services.
	install -Dm 0644 -o root "othersrc/usr-lib/systemd/system/imp-fixshm.service" -T "$(SVCDIR)/imp-fixshm.service"
	install -Dm 0644 -o root "othersrc/usr-lib/systemd/system/imp-pstorefs.service" -T "$(SVCDIR)/imp-pstorefs.service"
	install -Dm 0644 -o root "othersrc/usr-lib/systemd/system/imp-securityfs.service" -T "$(SVCDIR)/imp-securityfs.service"
	install -Dm 0644 -o root "othersrc/usr-lib/systemd/system/imp-remount-root-shared.service" -T "$(SVCDIR)/imp-remount-root-shared.service"

	# WSLg mount file
	install -Dm 0644 -o root "othersrc/usr-lib/systemd/system/imp-wslg-socket.service" -T "$(SVCDIR)/imp-wslg-socket.service"

	systemctl enable imp-fixshm.service
	systemctl enable imp-pstorefs.service
	systemctl enable imp-securityfs.service
	systemctl enable imp-remount-root-shared.service

	systemctl enable imp-wslg-socket.service


internal-binfmt:
	# binfmt.d
	install -Dm 0644 -o root "othersrc/usr-lib/binfmt.d/WSLInterop.conf" -t "$(USRLIBDIR)/binfmt.d"


internal-package: internal-systemd internal-binfmt
	# binaries
	mkdir -p "$(BINDIR)"
	install -Dm 6755 -o root "binsrc/imp-wrapper/imp" -t "$(BINDIR)"
	install -Dm 0755 -o root "binsrc/out/imp" -t "$(INSTALLDIR)"

	# Runtime dir mapping
	install -Dm 0755 -o root "othersrc/scripts/wait-forever.sh" -t "$(INSTALLDIR)"


internal-clean:
	make -C binsrc clean

# internal-supplement: TMPBUILDDIR = $(shell mktemp -d -t bit-XXXXXX)
internal-supplement: TMPBUILDDIR = /tmp/bi-build
internal-supplement:
	# Do the things that debuild would do if debuild was doing things.
	mkdir -p $(TMPBUILDDIR)

	# Documentation.
	/usr/bin/cp debian/changelog $(TMPBUILDDIR)/changelog
	/usr/bin/cp othersrc/docs/README.md $(TMPBUILDDIR)/README.md

	gzip $(TMPBUILDDIR)/changelog
	gzip $(TMPBUILDDIR)/README.md

	mkdir -p "$(DOCDIR)"
	install -Dm 0644 -o root $(TMPBUILDDIR)/changelog.gz -t "$(DOCDIR)"
	install -Dm 0644 -o root debian/copyright -t "$(DOCDIR)"
	install -Dm 0644 -o root othersrc/docs/LICENSE.md -t "$(DOCDIR)"
	install -Dm 0644 -o root $(TMPBUILDDIR)/README.md.gz -t "$(DOCDIR)"

	# Man page.
	/usr/bin/cp othersrc/docs/imp.8 $(TMPBUILDDIR)/imp.8
	gzip -f9 $(TMPBUILDDIR)/imp.8

	mkdir -p $(MAN8DIR)
	install -Dm 0644 -o root "$(TMPBUILDDIR)/imp.8.gz" -t $(MAN8DIR)

	# Cleanup temporary directory
	rm -rf $(TMPBUILDDIR)

make-output-directory:
	mkdir -p out

build-binaries:
	make -C binsrc
