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
PREFIX	:=	/usr/local/bin
MANPATH = /usr/local/share/man/man7
CONFPATH = /usr/local/etc

PROJECTNAME = jcreate

# ==============================================================
# files
# ==============================================================
#
SOURCES =	\
		$(SRCDIR)/jcreate.sh \
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
	@echo "Installing $(PROJECTNAME) to: $(PREFIX)"
	@$(SED) 's,/usr/local/etc/,$(CONFPATH),g' $(SRCDIR)/jdestroy.sh > $(PREFIX)/jdestroy
	@cp $(SRCDIR)/$(PROJECTNAME).conf $(CONFPATH)/$(PROJECTNAME).conf
	@$(SED) 's,/usr/local/etc/,$(CONFPATH),g' $(SRCDIR)/$(PROJECTNAME).sh > $(PREFIX)/$(PROJECTNAME)
	@$(CC) $(CFLAGS) $(PREFIX)/$(PROJECTNAME)
#-X- 	@if [ ! -d $(MANPATH) ]; then mkdir -p $(MANPATH); fi
	@cp $(DOCDIR)/$(PROJECTNAME).7 $(MANPATH)/$(PROJECTNAME).7

uninstall: remove
remove:
	@echo "Uninstalling $(PROJECTNAME) from: $(INSTALLDIR)"
	# jcreate
	@if [ -f $(PREFIX)/$(PROJECTNAME) ]; then rm $(PREFIX)/$(PROJECTNAME); fi
	# jdestroy
	@if [ -f $(PREFIX)/jdestroy ]; then rm $(PREFIX)/jdestroy; fi
	# jcreate.conf
	@if [ -f $(CONFPATH)/$(PROJECTNAME).conf ]; then rm $(CONFPATH)/$(PROJECTNAME).conf; fi
	# manpage
	@if [ -f $(MANPATH)/$(PROJECTNAME).7 ]; then rm $(MANPATH)/$(PROJECTNAME).7; fi

# vim: set noet set ff=unix
