#!/usr/bin/env python3
"""
Analyze Xcode Instruments .trace files — extract Heaviest Stack Trace.

Usage:
    # Symbolicate first (recommended):
    xctrace symbolicate --input MyApp.trace

    # Then analyze:
    python3 analyze_trace.py MyApp.trace

    # Analyze specific thread:
    python3 analyze_trace.py MyApp.trace --thread "Main Thread"

    # Show more app frames:
    python3 analyze_trace.py MyApp.trace --app-keywords MyApp,ViewController,Cell
"""

import argparse
import subprocess
import sys
import xml.etree.ElementTree as ET
from collections import defaultdict


def export_time_profile(trace_path: str) -> ET.Element:
    xpath = '/trace-toc/run[@number="1"]/data/table[@schema="time-profile"]'
    result = subprocess.run(
        ["xctrace", "export", "--input", trace_path, "--xpath", xpath],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        print(f"xctrace export failed:\n{result.stderr}", file=sys.stderr)
        sys.exit(1)
    return ET.fromstring(result.stdout)


def parse_rows(root: ET.Element):
    node = root.find(".//node")
    if node is None:
        print("No <node> element found in export.", file=sys.stderr)
        sys.exit(1)

    frame_names = {}
    thread_names = {}
    weight_values = {}

    rows = node.findall("row")

    # Collect all id -> value mappings
    for row in rows:
        for elem in row.iter():
            eid = elem.get("id")
            if not eid:
                continue
            if elem.tag == "frame":
                frame_names[eid] = elem.get("name", "unknown")
            elif elem.tag == "thread":
                thread_names[eid] = elem.get("fmt", "unknown")
            elif elem.tag == "weight":
                weight_values[eid] = int(elem.text) if elem.text else 0

    # Build per-sample data
    samples = []
    for row in rows:
        weight_elem = row.find("weight")
        weight = 0
        if weight_elem is not None:
            wid = weight_elem.get("id") or weight_elem.get("ref")
            if wid and wid in weight_values:
                weight = weight_values[wid]
            elif weight_elem.text:
                weight = int(weight_elem.text)
                wid2 = weight_elem.get("id")
                if wid2:
                    weight_values[wid2] = weight

        thread_elem = row.find("thread")
        tname = "unknown"
        if thread_elem is not None:
            tid = thread_elem.get("id") or thread_elem.get("ref")
            tname = thread_names.get(tid, "unknown")

        bt = row.find("backtrace")
        frames = []
        if bt is not None:
            for f in bt.findall("frame"):
                fid = f.get("id")
                if fid:
                    frame_names[fid] = f.get("name", "unknown")
                fid2 = fid or f.get("ref")
                frames.append(frame_names.get(fid2, f.get("name", "unknown")))

        samples.append((tname, weight, frames))

    return samples


class CallTreeNode:
    __slots__ = ("name", "self_weight", "total_weight", "children")

    def __init__(self, name: str):
        self.name = name
        self.self_weight = 0
        self.total_weight = 0
        self.children: dict[str, "CallTreeNode"] = {}

    def add_stack(self, frames: list[str], weight: int):
        self.total_weight += weight
        if not frames:
            self.self_weight += weight
            return
        child_name = frames[0]
        if child_name not in self.children:
            self.children[child_name] = CallTreeNode(child_name)
        self.children[child_name].add_stack(frames[1:], weight)


def heaviest_path(node: CallTreeNode) -> list[tuple[str, int, int]]:
    path = []
    current = node
    while current.children:
        heaviest = max(current.children.values(), key=lambda c: c.total_weight)
        path.append((heaviest.name, heaviest.total_weight, heaviest.self_weight))
        current = heaviest
    return path


def print_thread_distribution(samples, total_weight):
    thread_weights: dict[str, int] = defaultdict(int)
    for tname, weight, _ in samples:
        thread_weights[tname] += weight

    print("=" * 90)
    print("THREAD WEIGHT DISTRIBUTION")
    print("=" * 90)
    for tname, w in sorted(thread_weights.items(), key=lambda x: -x[1]):
        pct = w / total_weight * 100 if total_weight else 0
        ms = w / 1_000_000
        print(f"  {ms:8.1f} ms ({pct:5.1f}%) | {tname}")
    print()


def print_heaviest_stack(tree: CallTreeNode, label: str, app_keywords: list[str]):
    total = tree.total_weight
    print("=" * 90)
    print(f"HEAVIEST STACK TRACE — {label}")
    print("=" * 90)
    print(f"Total weight: {total / 1_000_000:.1f} ms\n")

    path = heaviest_path(tree)
    for i, (name, total_w, self_w) in enumerate(path):
        pct = total_w / total * 100 if total else 0
        indent = "  " * min(i, 30)
        is_app = any(kw.lower() in name.lower() for kw in app_keywords)
        marker = "★" if is_app and not name.startswith("0x") else " "
        ms = total_w / 1_000_000
        print(f"  {ms:8.1f} ms ({pct:5.1f}%) {marker} {indent}{name}")
    print()


def print_app_frames(tree: CallTreeNode, app_keywords: list[str]):
    results: dict[str, int] = {}

    def collect(node: CallTreeNode):
        for name, child in node.children.items():
            if not name.startswith("0x"):
                if any(kw.lower() in name.lower() for kw in app_keywords):
                    results[name] = max(results.get(name, 0), child.total_weight)
            collect(child)

    collect(tree)

    if not results:
        return

    total = tree.total_weight
    print("=" * 90)
    print("APP FRAMES (inclusive weight)")
    print("=" * 90)
    for name, w in sorted(results.items(), key=lambda x: -x[1])[:30]:
        pct = w / total * 100 if total else 0
        ms = w / 1_000_000
        print(f"  {ms:8.1f} ms ({pct:5.1f}%) {name}")
    print()


def print_hottest_functions(samples, total_weight):
    leaf_weights: dict[str, int] = defaultdict(int)
    for _, weight, frames in samples:
        if frames:
            leaf_weights[frames[0]] += weight

    print("=" * 90)
    print("HOTTEST FUNCTIONS (self time)")
    print("=" * 90)
    for name, w in sorted(leaf_weights.items(), key=lambda x: -x[1])[:25]:
        pct = w / total_weight * 100 if total_weight else 0
        ms = w / 1_000_000
        print(f"  {ms:8.1f} ms ({pct:5.1f}%) {name}")
    print()


def main():
    parser = argparse.ArgumentParser(description="Analyze Instruments .trace heaviest stack trace")
    parser.add_argument("trace", help="Path to .trace file/bundle")
    parser.add_argument(
        "--thread", default=None,
        help='Filter to a specific thread (e.g. "Main Thread"). Default: show all.',
    )
    parser.add_argument(
        "--app-keywords", default="",
        help='Comma-separated keywords to identify app frames (e.g. "xWallet,Cell,ViewController")',
    )
    args = parser.parse_args()

    app_keywords = [k.strip() for k in args.app_keywords.split(",") if k.strip()]
    if not app_keywords:
        # Try to infer from trace file name
        import re
        name = args.trace.rsplit("/", 1)[-1].replace(".trace", "")
        name = re.sub(r"\d+$", "", name)
        if name:
            app_keywords = [name]

    print(f"Exporting time-profile from: {args.trace}")
    root = export_time_profile(args.trace)
    samples = parse_rows(root)
    print(f"Total samples: {len(samples)}")

    total_weight = sum(w for _, w, _ in samples)
    print(f"Total weight:  {total_weight / 1_000_000:.1f} ms\n")

    # Thread distribution
    print_thread_distribution(samples, total_weight)

    # Build call trees (xctrace gives leaf-first, reverse for root-first)
    all_tree = CallTreeNode("ROOT")
    main_tree = CallTreeNode("ROOT")
    filtered_tree = CallTreeNode("ROOT") if args.thread else None

    for tname, weight, frames in samples:
        reversed_frames = list(reversed(frames))
        all_tree.add_stack(reversed_frames, weight)
        if "Main Thread" in tname:
            main_tree.add_stack(reversed_frames, weight)
        if filtered_tree and args.thread and args.thread in tname:
            filtered_tree.add_stack(reversed_frames, weight)

    # Hottest functions
    print_hottest_functions(samples, total_weight)

    # Heaviest stack traces
    if filtered_tree and filtered_tree.total_weight > 0:
        print_heaviest_stack(filtered_tree, f'Thread: "{args.thread}"', app_keywords)
        print_app_frames(filtered_tree, app_keywords)
    else:
        if main_tree.total_weight > 0:
            print_heaviest_stack(main_tree, "Main Thread", app_keywords)
            print_app_frames(main_tree, app_keywords)
        print_heaviest_stack(all_tree, "All Threads", app_keywords)


if __name__ == "__main__":
    main()
