
.PHONY: build
build:
	iverilog -g2012 -o a.out main.v components.v

.PHONY: run
run: build
	vvp a.out

.PHONY: clean
clean:
	rm -f a.out
