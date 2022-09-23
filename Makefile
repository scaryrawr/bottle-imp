#
# This Makefile builds and packages bottle-imp by invoking relevant sub-makefiles.
#

# Bottle-Imp version
IMPVERSION = 0.2

# Determine this makefile's path.
# Be sure to place this BEFORE `include` directives, if any.
THIS_FILE := $(lastword $(MAKEFILE_LIST))

# The values of these variables depend upon DESTDIR, set in the recursive call to
# the internal-package target.
INSTALLDIR = $(DESTDIR)/usr/lib/bottle-imp
BINDIR = $(DESTDIR)/usr/bin
SVCDIR = $(DESTDIR)/usr/lib/systemd/system
USRLIBDIR = $(DESTDIR)/usr/lib

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
	# make package-debian
	#   make package-debian-amd64
	#
	# Clean up
	#
	# make clean
	# make clean-debian

#
# Targets: individual end-product build.
#

clean: clean-debian
	make -C binsrc clean
	rm -rf out

package: package-debian


#
# Debian packaging
#

package-debian: package-debian-amd64

package-debian-amd64: make-output-directory
	mkdir -p out/debian
	debuild --no-sign
	mv ../bottle-imp_* out/debian

clean-debian:
	debuild -- clean

# Internal packaging functions

internal-debian-package:
	mkdir -p debian/bottle-imp
	@$(MAKE) -f $(THIS_FILE) DESTDIR=debian/bottle-imp internal-package

# We can assume DESTDIR is set, due to how the following are called.

internal-package:

	# binaries
	mkdir -p "$(BINDIR)"
	install -Dm 6755 -o root "binsrc/imp-wrapper/imp" -t "$(BINDIR)"
	install -Dm 0755 -o root "binsrc/out/imp" -t "$(INSTALLDIR)"

	# Runtime dir mapping
	install -Dm 0755 -o root "othersrc/scripts/wait-forever.sh" -t "$(INSTALLDIR)"
	install -Dm 0755 -o root "othersrc/scripts/map-user-runtime-dir.sh" -t "$(INSTALLDIR)"
	install -Dm 0755 -o root "othersrc/scripts/unmap-user-runtime-dir.sh" -t "$(INSTALLDIR)"

	# Unit override files.
	install -Dm 0644 -o root "othersrc/usr-lib/systemd/system/user-runtime-dir@.service.d/override.conf" -t "$(SVCDIR)/user-runtime-dir@.service.d"

	# binfmt.d
	install -Dm 0644 -o root "othersrc/usr-lib/binfmt.d/WSLInterop.conf" -t "$(USRLIBDIR)/binfmt.d"

internal-clean:
	make -C binsrc clean

#
# Helpers: intermediate build stages.
#

make-output-directory:
	mkdir -p out

build-binaries:
	make -C binsrc
