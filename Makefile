
.PHONY: build
build:
	iverilog -o a.out main.v -g2012

.PHONY: run
run: build
	vvp a.out

.PHONY: clean
clean:
	rm -f a.out