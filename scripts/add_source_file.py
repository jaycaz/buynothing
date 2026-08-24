#!/usr/bin/env python3
"""Adds a Swift source file to BuyNothing.xcodeproj's main app target.

Usage: add_source_file.py <path/relative/to/BuyNothing/dir e.g. Utilities/Foo.swift> --group <GroupName>

Inserts the 4 required entries (PBXBuildFile, PBXFileReference, PBXGroup child,
PBXSourcesBuildPhase file) into project.pbxproj using the same textual pattern
as every other Swift file already in the project. Does NOT create the file on
disk -- create it first with the real content, then run this script.
"""
import re
import sys
import uuid
import argparse

def fresh_uuid():
    return uuid.uuid4().hex[:24].upper()

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("relpath", help="path relative to the BuyNothing/ source dir, e.g. Utilities/Foo.swift")
    parser.add_argument("--group", required=True, help="name of the PBXGroup to add this file to, e.g. Utilities")
    parser.add_argument("--project", default="BuyNothing.xcodeproj/project.pbxproj")
    args = parser.parse_args()

    filename = args.relpath.split("/")[-1]
    assert filename.endswith(".swift"), "expected a .swift file"

    with open(args.project, "r") as f:
        content = f.read()

    build_uuid = fresh_uuid()
    ref_uuid = fresh_uuid()

    # 1. PBXBuildFile section
    build_line = f"\t\t{build_uuid} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {ref_uuid} /* {filename} */; }};\n"
    marker = "/* End PBXBuildFile section */"
    assert marker in content, "PBXBuildFile end marker not found"
    content = content.replace(marker, build_line + marker, 1)

    # 2. PBXFileReference section
    ref_line = f"\t\t{ref_uuid} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {filename}; sourceTree = \"<group>\"; }};\n"
    marker = "/* End PBXFileReference section */"
    assert marker in content, "PBXFileReference end marker not found"
    content = content.replace(marker, ref_line + marker, 1)

    # 3. PBXGroup children list for the named group
    group_pattern = re.compile(
        r"(\w+ /\* " + re.escape(args.group) + r" \*/ = \{\n\s*isa = PBXGroup;\n\s*children = \(\n)"
    )
    m = group_pattern.search(content)
    assert m, f"could not find PBXGroup named {args.group}"
    child_line = f"\t\t\t\t{ref_uuid} /* {filename} */,\n"
    content = content[: m.end()] + child_line + content[m.end() :]

    # 4. PBXSourcesBuildPhase files list (main app target's build phase; assumes exactly one
    # PBXSourcesBuildPhase with a non-empty files list precedes any test target's, matching
    # this project's current layout).
    phase_pattern = re.compile(
        r"(isa = PBXSourcesBuildPhase;\n\s*buildActionMask = \d+;\n\s*files = \(\n)"
    )
    m = phase_pattern.search(content)
    assert m, "could not find PBXSourcesBuildPhase"
    source_line = f"\t\t\t\t{build_uuid} /* {filename} in Sources */,\n"
    content = content[: m.end()] + source_line + content[m.end() :]

    with open(args.project, "w") as f:
        f.write(content)

    print(f"Added {filename} (fileRef={ref_uuid}, build={build_uuid}) to group '{args.group}'")

if __name__ == "__main__":
    main()
