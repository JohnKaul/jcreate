# ==============================================================
# tool setup
# ==============================================================
#
CC      =	chmod
# processor
CFLAGS  =	+x
# processor flags

SRC_EXT =	.sh
# source file ext

SED		:=	sed

# ==============================================================
# project information
# ==============================================================
#
SRCDIR  = src
DOCDIR 	= doc
PREFIX	:=	$(HOME)/bin
MANPATH = /usr/local/share/man/man7

PROJECTNAME = jcreate

# ==============================================================
# files
# ==============================================================
#
SOURCES =	$(SRCDIR)/jcreate.sh \
		$(SRCDIR)/jdestroy.sh

# ==============================================================
# Begin makefile
# ==============================================================
#
all: $(PROJECTNAME)

$(PROJECTNAME) :
	@echo "Processing..."
	$(CC) $(CFLAGS) $(SOURCES)

install:
	@echo "Installing jcreate to: $(PREFIX)"
	@cp $(SRCDIR)/jdestroy.sh $(PREFIX)/
	@cp $(SRCDIR)/jcreate.conf $(PREFIX)/
	@$(SED) 's,~/bin/,$(PREFIX),g' $(SRCDIR)/jcreate.sh > $(PREFIX)/jcreate.sh
	@if [ ! -d $(PREFIX)/man/man7 ]; then mkdir -p $(PREFIX)/man/man7; fi
	@cp ./doc/jcreate.7 $(PREFIX)/man/man7/jcreate.7

uninstall: remove
remove:
	@echo "Uninstalling jcreate from: $(INSTALLDIR)"
	@if [ -f $(PREFIX)/jcreate.sh ]; then rm $(PREFIX)/jcreate.sh; fi
	@if [ -f $(PREFIX)/jdestroy.sh ]; then rm $(PREFIX)/jdestroy.sh; fi
	@if [ -f $(PREFIX)/jcreate.conf ]; then rm $(PREFIX)/jcreate.conf; fi
	@if [ -f $(PREFIX)/man/man7/jcreate.7 ]; then rm $(PREFIX)/man/man7/jcreate.7; fi

# vim: set noet set ff=unix
