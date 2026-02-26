GENERATOR := generator/generator
T_FEDORA := Containerfile.fedora-tmpl

all: Containerfile.fedora-43-ec2 Containerfile.fedora-43-azure Containerfile.fedora-43-gce Containerfile.fedora-43-qcow2

$(GENERATOR): $(wildcard generator/*.go generator/go.mod generator/go.sum)
	cd generator && go build -o generator .

.PHONY: clean
clean:
	rm -f $(GENERATOR)

Containerfile.fedora-43-ec2: $(GENERATOR) $(T_FEDORA)
	./$(GENERATOR) -template $(T_FEDORA) -distro fedora -version 43 -type cloud-ec2 > $@

Containerfile.fedora-43-azure: $(GENERATOR) $(T_FEDORA)
	./$(GENERATOR) -template $(T_FEDORA) -distro fedora -version 43 -type cloud-azure > $@

Containerfile.fedora-43-gce: $(GENERATOR) $(T_FEDORA)
	./$(GENERATOR) -template $(T_FEDORA) -distro fedora -version 43 -type cloud-gce > $@

Containerfile.fedora-43-qcow2: $(GENERATOR) $(T_FEDORA)
	./$(GENERATOR) -template $(T_FEDORA) -distro fedora -version 43 -type cloud-qcow2 > $@
