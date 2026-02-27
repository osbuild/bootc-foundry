T_FEDORA := Containerfile.fedora.jinja2
FEDORA_43 := Containerfile.f43-ec2 Containerfile.f43-azure Containerfile.f43-gce Containerfile.f43-qcow2

all: $(FEDORA_43)

.PHONY: clean
clean:
	rm -f $(FEDORA_43)

$(FEDORA_43): $(T_FEDORA)
	python3 generate.py --template $(T_FEDORA) --distro fedora --version 43 --type $(lastword $(subst -, ,$@)) > $@
