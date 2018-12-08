CASK        ?= cask
EMACS       ?= emacs
DIST        ?= dist
EMACSFLAGS   = --batch -Q
EMACSBATCH   = $(EMACS) $(EMACSFLAGS)

VERSION     := $(shell EMACS=$(EMACS) $(CASK) version)
PKG_DIR     := $(shell EMACS=$(EMACS) $(CASK) package-directory)
PROJ_ROOT   := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

EMACS_D      = ~/.emacs.d
USER_ELPA_D  = $(EMACS_D)/elpa

SRCS         = $(filter-out %-pkg.el, $(wildcard *.el))
TESTS        = $(wildcard test/*.el)
ORG_MANUAL   = doc/org-pivotal.org
TEXI_MANUAL  = doc/org-pivotal.texi
TAR          = $(DIST)/org-pivotal-$(VERSION).tar
PACKAGE_EL   = "(progn (require 'package) \
					   (push '(\"melpa\" . \"http://melpa.org/packages/\") package-archives) \
					   (package-initialize))"

.PHONY: all check test unit ecukes lint install uninstall reinstall clean-all clean clean-elc

all : $(PKG_DIR) $(TAR)

install : $(TAR)
	$(EMACSBATCH) -l package -f package-initialize \
	--eval '(package-install-file "$(PROJ_ROOT)/$(TAR)")'

uninstall :
	rm -rf $(USER_ELPA_D)/skeletor-*

reinstall : clean uninstall install

clean-all : clean
	rm -rf $(PKG_DIR)

clean-elc :
	rm -f *.elc

clean : clean-elc
	rm -rf $(DIST)
	rm -f $(TEXI_MANUAL)
	rm -f *-pkg.el

$(PKG_DIR) : Cask
	$(CASK) install
	touch $(PKG_DIR)

$(TAR) : $(DIST) $(TEXI_MANUAL)
	$(CASK) package

$(DIST) :
	mkdir $(DIST)

$(TEXI_MANUAL) : $(PKG_DIR) $(ORG_MANUAL)
	$(CASK) exec $(EMACSBATCH) \
	-l org -l ox-texinfo \
	--file=$(ORG_MANUAL) -f org-texinfo-export-to-texinfo

check : test lint

test: unit

unit: $(PKG_DIR)
	${CASK} exec ert-runner

lint : $(SRCS) clean-elc
	# Byte compile all and stop on any warning or error
	${CASK} emacs $(EMACSFLAGS) \
	--eval "(setq byte-compile-error-on-warn t)" \
	-L . -f batch-byte-compile ${SRCS} ${TESTS}

	# Run package-lint to check for packaging mistakes
	${CASK} emacs $(EMACSFLAGS) \
	--eval $(PACKAGE_EL) \
	--eval '(package-refresh-contents)' \
	-l package-lint.el \
	-f package-lint-batch-and-exit ${SRCS}
