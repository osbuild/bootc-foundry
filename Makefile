# Lint shell scripts and YAML files
.PHONY: lint
lint: lint-shell lint-yaml

.PHONY: lint-shell
lint-shell:
	shellcheck --shell=bash $$(find . -name '*.sh' -not -path '*/.git/*')

.PHONY: lint-yaml
lint-yaml:
	yamllint $$(find . \( -name '*.yml' -o -name '*.yaml' \) -not -path '*/.git/*')
