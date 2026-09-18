vc ?= valk

test:
	$(vc) build ./tests --test --run
test-basics:
	$(vc) build ./tests --test --run --filter "Basics"
deps:
	vman install
lint:
	$(vc) build ./src --lint
example:
	$(vc) build ./example --run
docs:
	$(vc) doc . -o docs/api.md --markdown --no-private
	$(vc) doc . -o docs/api-full.md --markdown --no-private --full

.PHONY: deps test test-basics lint example docs
