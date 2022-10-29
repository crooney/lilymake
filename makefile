PIECE   ?= $(shell basename $(CURDIR))
PROJVER := $(shell git tag 2>/dev/null | sort -V | tail -1)
PROJVER ?= 0.0
LILYCMD ?= $(shell which lilypond)
LILYVER := $(shell $(LILYCMD) --version | grep -E -o "[0-9.]+" | head -1)

FORMAT      ?= pdf
GENDIR      ?= generated
OUTDIR      ?= out
ZIPDIR      ?= zip
GLOBDIR     ?= globals
SRCDIR      ?= src
NOTEDIR     ?= notes
TEMPLATEDIR ?= template

VPATH    := $(SRCDIR) $(NOTEDIR) $(GLOBDIR) $(GENDIR) $(OUTDIR)
PARTS    := $(notdir $(basename $(wildcard $(NOTEDIR)/*.ily)))
OUTPARTS := $(patsubst %, $(PIECE)-%.$(FORMAT), $(PARTS))
GENPARTS := $(patsubst %, $(GENDIR)/$(PIECE)-%.ly, $(PARTS))
GLOBALS  := $(wildcard $(GLOBDIR)/*.ily)
SRCS     := $(patsubst %, $(SRCDIR)/%, $(wildcard $(SRCDIR)/*.ly))
OUTS     := $(patsubst %.ly,%.$(FORMAT), $(notdir $(SRCS)))
FLAGS    ?= -dno-point-and-click -ddelete-intermediate-files
FLAGS    += -I $(CURDIR)/$(GENDIR) -I $(CURDIR)/$(NOTEDIR) -I $(CURDIR)/$(GLOBDIR) -f $(FORMAT)

all: vars generated $(OUTPARTS) $(OUTS)
	-mv *.$(FORMAT) $(OUTDIR)
	-mv *.mid* $(OUTDIR)

.PHONY: vars
vars:
	@echo  "piece:$(PIECE) version:$(PROJVER) lilycmd:$(LILYCMD) lilyver:$(LILYVER) parts:$(PARTS) genparts:$(GENPARTS) outparts:$(OUTPARTS) globals:$(GLOBALS) flags:$(FLAGS) srcs:$(SRCS) outs:$(OUTS)"
	
.PHONY: release
release: clean all zip

.PHONY: clean
clean:
	rm -fr $(GENDIR) $(OUTDIR) $(ZIPDIR)
	
.PHONY: dirs
dirs:
	mkdir -p $(GENDIR) $(OUTDIR) $(ZIPDIR)

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
	
%.ly: P += $(shell basename $@ .ly | sed "s/$(PIECE)-//")
%.ly: | $(GENDIR)/part-template.ly
	sed "s/_PART_/$P/g" $(GENDIR)/part-template.ly >$@
        
.PHONY: generated
generated: dirs $(GENDIR)/part-template.ly $(GENPARTS)

%.$(FORMAT): %.ly
	$(LILYCMD) $(FLAGS) $<

.PHONY: zip
zip: ZFLAGS ?= -q -j
zip: all  
	zip $(ZFLAGS) -r $(ZIPDIR)/$(PIECE)-src.zip **/*ly
	zip $(ZFLAGS) -r $(ZIPDIR)/$(PIECE)-score.zip $(OUTDIR)/*
	
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

