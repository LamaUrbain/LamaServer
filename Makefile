# OASIS_START
# DO NOT EDIT (digest: 9a60866e2fa295c5e33a3fe33b8f3a32)

SETUP = ./setup.exe

build: setup.data $(SETUP)
	$(SETUP) -build $(BUILDFLAGS)

doc: setup.data $(SETUP) build
	$(SETUP) -doc $(DOCFLAGS)

test: setup.data $(SETUP) build
	$(SETUP) -test $(TESTFLAGS)

all: $(SETUP)
	$(SETUP) -all $(ALLFLAGS)

install: setup.data $(SETUP)
	$(SETUP) -install $(INSTALLFLAGS)

uninstall: setup.data $(SETUP)
	$(SETUP) -uninstall $(UNINSTALLFLAGS)

reinstall: setup.data $(SETUP)
	$(SETUP) -reinstall $(REINSTALLFLAGS)

clean: $(SETUP)
	$(SETUP) -clean $(CLEANFLAGS)

distclean: $(SETUP)
	$(SETUP) -distclean $(DISTCLEANFLAGS)
	$(RM) $(SETUP)

setup.data: $(SETUP)
	$(SETUP) -configure $(CONFIGUREFLAGS)

configure: $(SETUP)
	$(SETUP) -configure $(CONFIGUREFLAGS)

setup.exe: setup.ml
	ocamlfind ocamlopt -o $@ -linkpkg -package oasis.dynrun $< || ocamlfind ocamlc -o $@ -linkpkg -package oasis.dynrun $< || true
	$(RM) setup.cmi setup.cmo setup.cmx setup.o

.PHONY: build doc test all install uninstall reinstall clean distclean configure

# OASIS_STOP

STATIC_DIR = /tmp/data

$(STATIC_DIR):
	mkdir -p $(STATIC_DIR)
	cp -r data/ $(STATIC_DIR)/


run: $(STATIC_DIR)
	ocsigenserver -c ocsigenserver.conf -v

DATADIR := data/

setup: $(DATADIR)
	@ mkdir -p data/ol
	@ wget http://openlayers.org/en/v3.1.1/build/ol.js -O data/ol/ol.js
	@ bower install
	@ mkdir -p data/css/
	@ lessc --compress data/less/style.less > data/css/style.css

