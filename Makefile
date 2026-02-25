GENERATOR := generator/generator
DISTROCAT := distrocat/distrocat
T_FEDORA := Containerfile.fedora-tmpl

all: Containerfile.fedora-43-ec2 Containerfile.fedora-43-azure Containerfile.fedora-43-gce Containerfile.fedora-43-qcow2

$(GENERATOR): $(wildcard generator/*.go generator/go.mod generator/go.sum)
	cd generator && go build -o generator .

$(DISTROCAT): $(wildcard distrocat/*.go)
	cd distrocat && go build -o distrocat .

.PHONY: clean
clean:
	rm -f $(GENERATOR) $(DISTROCAT)

Containerfile.fedora-43-ec2: $(GENERATOR) $(T_FEDORA)
	./$(GENERATOR) -template $(T_FEDORA) -distro fedora -version 43 -type cloud-ec2 > $@

Containerfile.fedora-43-azure: $(GENERATOR) $(T_FEDORA)
	./$(GENERATOR) -template $(T_FEDORA) -distro fedora -version 43 -type cloud-azure > $@

Containerfile.fedora-43-gce: $(GENERATOR) $(T_FEDORA)
	./$(GENERATOR) -template $(T_FEDORA) -distro fedora -version 43 -type cloud-gce > $@

Containerfile.fedora-43-qcow2: $(GENERATOR) $(T_FEDORA)
	./$(GENERATOR) -template $(T_FEDORA) -distro fedora -version 43 -type cloud-qcow2 > $@
