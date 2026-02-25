package main

import (
	"flag"
	"fmt"
	"os"
)

func main() {
	distroVersion := flag.String("distro-version", "", "Distribution name and version (e.g. fedora-41, rhel-8)")
	imageType := flag.String("type", "", "Image type (e.g. cloud-ec2, cloud-azure, cloud-gce, cloud-qcow2)")
	arch := flag.String("arch", "x86_64", "Architecture for package sets and config")
	flag.Parse()

	if *distroVersion == "" || *imageType == "" {
		fmt.Fprintf(os.Stderr, "Usage: generator -distro-version <name-version> -type <image-type> [-arch x86_64]\n")
		flag.Usage()
		os.Exit(2)
	}

	if err := Generate(os.Stdout, *distroVersion, *imageType, *arch); err != nil {
		fmt.Fprintf(os.Stderr, "generator: %v\n", err)
		os.Exit(1)
	}
}
