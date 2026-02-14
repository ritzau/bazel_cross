#!/usr/bin/env python3
import json
import os
import platform
import shutil
import subprocess
import sys
from pathlib import Path
from typing import List, Dict, Union, Optional

def get_workspace_root() -> Path:
    """Determines the workspace root."""
    if "BUILD_WORKSPACE_DIRECTORY" in os.environ:
        return Path(os.environ["BUILD_WORKSPACE_DIRECTORY"])
    
    try:
        return Path(subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True).strip())
    except Exception:
        return Path.cwd()

class Tool:
    def __init__(self, label: str, items: Dict[str, Union[str, List[str]]], build_target: Optional[str] = None):
        self.label = label
        self.items = items
        self.build_target = build_target or label

def get_llvm_target() -> str:
    system = platform.system()
    machine = platform.machine()
    
    if system == "Linux":
        if machine == "x86_64":
            return "@llvm_toolchain//:all-components-x86_64-linux"
        elif machine == "aarch64":
            return "@llvm_toolchain//:all-components-aarch64-linux"
        else:
            print(f"Unsupported Linux architecture: {machine}")
            sys.exit(1)
    elif system == "Darwin":
        return "@llvm_toolchain//:all-components-x86_64-darwin"
    else:
        print(f"Unsupported OS: {system}")
        sys.exit(1)

def load_tools(config_path: Path) -> List[Tool]:
    with open(config_path, "r") as f:
        data = json.load(f)
    
    tools = []
    llvm_target = get_llvm_target()
    
    for item in data:
        build_target = item.get("build_target")
        if build_target == "__LLVM_TARGET__":
            build_target = llvm_target
        elif build_target is None:
            # Default to label if likely a rule, but let's stick to explicit or label
             build_target = item["label"]
             
        tools.append(Tool(
            label=item["label"],
            items=item["items"],
            build_target=build_target
        ))
    return tools

def setup_toolchain():
    workspace_root = get_workspace_root()
    os.chdir(workspace_root)
    print(f"Workspace root: {workspace_root}")

    target_dir = workspace_root / "bazel-tools"
    target_dir.mkdir(exist_ok=True)
    
    tools_config = workspace_root / "tools" / "tools.json"
    if not tools_config.exists():
        print(f"Error: Configuration file not found at {tools_config}")
        sys.exit(1)
        
    tools = load_tools(tools_config)
    system = platform.system()

    for tool in tools:
        print(f"Building {tool.build_target}...")
        subprocess.check_call(["bazel", "build", tool.build_target])

        cquery_args = ["bazel", "cquery", tool.label, "--output=files"]
        result = subprocess.check_output(cquery_args, text=True)
        
        output_path = Path(result.strip().splitlines()[0])
        if not output_path.is_absolute():
            output_path = workspace_root / output_path
            
        tool_bin_dir = output_path.parent
        print(f"  Located bin dir: {tool_bin_dir}")

        for symlink_name, sources in tool.items.items():
            if isinstance(sources, str):
                sources = [sources]
            
            src_file = None
            for source in sources:
                candidate = tool_bin_dir / source
                if candidate.exists():
                    src_file = candidate
                    break
            
            if src_file:
                dst = target_dir / symlink_name
                if dst.exists() or dst.is_symlink():
                    dst.unlink()
                dst.symlink_to(src_file)
                print(f"  Symlinked {symlink_name} -> {src_file.name}")
            else:
                if symlink_name == "lldb" and system == "Darwin":
                    print("  Note: lldb not found (expected on macOS).")
                elif symlink_name == "llvm-symbolizer" and "llvm-toolchain" in tool.label:
                     pass
                else:
                    print(f"  Warning: Could not find sources {sources} in {tool_bin_dir}")

    print("")
    print("Done! Add this to your shell profile (e.g. ~/.zshrc):")
    print(f'export PATH="{target_dir}:$PATH"')

if __name__ == "__main__":
    setup_toolchain()
