#!/usr/bin/env python3
"""
Generate Containerfile from a Jinja2 template.
"""
import getopt
import os
import sys


def main():
    try:
        import jinja2
    except ImportError:
        print("Install jinja2 (e.g. dnf -y install python3-jinja)", file=sys.stderr)
        sys.exit(1)

    long_opts = ["template=", "distro=", "version=", "type="]
    try:
        opts, args = getopt.gnu_getopt(sys.argv[1:], "", long_opts)
    except getopt.GetoptError as e:
        print(f"generator: {e}", file=sys.stderr)
        sys.exit(1)

    template_path = None
    distro = None
    version = None
    image_type = None

    for opt, arg in opts:
        if opt == "--template":
            template_path = arg
        elif opt == "--distro":
            distro = arg
        elif opt == "--version":
            version = arg
        elif opt == "--type":
            image_type = arg

    if template_path is None:
        template_path = "Containerfile.fedora.jinja2"
    if distro is None:
        distro = "fedora"
    if image_type is None or image_type == "":
        print("generator: missing --type", file=sys.stderr)
        sys.exit(1)

    if distro == "fedora":
        base_image = f"quay.io/fedora/fedora-bootc:{version}"
    else:
        base_image = f"quay.io/centos-bootc/centos-bootc:stream{version}"

    if not os.path.isabs(template_path) and not os.path.isfile(template_path):
        exe = sys.argv[0]
        if exe:
            alt = os.path.join(os.path.dirname(os.path.abspath(exe)), template_path)
            if os.path.isfile(alt):
                template_path = alt

    env = jinja2.Environment(
        trim_blocks=True,
        lstrip_blocks=False,
        keep_trailing_newline=True,
    )
    env.filters["ge"] = lambda v, min_v: str(v) >= str(min_v)

    try:
        with open(template_path, "r") as f:
            tmpl = env.from_string(f.read())
    except OSError as e:
        print(f"generator: parse template: {e}", file=sys.stderr)
        sys.exit(1)

    data = {
        "distro": distro,
        "version": version,
        "image_type": image_type,
        "base_image": base_image,
    }

    try:
        out = tmpl.render(**data)
    except jinja2.TemplateError as e:
        print(f"generator: execute: {e}", file=sys.stderr)
        sys.exit(1)

    sys.stdout.write(out)
    if out and not out.endswith("\n"):
        sys.stdout.write("\n")


if __name__ == "__main__":
    main()
