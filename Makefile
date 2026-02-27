T_FEDORA := Containerfile.fedora.jinja2
FEDORA_43 := Containerfile.f43-ec2 Containerfile.f43-azure Containerfile.f43-gce Containerfile.f43-qcow2

T_CENTOS9 := Containerfile.centos9.jinja2
CENTOS_9 := Containerfile.c9-ec2 Containerfile.c9-azure Containerfile.c9-gce Containerfile.c9-qcow2

all: $(FEDORA_43) $(CENTOS_9)

.PHONY: clean
clean:
	rm -f $(FEDORA_43) $(CENTOS_9)

$(FEDORA_43): $(T_FEDORA)
	python3 generate.py --template $(T_FEDORA) --distro fedora --version 43 --type $(lastword $(subst -, ,$@)) > $@

$(CENTOS_9): $(T_CENTOS9)
	python3 generate.py --template $(T_CENTOS9) --distro centos --version 9 --type $(lastword $(subst -, ,$@)) > $@
