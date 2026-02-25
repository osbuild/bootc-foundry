package main

import (
	"fmt"
	"io"
	"os"
	"slices"
	"sort"
	"strconv"
	"strings"

	"github.com/osbuild/images/pkg/customizations/fsnode"
	"github.com/osbuild/images/pkg/distro"
	"github.com/osbuild/images/pkg/distro/defs"
	"github.com/osbuild/images/pkg/osbuild"
	"github.com/osbuild/images/pkg/rpmmd"
)

func Generate(w io.Writer, distroVersion, imageType, arch string) error {
	d, err := defs.NewDistroYAML(distroVersion)
	if err != nil {
		return fmt.Errorf("load distro: %w", err)
	}
	if d == nil {
		return fmt.Errorf("distro %q not found", distroVersion)
	}

	types := d.ImageTypes()
	it, ok := types[imageType]
	if !ok {
		return fmt.Errorf("image type %q not found for distro %q", imageType, distroVersion)
	}

	baseConfig := d.ImageConfig()
	typeConfig := it.ImageConfig(d.ID, arch)
	var imgConfig *distro.ImageConfig
	if typeConfig == nil {
		imgConfig = baseConfig
	} else {
		imgConfig = typeConfig.InheritFrom(baseConfig)
	}

	sw := NewMustWriter(w)
	sw.Printf("# Containerfile for %s %s %s\n", distroVersion, imageType, arch)
	sw.Printf("FROM %s\n\n", distroBaseImage(d.ID))

	pkgSets := it.PackageSets(d.ID, arch)
	if osSet, ok := pkgSets["os"]; ok && (len(osSet.Include) > 0 || len(osSet.Exclude) > 0) {
		writePackageRun(sw, osSet)
	}

	if imgConfig != nil && len(imgConfig.KernelOptions) > 0 {
		writeKernelOptionsRun(sw, imgConfig.KernelOptions)
	}

	if imgConfig != nil {
		writeServicesRun(sw, imgConfig.EnabledServices, imgConfig.DisabledServices, imgConfig.MaskedServices)
	}

	if imgConfig != nil && len(imgConfig.Directories) > 0 {
		writeDirectoriesRun(sw, imgConfig.Directories)
	}

	if imgConfig != nil && len(imgConfig.Files) > 0 {
		writeFilesRun(sw, imgConfig.Files)
	}

	if imgConfig != nil && imgConfig.Tuned != nil && len(imgConfig.Tuned.Profiles) > 0 {
		writeTunedRun(sw, imgConfig.Tuned)
	}

	if imgConfig != nil && len(imgConfig.Tmpfilesd) > 0 {
		writeTmpfilesdRun(sw, imgConfig.Tmpfilesd)
	}

	if imgConfig != nil && len(imgConfig.Sysctld) > 0 {
		writeSysctldRun(sw, imgConfig.Sysctld)
	}

	return nil
}

// distroBaseImage returns the bootc base image URL for the distro, or the id string if unknown.
func distroBaseImage(id distro.ID) string {
	switch id.Name {
	case "fedora":
		return "quay.io/fedora/fedora-bootc:" + id.VersionString()
	case "centos", "centos-stream":
		return "quay.io/centos-bootc/centos-bootc:stream" + strconv.Itoa(id.MajorVersion)
	case "rhel":
		return "registry.redhat.io/rhel" + strconv.Itoa(id.MajorVersion) + "/rhel-bootc:latest"
	default:
		return id.String()
	}
}

func writePackageRun(sw *MustWriter, ps rpmmd.PackageSet) {
	sort.Strings(ps.Include)
	sort.Strings(ps.Exclude)

	args := make([]string, 0, 4+len(ps.Include)+len(ps.Exclude))
	args = append(args, "RUN", "dnf", "install", "-y")
	for _, p := range ps.Include {
		args = append(args, strconv.Quote(p))
	}
	for _, p := range ps.Exclude {
		args = append(args, "--exclude="+strconv.Quote(p))
	}
	if len(args) <= 4 {
		return
	}
	sw.WriteCmd(args...)
	sw.WriteByte('\n')
}

func writeKernelOptionsRun(sw *MustWriter, opts []string) {
	content := strings.Join(opts, " ") + "\n"
	writeContentRun(sw, "/etc/kernel/cmdline", content)
}

func writeServicesRun(sw *MustWriter, enabled, disabled, masked []string) {
	if len(enabled) == 0 && len(disabled) == 0 && len(masked) == 0 {
		return
	}

	slices.Sort(enabled)
	slices.Sort(disabled)
	slices.Sort(masked)

	args := []string{"RUN"}
	if len(enabled) > 0 {
		args = append(args, "systemctl", "enable")
		args = append(args, quoteAll(enabled)...)
	}
	if len(disabled) > 0 {
		if len(args) > 1 {
			args = append(args, "&&")
		}
		args = append(args, "systemctl", "disable")
		args = append(args, quoteAll(disabled)...)
	}
	if len(masked) > 0 {
		if len(args) > 1 {
			args = append(args, "&&")
		}
		args = append(args, "systemctl", "mask")
		args = append(args, quoteAll(masked)...)
	}
	sw.WriteCmd(args...)
	sw.WriteByte('\n')
}

func quoteAll(s []string) []string {
	out := make([]string, len(s))
	for i, v := range s {
		out[i] = strconv.Quote(v)
	}
	return out
}

func writeDirectoriesRun(sw *MustWriter, dirs []*fsnode.Directory) {
	for _, d := range dirs {
		if d == nil {
			continue
		}
		path := d.Path()
		pathQ := strconv.Quote(path)
		mode := modeStr(d.Mode(), "755")
		user, group := userGroupStr(d.User(), d.Group())
		args := []string{"RUN", "mkdir", "-p", pathQ}
		if mode != "" {
			args = append(args, "&&", "chmod", mode, pathQ)
		}
		if user != "" || group != "" {
			args = append(args, "&&", "chown", ownerArg(user, group), pathQ)
		}
		sw.WriteCmd(args...)
	}
	if len(dirs) > 0 {
		sw.WriteByte('\n')
	}
}

func writeFilesRun(sw *MustWriter, files []*fsnode.File) {
	for _, f := range files {
		if f == nil {
			continue
		}
		path := f.Path()
		content := string(f.Data())
		writeContentRun(sw, path, content)
		mode := modeStr(f.Mode(), "0644")
		user, group := userGroupStr(f.User(), f.Group())
		if mode != "0644" || user != "" || group != "" {
			pathQ := strconv.Quote(path)
			args := []string{"RUN"}
			if mode != "0644" {
				args = append(args, "chmod", mode, pathQ)
			}
			if user != "" || group != "" {
				if len(args) > 1 {
					args = append(args, "&&")
				}
				args = append(args, "chown", ownerArg(user, group), pathQ)
			}
			sw.WriteCmd(args...)
		}
	}
	if len(files) > 0 {
		sw.WriteByte('\n')
	}
}

func writeContentRun(sw *MustWriter, path, content string) {
	delim := "EOF"
	for strings.Contains(content, delim) {
		delim = delim + "_" + delim
	}

	sw.Printf("RUN cat << '%s' > %s\n", delim, strconv.Quote(path))
	sw.WriteString(content)
	if !strings.HasSuffix(content, "\n") {
		sw.WriteByte('\n')
	}
	sw.Printf("%s\n\n", delim)
}

func modeStr(m *os.FileMode, defaultMode string) string {
	if m == nil {
		return defaultMode
	}
	return fmt.Sprintf("%#o", *m&0o777)
}

func userGroupStr(user, group interface{}) (u, g string) {
	if user != nil {
		switch v := user.(type) {
		case string:
			u = v
		case int64:
			u = strconv.FormatInt(v, 10)
		case float64:
			u = strconv.FormatInt(int64(v), 10)
		}
	}
	if group != nil {
		switch v := group.(type) {
		case string:
			g = v
		case int64:
			g = strconv.FormatInt(v, 10)
		case float64:
			g = strconv.FormatInt(int64(v), 10)
		}
	}
	return u, g
}

func ownerArg(user, group string) string {
	if user == "" {
		user = "root"
	}
	if group == "" {
		group = "root"
	}
	return user + ":" + group
}

func writeTunedRun(sw *MustWriter, opts *osbuild.TunedStageOptions) {
	if opts == nil || len(opts.Profiles) == 0 {
		return
	}
	args := make([]string, 0, 8+len(opts.Profiles))
	args = append(args, "RUN", "dnf", "install", "-y", "tuned", "&&", "tuned-adm", "profile")
	args = append(args, quoteAll(opts.Profiles)...)
	sw.WriteCmd(args...)
	sw.WriteByte('\n')
}

func writeTmpfilesdRun(sw *MustWriter, opts []*osbuild.TmpfilesdStageOptions) {
	for _, o := range opts {
		if o == nil || len(o.Config) == 0 {
			continue
		}
		path := "/etc/tmpfiles.d/" + o.Filename
		var lines []string
		for _, c := range o.Config {
			line := c.Type + " " + c.Path
			if c.Mode != "" {
				line += " " + c.Mode
			}
			if c.User != "" {
				line += " " + c.User
			}
			if c.Group != "" {
				line += " " + c.Group
			}
			if c.Age != "" {
				line += " " + c.Age
			}
			if c.Argument != "" {
				line += " " + c.Argument
			}
			lines = append(lines, line)
		}
		content := strings.Join(lines, "\n") + "\n"
		writeContentRun(sw, path, content)
	}
	if len(opts) > 0 {
		sw.WriteByte('\n')
	}
}

func writeSysctldRun(sw *MustWriter, opts []*osbuild.SysctldStageOptions) {
	for _, o := range opts {
		if o == nil || len(o.Config) == 0 {
			continue
		}
		path := "/etc/sysctl.d/" + o.Filename
		var lines []string
		for _, c := range o.Config {
			if c.Value == "" && strings.HasPrefix(c.Key, "-") {
				lines = append(lines, c.Key)
			} else {
				lines = append(lines, c.Key+" = "+c.Value)
			}
		}
		content := strings.Join(lines, "\n") + "\n"
		writeContentRun(sw, path, content)
	}
	if len(opts) > 0 {
		sw.WriteByte('\n')
	}
}
