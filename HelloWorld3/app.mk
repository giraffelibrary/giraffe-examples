################################################################################
# Application-specific values

NAME := helloworld3


# MLton target
#
# Define:
#   SRC_MLTON       - the SML source files for MLton
#   TARGET_MLTON    - the binary to be built with MLton

ifdef MLTON_VERSION

SRC_MLTON := $(shell $(MLTON_MLTON) -mlb-path-var 'GIRAFFE_SML_LIB $(GIRAFFE_SML_LIBDIR)' -stop f mlton.mlb)

TARGET_MLTON := $(NAME)-mlton

endif


# Poly/ML target
#
# Define:
#   SRC_POLYML      - the SML source files for Poly/ML
#   TARGET_POLYML   - the binary to be built with Poly/ML

ifdef POLYML_VERSION

SRC_POLYML := $(shell cat polyml-app.sml | sed -n 's|^use "\([^"]*\)";$$|\1|p')

TARGET_POLYML := $(NAME)-polyml

endif


# Library dependencies
#
# Define:
#   LIB_NAMES       - list of the libraries that the application references

LIB_NAMES := \
	gobject-2.0 \
	gio-2.0 \
	gtk-3.0

# Note that LIB_NAMES does _not_ contain pkg-config names but GIR namespace
# names, which are also the directory names in $(GIRAFFEHOME)/lib/sml.
#
# One method to determine the list is as follows: for each instance of
#
#   $(GIRAFFE_SML_LIB)/$(LIB_NAME)/mlton.mlb
#
# in mlton.mlb, the list should include $(LIB_NAME).
