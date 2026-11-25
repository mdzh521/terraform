#!/usr/bin/env python3
"""Ansible dynamic inventory backed by a Terraform environment output."""

import json
import os
import subprocess
import sys

if sys.argv[1:2] == ["--host"]:
    print("{}")
    sys.exit(0)


terraform_root = os.environ.get("TF_ROOT")
if not terraform_root:
    sys.stderr.write("Set TF_ROOT to aws/env/hosts or ali/env/hosts before running Ansible.\n")
    sys.exit(2)

try:
    raw = subprocess.check_output(
        ["terraform", f"-chdir={terraform_root}", "output", "-json", "ansible_inventory"],
        text=True,
    )
    output = json.loads(raw)
    inventory = output.get("value", output)
except (subprocess.CalledProcessError, json.JSONDecodeError) as exc:
    sys.stderr.write(f"Unable to read Terraform ansible_inventory output: {exc}\n")
    sys.exit(2)

print(json.dumps(inventory))
