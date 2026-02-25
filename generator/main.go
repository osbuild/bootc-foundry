package main

import (
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"text/template"
)

// Data passed to the Containerfile template.
type Data struct {
	Distro    string
	Version   string
	ImageType string
	BaseImage string
}

func main() {
	tmplPath := flag.String("template", "Containerfile.fedora-tmpl", "Path to template file")
	distro := flag.String("distro", "fedora", "Distribution (e.g. fedora)")
	version := flag.String("version", "43", "Version (e.g. 43)")
	imageType := flag.String("type", "", "Image type (cloud-ec2, cloud-azure, cloud-gce, cloud-qcow2)")
	flag.Parse()

	data, err := buildData(*distro, *version, *imageType)
	if err != nil {
		fmt.Fprintf(os.Stderr, "generator: %v\n", err)
		os.Exit(1)
	}

	if !filepath.IsAbs(*tmplPath) {
		if _, err := os.Stat(*tmplPath); err != nil {
			exe, _ := os.Executable()
			*tmplPath = filepath.Join(filepath.Dir(exe), *tmplPath)
		}
	}

	tmpl, err := template.New(filepath.Base(*tmplPath)).ParseFiles(*tmplPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "generator: parse template: %v\n", err)
		os.Exit(1)
	}

	if err := tmpl.Execute(os.Stdout, data); err != nil {
		fmt.Fprintf(os.Stderr, "generator: execute: %v\n", err)
		os.Exit(1)
	}
}

func buildData(distro, version, imageType string) (*Data, error) {
	if imageType == "" {
		return nil, fmt.Errorf("missing -type")
	}

	data := &Data{
		Distro:    distro,
		Version:   version,
		ImageType: imageType,
	}

	switch data.Distro {
	case "fedora":
		data.BaseImage = "quay.io/fedora/fedora-bootc:" + data.Version
	default:
		data.BaseImage = "quay.io/" + data.Distro + "/" + data.Distro + "-bootc:" + data.Version
	}

	return data, nil
}
