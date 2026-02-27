T_FEDORA := Containerfile.fedora.jinja2

all: Containerfile.f43-ec2 Containerfile.f43-azure Containerfile.f43-gce Containerfile.f43-qcow2

.PHONY: clean
clean:
	rm -f Containerfile.f43-ec2 Containerfile.f43-azure Containerfile.f43-gce Containerfile.f43-qcow2

Containerfile.f43-ec2: $(T_FEDORA)
	python3 generate.py --template $(T_FEDORA) --distro fedora --version 43 --type cloud-ec2 > $@

Containerfile.f43-azure: $(T_FEDORA)
	python3 generate.py --template $(T_FEDORA) --distro fedora --version 43 --type cloud-azure > $@

Containerfile.f43-gce: $(T_FEDORA)
	python3 generate.py --template $(T_FEDORA) --distro fedora --version 43 --type cloud-gce > $@

Containerfile.f43-qcow2: $(T_FEDORA)
	python3 generate.py --template $(T_FEDORA) --distro fedora --version 43 --type cloud-qcow2 > $@
