#!/usr/bin/env python3


from __future__ import annotations

import argparse
import html
import re
import sys
from dataclasses import dataclass, field
from html.parser import HTMLParser
from pathlib import Path
from typing import Iterable
from urllib.request import Request, urlopen


DEFAULT_BASE_URL = "https://wiki.archerage.to/ru-en/db/items"
DEFAULT_OUTPUT = Path(__file__).with_name("archerage_armors_first3.txt")
DEFAULT_CRAFT_URLS = [
    "https://wiki.archerage.to/ru-en/db/crafts",
    "https://wiki.archerage.to/ru-en/db/crafts/group/10000",
    "https://wiki.archerage.to/ru-en/db/crafts/group/8000000",
    "https://wiki.archerage.to/ru-en/db/crafts/group/9000000",
]


@dataclass
class Cell:
    text_parts: list[str] = field(default_factory=list)
    image_srcs: list[str] = field(default_factory=list)

    @property
    def text(self) -> str:
        return " ".join(" ".join(self.text_parts).split())


@dataclass
class Row:
    cells: list[Cell] = field(default_factory=list)


class ItemsTableParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.in_items_table = False
        self.in_tbody = False
        self.current_row: Row | None = None
        self.current_cell: Cell | None = None
        self.rows: list[Row] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        attrs_dict = dict(attrs)

        if tag == "table" and attrs_dict.get("id") == "items-list":
            self.in_items_table = True
            return

        if not self.in_items_table:
            return

        if tag == "tbody":
            self.in_tbody = True
        elif self.in_tbody and tag == "tr":
            self.current_row = Row()
        elif self.current_row is not None and tag == "td":
            self.current_cell = Cell()
        elif self.current_cell is not None and tag == "img":
            src = attrs_dict.get("src")
            if src:
                self.current_cell.image_srcs.append(src)

    def handle_endtag(self, tag: str) -> None:
        if not self.in_items_table:
            return

        if tag == "table":
            self.in_items_table = False
            self.in_tbody = False
        elif tag == "tbody":
            self.in_tbody = False
        elif tag == "td" and self.current_cell is not None and self.current_row is not None:
            self.current_row.cells.append(self.current_cell)
            self.current_cell = None
        elif tag == "tr" and self.current_row is not None:
            if self.current_row.cells:
                self.rows.append(self.current_row)
            self.current_row = None
            self.current_cell = None

    def handle_data(self, data: str) -> None:
        if self.current_cell is not None:
            text = data.strip()
            if text:
                self.current_cell.text_parts.append(text)


def fetch_html(url: str) -> str:
    request = Request(
        url,
        headers={
            "User-Agent": (
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/125.0 Safari/537.36"
            )
        },
    )
    with urlopen(request, timeout=60) as response:
        charset = response.headers.get_content_charset() or "utf-8"
        return response.read().decode(charset, errors="replace")


def read_html(args: argparse.Namespace) -> tuple[str, str]:
    if args.from_file:
        path = Path(args.from_file)
        return path.read_text(encoding="utf-8", errors="replace"), str(path)

    url = f"{args.base_url.rstrip('/')}/{args.category.strip('/')}"
    return fetch_html(url), url


def normalize_icon_path(srcs: Iterable[str]) -> str:
    for raw_src in srcs:
        src = html.unescape(raw_src).replace("\\", "/")
        if "item_grade_" in src:
            continue

        icons_index = src.find("/icons/")
        if icons_index >= 0:
            return src[icons_index + 1 :]

        match = re.search(r"([^/?#]+\.dds\.png)(?:[?#].*)?$", src)
        if match:
            return f"icons/{match.group(1)}"

        return src

    return ""


def parse_items(source_html: str) -> list[tuple[str, str, str, str]]:
    parser = ItemsTableParser()
    parser.feed(source_html)

    items: list[tuple[str, str, str, str]] = []
    for row in parser.rows:
        if len(row.cells) < 6:
            continue

        item_id = row.cells[0].text
        name = row.cells[2].text
        icon_path = normalize_icon_path(row.cells[1].image_srcs)
        category = row.cells[5].text

        if item_id.isdigit() and name:
            items.append((item_id, name, icon_path, category))

    return items


def write_output(items: Iterable[tuple[str, str, str, str]], output: Path) -> int:
    output.parent.mkdir(parents=True, exist_ok=True)
    count = 0
    with output.open("w", encoding="utf-8", newline="\n") as handle:
        for item_id, name, icon_path, category in items:
            clean_name = " ".join(name.replace(";", ",").split())
            clean_category = " ".join(category.replace(";", ",").split())
            handle.write(f"{item_id};{clean_name};{icon_path};{clean_category}\n")
            count += 1
    return count


def lua_quote(value: str) -> str:
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def parse_craft_rows(source_html: str) -> list[tuple[str, str]]:
    pattern = re.compile(
        r'<a\s+href="/ru-en/db/crafts/(\d+)"[^>]*data-model-type="craft"[^>]*>\s*'
        r"\d+\s*</a>.*?"
        r'<a\s+href="/ru-en/db/crafts/\1"[^>]*data-model-type="craft"[^>]*>\s*'
        r"(.*?)\s*</a>",
        re.IGNORECASE | re.DOTALL,
    )
    rows: list[tuple[str, str]] = []
    for craft_id, raw_name in pattern.findall(source_html):
        clean_name = " ".join(html.unescape(re.sub(r"<[^>]+>", "", raw_name)).split())
        if clean_name:
            rows.append((craft_id, clean_name))
    return rows


def read_item_type_csv(path: Path) -> dict[str, str]:
    item_types: dict[str, str] = {}
    if not path.exists():
        return item_types
    with path.open("r", encoding="utf-8", errors="replace") as handle:
        for line in handle:
            parts = line.rstrip("\n").split(";")
            if len(parts) >= 2 and parts[0].isdigit() and parts[1]:
                item_types.setdefault(parts[1], parts[0])
    return item_types


def write_crafts_lua(crafts: Iterable[tuple[str, str]], item_types: dict[str, str], output: Path) -> int:
    output.parent.mkdir(parents=True, exist_ok=True)
    merged: dict[str, dict[str, str]] = {}
    for craft_id, name in crafts:
        entry = merged.setdefault(name, {})
        entry["craftType"] = craft_id
        if name in item_types:
            entry["itemType"] = item_types[name]

    with output.open("w", encoding="utf-8", newline="\n") as handle:
        handle.write("-- Generated by z_trash/scrape_archerage_items.py --crafts-lua\n")
        handle.write("AutoShopCraftIndex = {\n")
        for name in sorted(merged):
            entry = merged[name]
            parts = [f"craftType = {entry['craftType']}"]
            if "itemType" in entry:
                parts.append(f"itemType = {entry['itemType']}")
            handle.write(f"\t[{lua_quote(name)}] = {{ {', '.join(parts)} }},\n")
        handle.write("}\n\n")
        handle.write("AutoShopItemTypes = {\n")
        for name in sorted(item_types):
            handle.write(f"\t[{lua_quote(name)}] = {item_types[name]},\n")
        handle.write("}\n")
    return len(merged)


def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Scrape ArcheRage wiki item IDs, names, and icon paths."
    )
    parser.add_argument(
        "--category",
        default="armors",
        help="Item category path under /db/items, e.g. armors, weapons, costumes.",
    )
    parser.add_argument(
        "--pages",
        type=int,
        default=3,
        help="How many DataTables pages to export. Use 0 to export every row found.",
    )
    parser.add_argument(
        "--per-page",
        type=int,
        default=10,
        help="Rows per DataTables page. The wiki defaults to 10.",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=DEFAULT_OUTPUT,
        help=f"Output file path. Default: {DEFAULT_OUTPUT}",
    )
    parser.add_argument(
        "--base-url",
        default=DEFAULT_BASE_URL,
        help=f"Base wiki items URL. Default: {DEFAULT_BASE_URL}",
    )
    parser.add_argument(
        "--from-file",
        help="Optional saved HTML file to parse instead of fetching the live wiki.",
    )
    parser.add_argument(
        "--crafts-lua",
        action="store_true",
        help="Export AutoShopCraftIndex.lua from the ArcheRage craft list pages.",
    )
    parser.add_argument(
        "--craft-url",
        action="append",
        default=[],
        help="Craft list URL to include. May be passed multiple times.",
    )
    parser.add_argument(
        "--item-type-csv",
        type=Path,
        default=Path(__file__).with_name("materials_en_raw.csv"),
        help="Optional semicolon CSV with item id and name columns to add itemType values.",
    )
    return parser


def main() -> int:
    args = build_arg_parser().parse_args()
    if args.crafts_lua:
        urls = args.craft_url or DEFAULT_CRAFT_URLS
        crafts: list[tuple[str, str]] = []
        for url in urls:
            source_html = fetch_html(url)
            rows = parse_craft_rows(source_html)
            print(f"{url}: {len(rows)} craft rows")
            crafts.extend(rows)
        item_types = read_item_type_csv(args.item_type_csv)
        count = write_crafts_lua(crafts, item_types, args.output)
        print(f"Wrote craft index rows: {count}")
        print(f"Output: {args.output}")
        return 0

    if args.pages < 0:
        print("--pages must be 0 or greater", file=sys.stderr)
        return 2
    if args.per_page <= 0:
        print("--per-page must be greater than 0", file=sys.stderr)
        return 2

    source_html, source = read_html(args)
    items = parse_items(source_html)
    limit = None if args.pages == 0 else args.pages * args.per_page
    selected_items = items[:limit]
    count = write_output(selected_items, args.output)

    print(f"Source: {source}")
    print(f"Found rows: {len(items)}")
    print(f"Wrote rows: {count}")
    print(f"Output: {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
