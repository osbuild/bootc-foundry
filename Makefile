.PHONY: lint
lint: lint-shell lint-yaml

.PHONY: lint-shell
lint-shell:
	shellcheck --shell=bash -x -P SCRIPTDIR $$(find . -name '*.sh' -not -path '*/.git/*')

.PHONY: lint-yaml
lint-yaml:
	yamllint $$(find . \( -name '*.yml' -o -name '*.yaml' \) -not -path '*/.git/*')
