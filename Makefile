EBIN_DIR=ebin
ERLC=erlc -W0
ERL=erl -noshell -pa $(EBIN_DIR)

.PHONY: compile test clean

all: deps self

deps: deps/genx

deps/genx:
	@git clone https://github.com/yrashk/genx.git deps/genx
	@cd deps/genx && rm -rf ebin && mkdir -p ebin && elixirc lib -o ebin

compile: $(EBIN_DIR)

$(EBIN_DIR): $(shell find lib -type f -name "*.ex")
	@rm -rf ebin
	@mkdir -p $(EBIN_DIR)
	@touch $(EBIN_DIR)
	@elixirc -pa deps/genx/ebin lib -o ebin


self: $(EBIN_DIR)
	@echo "Rebuilding with Syrup itself..."
	@cp Syrup.app ebin/__MAIN__.Syrup.app
	@rm -rf builds
	@bin/syrup build

test: compile
	@echo Running tests ...
	time elixir -pa ebin -r "test/test_helper.exs" -pr "test/*_test.exs"
	@echo
clean:
	rm -rf $(EBIN_DIR)
	@echo
