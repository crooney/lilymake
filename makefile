
# Name of score. Defaults to name of current directory. Override by, e.g., "PIECE=Symphony make"
PIECE   ?= $(shell basename $(CURDIR))
# git version. defaults to 0.0 if git not used. May be safely ignored.
PROJVER := $(shell git tag 2>/dev/null | sort -V | tail -1)
PROJVER ?= 0.0
# lilypond executable. Defaults to default(!). Override by, e.g., "LILYCMD=/bin/lilypond make"
LILYCMD ?= $(shell which lilypond)
# For automatically including "\version" directives in generated files
LILYVER := $(shell $(LILYCMD) --version | grep -E -o "[0-9.]+" | head -1)


FORMAT      ?= pdf # output format defaults to pdf. Override by, e.g., "make svg png" for both image formats

# input and output directories any may be overriden by, e.g., "OUTDIR=product make"
GENDIR      ?= generated
OUTDIR      ?= out
ZIPDIR      ?= zip
GLOBDIR     ?= global
SRCDIR      ?= src
NOTEDIR     ?= notes
TEMPLATEDIR ?= template

# Various vars needed for buiding and generating
VPATH    := $(SRCDIR) $(NOTEDIR) $(GLOBDIR) $(GENDIR) $(OUTDIR)    # dirs to use automatically
PARTS    := $(notdir $(basename $(wildcard $(NOTEDIR)/*.ily)))     # violin bassoon, etc
OUTPARTS := $(patsubst %, $(PIECE)-%.$(FORMAT), $(PARTS))          # Symphony-violin, Symphony-bassoon, etc
GENPARTS := $(patsubst %, $(GENDIR)/$(PIECE)-%.ly, $(PARTS))       # violin.ly, bassoon.ly, etc
GLOBALS  := $(wildcard $(GLOBDIR)/*.ily)                           # global definition files, included in generated files
SRCS     := $(patsubst %, $(SRCDIR)/%, $(wildcard $(SRCDIR)/*.ly)) # non-generated .ly files
OUTS     := $(patsubst %.ly,%.$(FORMAT), $(notdir $(SRCS)))        # output files. pdfs or svgs, etc

# Flags for every invocation of lilypond. Override by, e.g., "FLAGS='-s' make"
FLAGS    ?= -dno-point-and-click -ddelete-intermediate-files
FLAGS    += -I $(CURDIR)/$(GENDIR) -I $(CURDIR)/$(NOTEDIR) -I $(CURDIR)/$(GLOBDIR) -f $(FORMAT)

# Default target. Prints variable values, generates intermediate files and builds output
all: vars generated $(OUTPARTS) $(OUTS)
	-mv *.$(FORMAT) $(OUTDIR)
	-mv *.mid* $(OUTDIR)

# Prints vars to screen before building
.PHONY: vars
vars:
	@echo  "piece:$(PIECE) version:$(PROJVER) lilycmd:$(LILYCMD) lilyver:$(LILYVER) parts:$(PARTS) genparts:$(GENPARTS) outparts:$(OUTPARTS) globals:$(GLOBALS) flags:$(FLAGS) srcs:$(SRCS) outs:$(OUTS)"

# Builds everything from scratch
.PHONY: release
release: clean all zip
# Removes everything generated or built. Start from a clean slate.
.PHONY: clean
clean:
	rm -fr $(GENDIR) $(OUTDIR) $(ZIPDIR)
# Create needed directories. Not an error if directories already exist.
.PHONY: dirs
dirs:
	mkdir -p $(GENDIR) $(OUTDIR) $(ZIPDIR)

# Build the file to use as a template for parts. Copies part.ly from ./template if it exists, or builds one by
# "\include" every definition ily file from global. Every use of _PART_ in the template will be replaced by the
# name of the part, e.g. violin or bassoon.
.INTERMEDIATE: $(GENDIR)/part-template.ly
$(GENDIR)/part-template.ly:
	-cp $(TEMPLATEDIR)/part.ly $@ 2>/dev/null
	if [ ! -s $@ ] ; then \
		echo "\\\version \"$(LILYVER)\"" >$@; \
		for G in $(GLOBALS) ; do \
			echo "\include \"$$G\" " >>$@; \
		done; \
		echo "\include \"$(NOTEDIR)/_PART_.ily\" " >>$@; \
	fi

# Rule to build a generated .ly file from a notes/x.ily file and change _PART_ to the partname.
%.ly: P += $(shell basename $@ .ly | sed "s/$(PIECE)-//")
%.ly: | $(GENDIR)/part-template.ly
	sed "s/_PART_/$P/g" $(GENDIR)/part-template.ly >$@

# Generate all prerequisites to building.
.PHONY: generated
generated: dirs $(GENDIR)/part-template.ly $(GENPARTS)
# Build individual output file from .ly
%.$(FORMAT): %.ly
	$(LILYCMD) $(FLAGS) $<

# Create zip file from .ly and .ily sources, including generated ones and zip file of all lilyponf output.
.PHONY: zip
zip: ZFLAGS ?= -q -j
zip: all  
	zip $(ZFLAGS) -r $(ZIPDIR)/$(PIECE)-src.zip **/*ly
	zip $(ZFLAGS) -r $(ZIPDIR)/$(PIECE)-score.zip $(OUTDIR)/*

# Target build types(s). Defaults to pdf, but any combination may be used, e.g., "make ps svg"
.PHONY: pdf
pdf:
	FORMAT=pdf make
.PHONY: ps
ps:
	FORMAT=ps make
.PHONY: svg
svg:
	FORMAT=svg make
.PHONY: png
png:
	FORMAT=png make

