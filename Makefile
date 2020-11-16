# Giraffe Library application sample Makefile
#
# Copyright 2015-2020 Phil Clayton <phil.clayton@veonix.com>
#
# This file is part of the Giraffe Library runtime.  For your rights to use
# this file, see the file 'LICENCE.RUNTIME' distributed with Giraffe Library
# or visit <http://www.giraffelibrary.org/licence-runtime.html>.



################################################################################
# Configuration
#

SHELL=/bin/bash

ifndef GIRAFFEHOME
GIRAFFEHOME := /opt/giraffe
GIRAFFEHOMEDEFAULT := $() default
endif

ifndef GIRAFFEDEBUG
GIRAFFEDEBUG := yes
endif

-include $(GIRAFFEHOME)/config.mk

ifneq ($(PREFIX),$(GIRAFFEHOME))
$(info Configuration file "config.mk" not found in $$GIRAFFEHOME or contents missing.)
$(info Using$(GIRAFFEHOMEDEFAULT) GIRAFFEHOME = "$(GIRAFFEHOME)".)
$(info Expected configuration file is "$(GIRAFFEHOME)/config.mk".)
$(info )
$(info Set GIRAFFEHOME to Giraffe Library installation directory, e.g.)
$(info $()  export GIRAFFEHOME="/opt/giraffe")
$(info )
$(error Giraffe Library installation directory not found)
endif

ifndef KERNEL_NAME
KERNEL_NAME := $(shell uname -s)
endif

ifeq ($(KERNEL_NAME),Darwin)
LIB := dylib
else
LIB := so
endif

GIRAFFE_SML_LIBDIR := $(GIRAFFEHOME)/lib/sml



################################################################################
# Application-specific values
#

include app.mk

ifdef MLTON_VERSION
ifeq ($(SRC_MLTON),)
$(error SRC_MLTON not set in file "app.mk")
endif
ifeq ($(TARGET_MLTON),)
$(error TARGET_MLTON not set in file "app.mk")
endif
endif

ifdef POLYML_VERSION
ifeq ($(SRC_POLYML),)
$(error SRC_POLYML not set in file "app.mk")
endif
ifeq ($(TARGET_POLYML),)
$(error TARGET_POLYML not set in file "app.mk")
endif
endif


################################################################################
# Make options
#

default :
	@echo "Giraffe Library settings:"
	@echo "  Home directory       $(GIRAFFEHOME)"
	@echo "  Debugging support    $(GIRAFFEDEBUG)"
	@echo
	@echo "Standard ML compilers:"
ifdef MLTON_VERSION
	@echo "  MLton                $(MLTON_VERSION)"
else
	@echo "  MLton                not available"
endif
ifdef POLYML_VERSION
	@echo "  Poly/ML              $(POLYML_VERSION)"
else
	@echo "  Poly/ML              not available"
endif
	@echo
	@echo "Makefile usage:"
ifdef MLTON_VERSION
	@echo "  make mlton         - make MLton binary '$(TARGET_MLTON)'"
endif
ifdef POLYML_VERSION
	@echo "  make polyml        - make Poly/ML binary '$(TARGET_POLYML)'"
endif
	@echo "  make clean         - clean up intermediate files"
	@echo "  make distclean     - clean up all files"
	@echo



################################################################################
# Building
#

# Determine the pkg-config dependencies

PKG_NAMES := \
  $(strip \
    $(foreach LIB_NAME,$(LIB_NAMES), \
      $(foreach FILE,$(wildcard $(GIRAFFE_SML_LIBDIR)/$(LIB_NAME)/package), \
        $(shell cat $(FILE)) \
      ) \
    ) \
  )


# MLton

ifdef MLTON_VERSION

GIRAFFE_MLTON_LIBDIR := $(GIRAFFEHOME)/lib/mlton
GIRAFFE_MLTON_LIB_NAMES := \
	$(addprefix giraffe-,$(filter $(MLTON_LIB_NAMES),$(LIB_NAMES)))

ifeq ($(GIRAFFEDEBUG),yes)
MLTONDEBUG := true
else ifeq ($(GIRAFFEDEBUG),no)
MLTONDEBUG := false
else
  $(error GIRAFFEDEBUG must be set to 'yes' or 'no')
endif

GIRAFFE_MLTON_LIB_LDFLAGS := $(addprefix -l,$(GIRAFFE_MLTON_LIB_NAMES))

$(TARGET_MLTON) : $(SRC_MLTON)
	$(MLTON_MLTON) \
	 -keep g \
	 -mlb-path-var 'GIRAFFE_SML_LIB $(GIRAFFE_SML_LIBDIR)' \
	 -output $(TARGET_MLTON) \
	 -const 'GiraffeDebug.isEnabled $(MLTONDEBUG)' \
	 -const 'Exn.keepHistory true' \
	 -cc-opt "-ggdb -std=c99 -O2" \
	 -link-opt "`pkg-config --libs $(PKG_NAMES)` -L$(GIRAFFE_MLTON_LIBDIR) $(GIRAFFE_MLTON_LIB_LDFLAGS)" \
	 mlton.mlb


.PHONY : mlton

mlton : $(TARGET_MLTON)

endif # MLTON_VERSION


# Poly/ML

ifdef POLYML_VERSION

GIRAFFE_POLYML_LIBDIR := $(GIRAFFEHOME)/lib/polyml
GIRAFFE_POLYML_LIB_NAMES := \
	$(addprefix giraffe-,$(filter $(POLYML_LIB_NAMES),$(LIB_NAMES)))

ifeq ($(GIRAFFEDEBUG),yes)
POLYMLDEBUG := 1
else ifeq ($(GIRAFFEDEBUG),no)
POLYMLDEBUG :=
else
  $(error GIRAFFEDEBUG must be set to 'yes' or 'no')
endif

polyml-export.sml :
	echo "PolyML.export (\"$(TARGET_POLYML).o\", main);" > $@

polyml-libs.state :
	LD_LIBRARY_PATH=$(GIRAFFE_POLYML_LIBDIR):$(POLYML_LIBDIR):$(LD_LIBRARY_PATH) \
	 GIRAFFE_SML_LIB=$(GIRAFFE_SML_LIBDIR) \
	 GIRAFFE_DEBUG=$(POLYMLDEBUG) \
	 $(POLYML_POLY) --use make-polyml-libs.sml -q

$(TARGET_POLYML).o : polyml-libs.state polyml-export.sml $(SRC_POLYML)
	LD_LIBRARY_PATH=$(GIRAFFE_POLYML_LIBDIR):$(POLYML_LIBDIR):$(LD_LIBRARY_PATH) \
	 GIRAFFE_SML_LIB=$(GIRAFFE_SML_LIBDIR) \
	 GIRAFFE_DEBUG=$(POLYMLDEBUG) \
	 $(POLYML_POLY) --use make-polyml-app.sml -q

GIRAFFE_POLYML_LIB_LDFLAGS := $(addprefix -l,$(GIRAFFE_POLYML_LIB_NAMES))

$(TARGET_POLYML) : $(TARGET_POLYML).o
ifeq ($(KERNEL_NAME),Darwin)
	$(CC) \
	 -g \
	 -Wl,-no_pie \
	 -Wl,-rpath,$(POLYML_LIBDIR) \
	 -Wl,-rpath,$(GIRAFFE_POLYML_LIBDIR) \
	 -o $@ \
	 $< \
	 `PKG_CONFIG_PATH=$(POLYML_LIBDIR)/pkgconfig:$(PKG_CONFIG_PATH) pkg-config --libs polyml $(PKG_NAMES)` \
	 -L$(GIRAFFE_POLYML_LIBDIR) $(GIRAFFE_POLYML_LIB_LDFLAGS)
else
	$(CC) \
	 -g \
	 -rdynamic \
	 -Wl,--no-copy-dt-needed-entries \
	 -Wl,--no-as-needed \
	 -Wl,-rpath,$(POLYML_LIBDIR) \
	 -Wl,-rpath,$(GIRAFFE_POLYML_LIBDIR) \
	 -o $@ \
	 $< \
	 `PKG_CONFIG_PATH=$(POLYML_LIBDIR)/pkgconfig:$(PKG_CONFIG_PATH) pkg-config --libs polyml $(PKG_NAMES)` \
	 -L$(GIRAFFE_POLYML_LIBDIR) $(GIRAFFE_POLYML_LIB_LDFLAGS)
endif


.PHONY : polyml

polyml : $(TARGET_POLYML)

endif # POLYML_VERSION



################################################################################
# Cleaning
#

.PHONY : clean distclean

clean : clean-mlton clean-polyml

distclean : distclean-mlton distclean-polyml


#   - MLton

.PHONY : clean-mlton distclean-mlton

clean-mlton :
	rm -f $(TARGET_MLTON).o
	rm -f $(TARGET_MLTON).*.[cs]

distclean-mlton : clean-mlton
	rm -f $(TARGET_MLTON)


#   - Poly/ML

.PHONY : clean-polyml distclean-polyml

clean-polyml :
	rm -f polyml-libs.state
	rm -f polyml-export.sml
	rm -f $(TARGET_POLYML).o $(TARGET_POLYML).log

distclean-polyml : clean-polyml
	rm -f $(TARGET_POLYML)

