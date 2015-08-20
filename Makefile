#
# OpenSIPS makefile
#
# WARNING: requires gmake (GNU Make)
#  Arch supported: Linux, FreeBSD, SunOS (tested on Solaris 8), OpenBSD (3.2),
#  NetBSD (1.6).
#
#  History:
#  --------
#              created by andrei
#  2003-02-24  make install no longer overwrites opensips.cfg  - patch provided
#               by Maxim Sobolev   <sobomax@FreeBSD.org> and 
#                  Tomas Bjoerklund <tomas@webservices.se>
#  2003-03-11  PREFIX & LOCALBASE must also be exported (andrei)
#  2003-04-07  hacked to work with solaris install (andrei)
#  2003-04-17  exclude modules overwritable from env. or cmd. line,
#               added include_modules and skip_modules (andrei)
#  2003-05-30  added extra_defs & EXTRA_DEFS
#               Makefile.defs force-included to allow recursive make
#               calls -- see comment (andrei)
#  2003-06-02  make tar changes -- unpacks in $NAME-$RELEASE  (andrei)
#  2003-06-03  make install-cfg will properly replace the module path
#               in the cfg (re: /usr/.*lib/opensips/modules)
#              opensips.cfg.default is installed only if there is a previous
#               cfg. -- fixes packages containing opensips.cfg.default (andrei)
#  2003-08-29  install-modules-doc split from install-doc, added 
#               install-modules-all, removed README.cfg (andrei)
#              added skip_cfg_install (andrei)
#  2004-09-02  install-man will automatically "fix" the path of the files
#               referred in the man pages
#  2007-09-28  added db_berkeley (wiquan)
#

#FREERADIUS=1
# freeradius libs check (must be done in toplevel makefile)
ifneq ("$(wildcard /usr/include/freeradius-client.h)","")
FREERADIUS=1
else
#FREERADIUS=0
endif

NICER?=1
auto_gen=lex.yy.c cfg.tab.c   #lexx, yacc etc


# whether or not to install opensips.cfg or just opensips.cfg.default
# (opensips.cfg will never be overwritten by make install, this is useful
#  when creating packages)
skip_cfg_install?=

#extra modules to exclude
skip_modules?=

# whether or not to overwrite TLS certificates
tls_overwrite_certs?=


makefile_defs=0
DEFS:=
DEBUG_PARSER?=

# json libs check
ifneq ("$(wildcard /usr/include/json-c/json.h)","")
DEFS += -I/usr/include/json-c
else
DEFS += -I/usr/include/json
endif

# create the template only if the file is not yet created
ifeq (,$(wildcard Makefile.conf))
$(shell cp Makefile.conf.template Makefile.conf)
endif
include Makefile.conf
include Makefile.sources
include Makefile.defs

# always exclude the SVN dir
override exclude_modules+= .svn $(skip_modules)

#always include this modules
#include_modules?=

# first 2 lines are excluded because of the experimental or incomplete
# status of the modules
# the rest is excluded because it depends on external libraries
#
static_modules=
static_modules_path=$(addprefix modules/, $(static_modules))
extra_sources=$(wildcard $(addsuffix /*.c, $(static_modules_path)))
extra_objs=$(extra_sources:.c=.o)

static_defs=$(foreach mod, $(static_modules), \
		-DSTATIC_$(shell echo $(mod) | tr [:lower:] [:upper:]) )

override extra_defs+=$(static_defs) $(EXTRA_DEFS)
export extra_defs

# If modules is supplied, only do those. If not, use all modules when
# building documentation.
ifeq ($(modules),)
	doc_modules=$(all_modules)
else
	doc_modules=$(modules)
endif

# Take subset of all modules, excluding the exclude_modules and the
# static_modules.
modules=$(filter-out $(addprefix modules/, \
			$(exclude_modules) $(static_modules)), \
			$(wildcard modules/*))
# Let modules consist of modules and include_modules (but remove
# duplicates).
modules:=$(filter-out $(modules), $(addprefix modules/, $(include_modules) )) \
			$(modules)

ifneq ($(module),)
	modules:=$(addprefix modules/, $(module))
endif

modules_names=$(patsubst modules/%, %.so, $(modules))
modules_basenames=$(patsubst modules/%, %, $(modules))
modules_full_path=$(join $(modules), $(addprefix /, $(modules_names)))

doc_modules_basenames=$(patsubst modules/%, %, $(patsubst net/%, %, $(doc_modules)))

ALLDEP=Makefile Makefile.sources Makefile.defs Makefile.rules Makefile.conf


install_docs := README-MODULES AUTHORS NEWS README
ifneq ($(skip-install-doc),yes)
	install_docs += INSTALL
endif

#include general defs (like CC, CFLAGS  a.s.o)
# hack to force makefile.defs re-inclusion (needed when make calls itself with
# other options -- e.g. make bin)
#DEFS:=
#include Makefile.defs

NAME=$(MAIN_NAME)

#export relevant variables to the sub-makes
export DEFS PROFILE CC LD MKDEP MKTAGS CFLAGS LDFLAGS MOD_CFLAGS MOD_LDFLAGS 
export LIBS RADIUS_LIB
export LEX YACC YACC_FLAGS
export PREFIX LOCALBASE SYSBASE
# export relevant variables for recursive calls of this makefile 
# (e.g. make deb)
#export LIBS
#export TAR 
export NAME RELEASE OS ARCH 
export cfg-prefix cfg-dir bin-prefix bin-dir modules-prefix modules-dir
export doc-prefix doc-dir man-prefix man-dir ut-prefix ut-dir lib-dir
export cfg-target modules-target data-dir data-prefix data-target
export INSTALL INSTALL_CFG INSTALL_BIN INSTALL_MODULES INSTALL_DOC INSTALL_MAN 
export INSTALL_TOUCH

# extra excludes for tar
tar_extra_args+=

# include the common rules
include Makefile.rules

#extra targets 

$(NAME): $(extra_objs) # static_modules

lex.yy.c: cfg.lex cfg.tab.h $(ALLDEP)
	$(LEX) $<

cfg.tab.c cfg.tab.h: cfg.y  $(ALLDEP)
	$(YACC) $(YACC_FLAGS) $<

.PHONY: all
all: $(NAME) modules utils

.PHONY: app
app: $(NAME)


.PHONY: _modules
_modules: $(modules)

.PHONY: $(modules)
$(modules):
	@$(MAKE) --no-print-directory -C $@ && \
		echo "Building $(notdir $@) module succeeded" || (\
			status=$$?; \
			echo "ERROR: Building $(notdir $@) module failed!"; \
			exit $$status; \
		)

.PHONY: modules
modules:
ifeq (,$(FASTER))
	@set -e; \
	for r in $(modules) "" ; do \
		if [ -n "$$r" ]; then \
			if [ -d "$$r" ]; then \
				echo  "" ; \
				echo  "" ; \
				$(MAKE) -j -C $$r ; \
			fi ; \
		fi ; \
	done
else
	@$(MAKE) _modules || ( \
		status=$$?; \
		if echo $(MAKEFLAGS) | grep -q -- --jobserver; then \
			printf '\nBuilding one or more modules failed!\n'; \
			printf 'Please re-run make without -j / --jobs to find out which.\n\n'; \
		fi; \
		exit $$status \
	)
endif


.PHONY: tool-docbook2pdf
tool-docbook2pdf:
	@if [ -z "$(DBXML2PDF)" ]; then \
		echo "error: docbook2pdf not found"; exit 1; \
	fi

.PHONY: tool-lynx
tool-lynx:
	@if [ -z "$(DBHTML2TXT)" ]; then \
		echo "error: lynx not found"; exit 1; \
	fi

.PHONY: tool-xsltproc
tool-xsltproc:
	@if [ -z "$(DBXML2HTML)" ]; then \
		echo "error: xsltproc not found"; exit 1; \
	fi
	@if [ -z "$(DBHTMLXSL)" ]; then \
		echo "error: docbook.xsl not found (docbook-xsl)"; exit 1; \
	fi

.PHONY: modules-readme
modules-readme: tool-lynx tool-xsltproc
	@set -e; \
	for r in $(doc_modules_basenames) ""; do \
		if [ ! -d "modules/$$r/doc" -a ! -d "net/$$r/doc" ]; then \
			continue; \
		fi; \
		if [ -d "modules/$$r/doc" ]; then \
			cd "modules/$$r/doc"; \
		elif [ -d "net/$$r/doc" ]; then \
			cd "net/$$r/doc"; \
		fi; \
		\
		if [ -f "$$r".xml ]; then \
			echo ""; \
			echo "docbook xml to html: $$r.xml"; \
			$(DBXML2HTML) -o $$r.html $(DBXML2HTMLPARAMS) $(DBHTMLXSL) \
						$$r.xml; \
			echo "docbook html to txt: $$r.html"; \
			$(DBHTML2TXT) $(DBHTML2TXTPARAMS) $$r.html >$$r.txt; \
			echo "docbook txt to readme: $$r.txt"; \
			rm $$r.html; \
			mv $$r.txt ../README; \
			echo ""; \
		fi; \
		cd ../../..; \
	done

.PHONY: modules-docbook-txt
modules-docbook-txt: tool-lynx tool-xsltproc
	@set -e; \
	for r in $(doc_modules_basenames) ""; do \
		if [ ! -d "modules/$$r/doc" -a ! -d "net/$$r/doc" ]; then \
			continue; \
		fi; \
		if [ -d "modules/$$r/doc" ]; then \
			cd "modules/$$r/doc"; \
		elif [ -d "net/$$r/doc" ]; then \
			cd "net/$$r/doc"; \
		fi; \
		\
		if [ -f "$$r".xml ]; then \
			echo ""; \
			echo "docbook xml to html: $$r.xml"; \
			$(DBXML2HTML) -o $$r.html $(DBXML2HTMLPARAMS) $(DBHTMLXSL) \
						$$r.xml; \
			echo "docbook html to txt: $$r.html"; \
			$(DBHTML2TXT) $(DBHTML2TXTPARAMS) $$r.html >$$r.txt; \
			rm $$r.html; \
			echo ""; \
		fi; \
		cd ../../..; \
	done

.PHONY: modules-docbook-html
modules-docbook-html: tool-xsltproc
	@set -e; \
	for r in $(doc_modules_basenames) ""; do \
		if [ ! -d "modules/$$r/doc" -a ! -d "net/$$r/doc" ]; then \
			continue; \
		fi; \
		if [ -d "modules/$$r/doc" ]; then \
			cd "modules/$$r/doc"; \
		elif [ -d "net/$$r/doc" ]; then \
			cd "net/$$r/doc"; \
		fi; \
		\
		if [ -f "$$r".xml ]; then \
			echo ""; \
			echo "docbook xml to html: $$r.xml"; \
			$(DBXML2HTML) -o $$r.html $(DBXML2HTMLPARAMS) $(DBHTMLXSL) \
						$$r.xml; \
			echo ""; \
		fi; \
		cd ../../..; \
	done

.PHONY: modules-docbook-pdf
modules-docbook-pdf: tool-docbook2pdf
	@set -e; \
	for r in $(doc_modules_basenames) ""; do \
		if [ ! -d "modules/$$r/doc" -a ! -d "net/$$r/doc" ]; then \
			continue; \
		fi; \
		if [ -d "modules/$$r/doc" ]; then \
			cd "modules/$$r/doc"; \
		elif [ -d "net/$$r/doc" ]; then \
			cd "net/$$r/doc"; \
		fi; \
		if [ -f "$$r".xml ]; then \
			echo ""; \
			echo "docbook xml to pdf: $$r.xml"; \
			$(DBXML2PDF) "$$r".xml; \
		fi; \
		cd ../../..; \
	done

.PHONY: modules-docbook
modules-docbook: modules-docbook-txt modules-docbook-html modules-docbook-pdf

.PHONY: dbschema-docbook-txt
dbschema-docbook-txt: dbschema
	@set -e; \
	for r in $(wildcard doc/database/*.sgml) "" ; do \
		if [ -f "$$r" ]; then \
			echo  "" ; \
			echo  "docbook2txt $$r" ; \
			docbook2txt -o "doc/database/" "$$r" ; \
		fi ; \
	done

.PHONY: dbschema-docbook-html
dbschema-docbook-html: dbschema
	@set -e; \
	for r in $(wildcard doc/database/*.sgml) "" ; do \
		if [ -f "$$r" ]; then \
			echo  "" ; \
			echo  "docbook2html $$r" ; \
			docbook2html --nochunks -o "doc/database/" "$$r" ; \
		fi ; \
	done

.PHONY: dbschema-docbook-pdf
dbschema-docbook-pdf: dbschema
	@set -e; \
	for r in $(wildcard doc/database/*.sgml) "" ; do \
		if [ -f "$$r" ]; then \
			echo  "" ; \
			echo  "docbook2pdf $$r" ; \
			docbook2pdf -o "doc/database/" "$$r" ; \
		fi ; \
	done

.PHONY: dbschema-docbook
dbschema-docbook: dbschema-docbook-txt dbschema-docbook-html dbschema-docbook-pdf


$(extra_objs):
	-@echo "Extra objs: $(extra_objs)" 
	@set -e; \
	for r in $(static_modules_path) "" ; do \
		if [ -n "$$r" ]; then \
			echo  "" ; \
			echo  "Making static module $r" ; \
			$(MAKE) -C $$r static ; \
		fi ; \
	done 


	
dbg: $(NAME)
	gdb -command debug.gdb

.PHONY: tar
.PHONY: dist

dist: tar

tar: $(NEWREVISION)
	$(TAR) -C .. \
		--exclude=$(notdir $(CURDIR))/tmp* \
		--exclude=$(notdir $(CURDIR))/debian* \
		--exclude=.svn* \
		--exclude=.git \
		--exclude=.gitignore \
		--exclude=Makefile.conf \
		--exclude=*.[do] \
		--exclude=*.so \
		--exclude=*.il \
		--exclude=$(notdir $(CURDIR))/$(NAME) \
		--exclude=*.gz \
		--exclude=*.bz2 \
		--exclude=*.tar \
		--exclude=*.patch \
		--exclude=.\#* \
		--exclude=*.swp \
		--exclude=*~ \
		${tar_extra_args} \
		-cf - $(notdir $(CURDIR)) | \
			(mkdir -p tmp/_tar1; mkdir -p tmp/_tar2 ; \
			    cd tmp/_tar1; $(TAR) -xf - ) && \
			    mv tmp/_tar1/$(notdir $(CURDIR)) \
			       tmp/_tar2/"$(NAME)-$(RELEASE)" && \
			    (cd tmp/_tar2 && $(TAR) \
			                    -zcf ../../"$(NAME)-$(RELEASE)_src".tar.gz \
			                               "$(NAME)-$(RELEASE)" ) ; \
			    rm -rf tmp/_tar1; rm -rf tmp/_tar2

# binary dist. tar.gz
.PHONY: bin
bin:
	mkdir -p tmp/$(NAME)/usr/local
	$(MAKE) install basedir=tmp/$(NAME) prefix=/usr/local 
	$(TAR) -C tmp/$(NAME)/ -zcf ../$(NAME)-$(RELEASE)_$(OS)_$(ARCH).tar.gz .
	rm -rf tmp/$(NAME)

.PHONY: deb-orig-tar
deb-orig-tar:
	tar_extra_args=--exclude=packaging make tar
	mv "$(NAME)-$(RELEASE)_src".tar.gz ../$(NAME)_$(RELEASE).orig.tar.gz

.PHONY: deb
deb:
	rm -rf debian
	# dpkg-source cannot use links for debian source
	cp -r packaging/debian debian
	dpkg-buildpackage \
		-I.git -I.gitignore \
		-IMakefile.conf \
		-I*.swp -I*~ \
		-i\\.git\|Makefile\\.conf\|packaging\|debian\|^\\.\\w+\\.swp\|lex\\.yy\\.c\|cfg\\.tab\\.\(c\|h\) \
		-rfakeroot -tc $(DEBBUILD_EXTRA_OPTIONS)
	rm -rf debian


.PHONY: sunpkg
sunpkg:
	mkdir -p tmp/$(NAME)
	mkdir -p tmp/$(NAME)_sun_pkg
	$(MAKE) install basedir=tmp/$(NAME) prefix=/usr/local
	(cd packaging/solaris; \
	pkgmk -r ../../tmp/$(NAME)/usr/local -o -d ../../tmp/$(NAME)_sun_pkg/ -v "$(RELEASE)" ;\
	cd ../..)
	cat /dev/null > ../$(NAME)-$(RELEASE)-$(OS)-$(ARCH)-local
	pkgtrans -s tmp/$(NAME)_sun_pkg/ ../$(NAME)-$(RELEASE)-$(OS)-$(ARCH)-local \
		OpenSIPS
	gzip -9 ../$(NAME)-$(RELEASE)-$(OS)-$(ARCH)-local
	rm -rf tmp/$(NAME)
	rm -rf tmp/$(NAME)_sun_pkg


.PHONY: install-app install-modules-all install
# Install app only, excluding console, modules and module docs
install-app: app mk-install-dirs install-cfg opensipsmc install-bin \
	install-app-doc install-man

# Install all module stuff (except modules-docbook?)
install-modules-all: install-modules install-modules-doc

# Install everything (except modules-docbook?)
install: install-app install-console install-modules-all

opensipsmc: $(cfg-prefix)/$(cfg-dir) $(data-prefix)/$(data-dir)
	$(MAKE) -C menuconfig proper
	$(MAKE) -C menuconfig \
		MENUCONFIG_CFG_PATH=$(data-target)/menuconfig_templates/ \
		MENUCONFIG_GEN_PATH=$(cfg-target) MENUCONFIG_HAVE_SOURCES=0
	mkdir -p $(data-prefix)/$(data-dir)/menuconfig_templates/
	$(INSTALL_TOUCH) menuconfig/configs/* $(data-prefix)/$(data-dir)/menuconfig_templates/
	$(INSTALL_CFG) menuconfig/configs/* $(data-prefix)/$(data-dir)/menuconfig_templates/
	sed -i -e "s#/usr/.*lib/$(NAME)/modules/#$(modules-target)#" \
		$(data-prefix)/$(data-dir)/menuconfig_templates/*

.PHONY: dbschema
dbschema:
	-@echo "Build database schemas"
	$(MAKE) -C db/schema
	-@echo "Done"

mk-install-dirs: $(cfg-prefix)/$(cfg-dir) $(bin-prefix)/$(bin-dir) \
			$(modules-prefix)/$(modules-dir) $(doc-prefix)/$(doc-dir) \
			$(man-prefix)/$(man-dir)/man8 $(man-prefix)/$(man-dir)/man5 \
			$(data-prefix)/$(data-dir)

		
# note: on solaris 8 sed: ? or \(...\)* (a.s.o) do not work
install-cfg: $(cfg-prefix)/$(cfg-dir)
		sed -e "s#/usr/.*lib/$(NAME)/modules/#$(modules-target)#g" \
			< etc/$(NAME).cfg > $(cfg-prefix)/$(cfg-dir)$(NAME).cfg.sample0
		sed -e "s#/usr/.*etc/$(NAME)/tls/#$(cfg-target)tls/#g" \
			< $(cfg-prefix)/$(cfg-dir)$(NAME).cfg.sample0 \
			> $(cfg-prefix)/$(cfg-dir)$(NAME).cfg.sample
		rm -fr $(cfg-prefix)/$(cfg-dir)$(NAME).cfg.sample0
		chmod 600 $(cfg-prefix)/$(cfg-dir)$(NAME).cfg.sample
		chmod 700 $(cfg-prefix)/$(cfg-dir)
		if [ -z "${skip_cfg_install}" -a \
				! -f $(cfg-prefix)/$(cfg-dir)$(NAME).cfg ]; then \
			mv -f $(cfg-prefix)/$(cfg-dir)$(NAME).cfg.sample \
				$(cfg-prefix)/$(cfg-dir)$(NAME).cfg; \
		fi
		# opensipsctl config
		$(INSTALL_TOUCH)   $(cfg-prefix)/$(cfg-dir)/opensipsctlrc.sample
		$(INSTALL_CFG) scripts/opensipsctlrc \
			$(cfg-prefix)/$(cfg-dir)/opensipsctlrc.sample
		if [ ! -f $(cfg-prefix)/$(cfg-dir)/opensipsctlrc ]; then \
			mv -f $(cfg-prefix)/$(cfg-dir)/opensipsctlrc.sample \
				$(cfg-prefix)/$(cfg-dir)/opensipsctlrc; \
		fi
		# osipsconsole config
		$(INSTALL_TOUCH)   $(cfg-prefix)/$(cfg-dir)/osipsconsolerc.sample
		$(INSTALL_CFG) scripts/osipsconsolerc \
			$(cfg-prefix)/$(cfg-dir)/osipsconsolerc.sample
		if [ ! -f $(cfg-prefix)/$(cfg-dir)/osipsconsolerc ]; then \
			mv -f $(cfg-prefix)/$(cfg-dir)/osipsconsolerc.sample \
				$(cfg-prefix)/$(cfg-dir)/osipsconsolerc; \
		fi

install-console: $(bin-prefix)/$(bin-dir)
		# install osipsconsole
		cat scripts/osipsconsole | \
		sed -e "s#PATH_BIN[ \t]*=[ \t]*\"\./\"#PATH_BIN = \"$(bin-target)\"#g" | \
		sed -e "s#PATH_CTLRC[ \t]*=[ \t]*\"\./scripts/\"#PATH_CTLRC = \"$(cfg-target)\"#g" | \
		sed -e "s#PATH_LIBS[ \t]*=[ \t]*\"\./scripts/\"#PATH_LIBS = \"$(lib-target)/opensipsctl/\"#g" | \
		sed -e "s#PATH_SHARE[ \t]*=[ \t]*\"\./scripts/\"#PATH_SHARE = \"$(data-target)\"#g" | \
		sed -e "s#PATH_ETC[ \t]*=[ \t]*\"\./etc/\"#PATH_ETC = \"$(cfg-target)\"#g" \
		> /tmp/osipsconsole
		$(INSTALL_TOUCH) $(bin-prefix)/$(bin-dir)/osipsconsole
		$(INSTALL_BIN) /tmp/osipsconsole $(bin-prefix)/$(bin-dir)
		rm -fr /tmp/osipsconsole

install-bin: $(bin-prefix)/$(bin-dir) utils
		# install opensips binary
		$(INSTALL_TOUCH) $(bin-prefix)/$(bin-dir)/$(NAME) 
		$(INSTALL_BIN) $(NAME) $(bin-prefix)/$(bin-dir)
		# install opensips menuconfig
		$(INSTALL_TOUCH) $(bin-prefix)/$(bin-dir)/osipsconfig
		$(INSTALL_BIN) menuconfig/configure $(bin-prefix)/$(bin-dir)/osipsconfig
		# install opensipsctl (and family) tool
		cat scripts/opensipsctl | \
		sed -e "s#/usr/local/sbin#$(bin-target)#g" | \
		sed -e "s#/usr/local/lib/opensips#$(lib-target)#g" | \
		sed -e "s#/usr/local/etc/opensips#$(cfg-target)#g"  >/tmp/opensipsctl
		$(INSTALL_TOUCH) $(bin-prefix)/$(bin-dir)/opensipsctl
		$(INSTALL_BIN) /tmp/opensipsctl $(bin-prefix)/$(bin-dir)
		rm -fr /tmp/opensipsctl
		sed -e "s#/usr/local/sbin#$(bin-target)#g" \
			< scripts/opensipsctl.base > /tmp/opensipsctl.base
		mkdir -p $(modules-prefix)/$(lib-dir)/opensipsctl 
		$(INSTALL_TOUCH) \
			$(modules-prefix)/$(lib-dir)/opensipsctl
		$(INSTALL_CFG) /tmp/opensipsctl.base \
			$(modules-prefix)/$(lib-dir)/opensipsctl/opensipsctl.base
		rm -fr /tmp/opensipsctl.base
		sed -e "s#/usr/local#$(bin-target)#g" \
			< scripts/opensipsctl.ctlbase > /tmp/opensipsctl.ctlbase
		$(INSTALL_CFG) /tmp/opensipsctl.ctlbase \
			$(modules-prefix)/$(lib-dir)/opensipsctl/opensipsctl.ctlbase
		rm -fr /tmp/opensipsctl.ctlbase
		sed -e "s#/usr/local#$(bin-target)#g" \
			< scripts/opensipsctl.fifo > /tmp/opensipsctl.fifo
		$(INSTALL_CFG) /tmp/opensipsctl.fifo \
			$(modules-prefix)/$(lib-dir)/opensipsctl/opensipsctl.fifo
		rm -fr /tmp/opensipsctl.fifo
		sed -e "s#/usr/local#$(bin-target)#g" \
			< scripts/opensipsctl.unixsock > /tmp/opensipsctl.unixsock
		$(INSTALL_CFG) /tmp/opensipsctl.unixsock \
			$(modules-prefix)/$(lib-dir)/opensipsctl/opensipsctl.unixsock
		rm -fr /tmp/opensipsctl.unixsock
		sed -e "s#/usr/local#$(bin-target)#g" \
			< scripts/opensipsctl.sqlbase > /tmp/opensipsctl.sqlbase
		$(INSTALL_CFG) /tmp/opensipsctl.sqlbase \
			$(modules-prefix)/$(lib-dir)/opensipsctl/opensipsctl.sqlbase
		rm -fr /tmp/opensipsctl.sqlbase
		# install db setup base script
		sed -e "s#/usr/local/sbin#$(bin-target)#g" \
			-e "s#/usr/local/etc/opensips#$(cfg-target)#g" \
			-e "s#/usr/local/share/opensips#$(data-target)#g" \
			< scripts/opensipsdbctl.base > /tmp/opensipsdbctl.base
		$(INSTALL_CFG) /tmp/opensipsdbctl.base \
			$(modules-prefix)/$(lib-dir)/opensipsctl/opensipsdbctl.base
		rm -fr /tmp/opensipsdbctl.base
		cat scripts/opensipsdbctl | \
		sed -e "s#/usr/local/sbin#$(bin-target)#g" | \
		sed -e "s#/usr/local/lib/opensips#$(lib-target)#g" | \
		sed -e "s#/usr/local/etc/opensips#$(cfg-target)#g"  >/tmp/opensipsdbctl
		$(INSTALL_TOUCH) $(bin-prefix)/$(bin-dir)/opensipsdbctl
		$(INSTALL_BIN) /tmp/opensipsdbctl $(bin-prefix)/$(bin-dir)
		rm -fr /tmp/opensipsdbctl
		$(INSTALL_TOUCH)   $(bin-prefix)/$(bin-dir)/$(NAME)unix
		$(INSTALL_BIN) utils/$(NAME)unix/$(NAME)unix $(bin-prefix)/$(bin-dir)

.PHONY: utils
utils:
		cd utils/$(NAME)unix; $(MAKE) all
		if [ "$(BERKELEYDBON)" = "yes" ]; then \
			cd utils/db_berkeley; $(MAKE) all ; \
		fi ;
		if [ "$(ORACLEON)" = "yes" ]; then \
			cd utils/db_oracle; $(MAKE) all ; \
		fi ;

install-modules: modules $(modules-prefix)/$(modules-dir)
	@for r in $(modules_full_path) "" ; do \
		if [ -n "$$r" ]; then \
			if [ -f "$$r" ]; then \
				$(INSTALL_TOUCH) \
					$(modules-prefix)/$(modules-dir)/`basename "$$r"` ; \
				$(INSTALL_MODULES)  "$$r"  $(modules-prefix)/$(modules-dir) ; \
				$(MAKE) -C `dirname "$$r"` install_module_custom ; \
			else \
				echo "ERROR: module $$r not compiled" ; \
			fi ;\
		fi ; \
	done 


.PHONY: install-doc install-app-doc install-modules-doc
install-doc: install-app-doc install-modules-doc

install-app-doc: $(doc-prefix)/$(doc-dir)
	-@for d in $(install_docs) ""; do \
		$(INSTALL_TOUCH) $(doc-prefix)/$(doc-dir)/"$$d" ; \
		$(INSTALL_DOC) "$$d" $(doc-prefix)/$(doc-dir) ; \
	done


install-modules-doc: $(doc-prefix)/$(doc-dir)
	-@for r in $(modules_basenames) "" ; do \
		if [ -n "$$r" ]; then \
			if [ -f modules/"$$r"/README ]; then \
				$(INSTALL_TOUCH)  $(doc-prefix)/$(doc-dir)/README."$$r" ; \
				$(INSTALL_DOC)  modules/"$$r"/README  \
									$(doc-prefix)/$(doc-dir)/README."$$r" ; \
			fi ; \
		fi ; \
	done 


install-man: $(man-prefix)/$(man-dir)/man8 $(man-prefix)/$(man-dir)/man5
		sed -e "s#/etc/$(NAME)/$(NAME)\.cfg#$(cfg-target)$(NAME).cfg#g" \
			-e "s#/usr/sbin/#$(bin-target)#g" \
			-e "s#/usr/lib/$(NAME)/modules/#$(modules-target)#g" \
			-e "s#/usr/share/doc/$(NAME)/#$(doc-target)#g" \
			< $(NAME).8 >  $(man-prefix)/$(man-dir)/man8/$(NAME).8
		chmod 644  $(man-prefix)/$(man-dir)/man8/$(NAME).8
		sed -e "s#/etc/$(NAME)/$(NAME)\.cfg#$(cfg-target)$(NAME).cfg#g" \
			-e "s#/usr/sbin/#$(bin-target)#g" \
			-e "s#/usr/lib/$(NAME)/modules/#$(modules-target)#g" \
			-e "s#/usr/share/doc/$(NAME)/#$(doc-target)#g" \
			< $(NAME).cfg.5 >  $(man-prefix)/$(man-dir)/man5/$(NAME).cfg.5
		chmod 644  $(man-prefix)/$(man-dir)/man5/$(NAME).cfg.5
		sed -e "s#/etc/$(NAME)/$(NAME)\.cfg#$(cfg-target)$(NAME).cfg#g" \
			-e "s#/usr/sbin/#$(bin-target)#g" \
			-e "s#/usr/lib/$(NAME)/modules/#$(modules-target)#g" \
			-e "s#/usr/share/doc/$(NAME)/#$(doc-target)#g" \
			< scripts/opensipsctl.8 > $(man-prefix)/$(man-dir)/man8/opensipsctl.8
		chmod 644  $(man-prefix)/$(man-dir)/man8/opensipsctl.8
		sed -e "s#/etc/$(NAME)/$(NAME)\.cfg#$(cfg-target)$(NAME).cfg#g" \
			-e "s#/usr/sbin/#$(bin-target)#g" \
			-e "s#/usr/lib/$(NAME)/modules/#$(modules-target)#g" \
			-e "s#/usr/share/doc/$(NAME)/#$(doc-target)#g" \
			< utils/opensipsunix/opensipsunix.8 > \
			$(man-prefix)/$(man-dir)/man8/opensipsunix.8
		chmod 644  $(man-prefix)/$(man-dir)/man8/opensipsunix.8

install-modules-docbook: $(doc-prefix)/$(doc-dir)
	-@for r in $(modules_basenames) "" ; do \
		if [ -n "$$r" ]; then \
			if [ -d modules/"$$r"/doc ]; then \
				if [ -f modules/"$$r"/doc/"$$r".txt ]; then \
					$(INSTALL_TOUCH)  $(doc-prefix)/$(doc-dir)/"$$r".txt ; \
					$(INSTALL_DOC)  modules/"$$r"/doc/"$$r".txt  \
									$(doc-prefix)/$(doc-dir)/"$$r".txt ; \
				fi ; \
				if [ -f modules/"$$r"/doc/"$$r".html ]; then \
					$(INSTALL_TOUCH)  $(doc-prefix)/$(doc-dir)/"$$r".html ; \
					$(INSTALL_DOC)  modules/"$$r"/doc/"$$r".html  \
									$(doc-prefix)/$(doc-dir)/"$$r".html ; \
				fi ; \
				if [ -f modules/"$$r"/doc/"$$r".pdf ]; then \
					$(INSTALL_TOUCH)  $(doc-prefix)/$(doc-dir)/"$$r".pdf ; \
					$(INSTALL_DOC)  modules/"$$r"/doc/"$$r".pdf  \
									$(doc-prefix)/$(doc-dir)/"$$r".pdf ; \
				fi ; \
			fi ; \
		fi ; \
	done

.PHONY: test
test:
	-@echo "Start tests"
	$(MAKE) -C test/
	-@echo "Tests finished"

doxygen:
	-@echo "Create Doxygen documentation"
	# disable call graphes, because of the DOT dependencies
	(cat doc/doxygen/opensips-doxygen; \
	echo "HAVE_DOT=no" ;\
	echo "PROJECT_NUMBER=$(NAME)-$(RELEASE)" )| doxygen -
	-@echo "Doxygen documentation created"

comp_menuconfig:
	$(MAKE) -C menuconfig
menuconfig: comp_menuconfig
	./menuconfig/configure --local
