#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class LintError:
    path: Path
    line: int
    msg: str


def _is_text_ext(path: Path) -> bool:
    # Include TERP templates as well.
    name = path.name.lower()
    return any(
        name.endswith(ext)
        for ext in (
            ".vhd",
            ".terp.vhd",
            ".sv",
            ".v",
        )
    )


def _iter_targets(opq_split_dir: Path) -> list[Path]:
    # lint_opq.py lives under packet_scheduler/tb/lint/.
    # repo_root/.../mu3e-ip-cores
    repo_root = opq_split_dir.parents[2]
    pkt_sched = repo_root / "packet_scheduler"
    uvm_root_dir = repo_root / "uvm_order_priority_queue"

    roots = [
        pkt_sched / "rtl",
        pkt_sched / "tb",
        pkt_sched / "uvm",
        uvm_root_dir / "tb",
        uvm_root_dir / "rtl_overrides",
    ]

    def is_ignored(p: Path) -> bool:
        parts = set(p.parts)
        # Ignore generated simulator build outputs.
        if "trash_bin" in parts:
            return True
        # Ignore generated preprocessed monolithic outputs in TB folders (produced by update_preprocessed.sh).
        if ("packet_scheduler" in parts) and ("tb" in parts) and (p.name in {"ordered_priority_queue.vhd", "ordered_priority_queue_wrapper.vhd"}):
            return True
        if any(part.startswith("work_uvm_") for part in p.parts):
            return True
        if any(part in {"work", "rtl_gen_split", "rtl_gen_monolithic"} for part in p.parts):
            return True
        if any(part.startswith("work_") for part in p.parts):
            return True
        if "uvm_patched" in parts:
            return True
        if ".git" in parts:
            return True
        if ".qsys_edit" in parts:
            return True
        return False

    out: list[Path] = []
    for root in roots:
        if not root.exists():
            continue
        for p in root.rglob("*"):
            if is_ignored(p):
                continue
            if p.is_file() and _is_text_ext(p):
                out.append(p)
    return sorted(set(out))


def _check_newline_and_crlf(path: Path, data: bytes) -> list[LintError]:
    errs: list[LintError] = []
    if b"\r" in data:
        errs.append(LintError(path=path, line=1, msg="CRLF/CR characters found (use LF only)"))
    if data and not data.endswith(b"\n"):
        errs.append(LintError(path=path, line=1, msg="Missing trailing newline at EOF"))
    return errs


def _check_trailing_whitespace(path: Path, text: str) -> list[LintError]:
    errs: list[LintError] = []
    for idx, line in enumerate(text.splitlines(), start=1):
        if line.endswith(" ") or line.endswith("\t"):
            errs.append(LintError(path=path, line=idx, msg="Trailing whitespace"))
    return errs


def _check_vhdl_header(path: Path, text: str) -> list[LintError]:
    # Derive from packet_scheduler/ordered_priority_queue.terp.vhd:
    # expect a header block that contains the canonical fields and delimiter line:
    #   - "-- ------------------------------------------------------------------------------------------------------------"
    #   - "IP Name:"
    #   - "Author:"
    #   - "Revision:"
    #   - "Description:"
    # Only enforce for split RTL files (not TBs and not UVM SV).
    if path.suffix.lower() != ".vhd" and not path.name.lower().endswith(".terp.vhd"):
        return []

    sp = str(path)
    if "/packet_scheduler/tb/" in sp:
        return []
    if "/packet_scheduler/uvm/" in sp:
        return []
    if "/uvm_order_priority_queue/tb/" in sp:
        return []

    # Skip generated preprocessed output files that are expected to change per TERP run.
    if path.name in {"ordered_priority_queue_top.vhd"}:
        return []

    head = "\n".join(text.splitlines()[:80])
    errs: list[LintError] = []
    if not text.startswith("-- ------------------------------------------------------------------------------------------------------------"):
        errs.append(LintError(path=path, line=1, msg='Missing top-of-file delimiter line "-- ------------------------------------------------------------------------------------------------------------"'))
    if "IP Name:" not in head:
        errs.append(LintError(path=path, line=1, msg='Missing header field "IP Name:" in top-of-file comment block'))
    if "Author:" not in head:
        errs.append(LintError(path=path, line=1, msg='Missing header field "Author:" in top-of-file comment block'))
    if "Revision:" not in head:
        errs.append(LintError(path=path, line=1, msg='Missing header field "Revision:" in top-of-file comment block'))
    if "Description:" not in head:
        errs.append(LintError(path=path, line=1, msg='Missing header field "Description:" in top-of-file comment block'))
    return errs


def _check_vhdl_proc_doc(path: Path, text: str) -> list[LintError]:
    # Enforce that each labeled proc_* process has a nearby @name/@brief block.
    if path.suffix.lower() != ".vhd" and not path.name.lower().endswith(".terp.vhd"):
        return []

    sp = str(path)
    if "/packet_scheduler/tb/" in sp:
        return []
    if "/packet_scheduler/uvm/" in sp:
        return []
    if "/uvm_order_priority_queue/tb/" in sp:
        return []

    proc_re = re.compile(r"^\s*(proc_[A-Za-z0-9_]+)\s*:\s*process\b", re.IGNORECASE)
    lookback_lines = 400  # Monolithic OPQ uses large per-module blocks; keep this high enough for the matching @name/@brief.
    lines = text.splitlines()
    errs: list[LintError] = []
    for idx, line in enumerate(lines, start=1):
        m = proc_re.match(line)
        if not m:
            continue
        lookback = "\n".join(lines[max(0, idx - lookback_lines) : idx])
        if "-- @name" not in lookback:
            errs.append(LintError(path=path, line=idx, msg=f'{m.group(1)} missing preceding "-- @name" block'))
        if "-- @brief" not in lookback:
            errs.append(LintError(path=path, line=idx, msg=f'{m.group(1)} missing preceding "-- @brief" block'))
    return errs


def main() -> int:
    lint_dir = Path(__file__).resolve().parent
    targets = _iter_targets(lint_dir)
    if not targets:
        print("opq_lint: no targets found", file=sys.stderr)
        return 2

    errs: list[LintError] = []
    for path in targets:
        data = path.read_bytes()
        errs.extend(_check_newline_and_crlf(path, data))

        try:
            text = data.decode("utf-8")
        except UnicodeDecodeError:
            # All RTL/TB sources here should be UTF-8 (ordered_priority_queue.terp.vhd includes UTF-8 line art).
            errs.append(LintError(path=path, line=1, msg="File is not valid UTF-8"))
            continue

        errs.extend(_check_trailing_whitespace(path, text))
        errs.extend(_check_vhdl_header(path, text))
        errs.extend(_check_vhdl_proc_doc(path, text))

    if errs:
        print("opq_lint: FAIL\n", file=sys.stderr)
        for e in errs[:200]:
            print(f"{e.path}:{e.line}: {e.msg}", file=sys.stderr)
        if len(errs) > 200:
            print(f"... and {len(errs) - 200} more", file=sys.stderr)
        return 1

    print(f"opq_lint: PASS ({len(targets)} files)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
