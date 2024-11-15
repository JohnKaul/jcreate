# ==============================================================
# tool setup
# ==============================================================
#
CC      =	chmod
# processor
CFLAGS  =	+x
# processor flags

SED		:=	sed
CP		:=	cp
ECHO	:=	echo
RM		:=	rm

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
	@$(ECHO) "Processing..."
	$(CC) $(CFLAGS) $(SOURCES)

install:
	@$(ECHO) "Installing $(PROJECTNAME) to: $(PREFIX)"
	@$(SED) 's,/usr/local/etc/,$(CONFPATH),g' $(SRCDIR)/jdestroy.sh > $(PREFIX)/jdestroy
	@$(CC) $(CFLAGS) $(PREFIX)/jdestroy
	@$(CP) $(SRCDIR)/$(PROJECTNAME).conf $(CONFPATH)/$(PROJECTNAME).conf
	@$(SED) 's,/usr/local/etc/,$(CONFPATH),g' $(SRCDIR)/$(PROJECTNAME).sh > $(PREFIX)/$(PROJECTNAME)
	@$(CC) $(CFLAGS) $(PREFIX)/$(PROJECTNAME)
	@$(SED) -e 's,/usr/local/etc/,$(CONFPATH),g' -e 's,/usr/local/bin/,$(PREFIX),g' $(DOCDIR)/jcreate.7 > $(MANPATH)/$(PROJECTNAME).7
	@chmod 644 $(MANPATH)/jcreate.7

uninstall: remove
remove:
	@$(ECHO) "Uninstalling $(PROJECTNAME) from: $(PREFIX)"
	# jcreate
	@if [ -f $(PREFIX)/$(PROJECTNAME) ]; then $(RM) $(PREFIX)/$(PROJECTNAME); fi
	# jdestroy
	@if [ -f $(PREFIX)/jdestroy ]; then $(RM) $(PREFIX)/jdestroy; fi
	# jcreate.conf
	@if [ -f $(CONFPATH)/$(PROJECTNAME).conf ]; then $(RM) $(CONFPATH)/$(PROJECTNAME).conf; fi
	# manpage
	@if [ -f $(MANPATH)/$(PROJECTNAME).7 ]; then $(RM) $(MANPATH)/$(PROJECTNAME).7; fi

# vim: set noet set ff=unix
