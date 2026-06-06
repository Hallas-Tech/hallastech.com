#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from datetime import date
from pathlib import Path

from jinja2 import Environment, FileSystemLoader, select_autoescape


ROOT = Path(__file__).resolve().parents[1]


def load_json(path: Path) -> dict:
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def render_site(content_path: Path, template_name: str, output_path: Path) -> None:
    content = load_json(content_path)
    content["build_year"] = date.today().year

    environment = Environment(
        loader=FileSystemLoader(ROOT / "templates"),
        autoescape=select_autoescape(["html", "xml"]),
        trim_blocks=True,
        lstrip_blocks=True,
    )
    template = environment.get_template(template_name)
    output_path.write_text(template.render(**content), encoding="utf-8")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Render the static Hallas Tech website.")
    parser.add_argument(
        "--content",
        type=Path,
        default=ROOT / "content" / "site.json",
        help="Path to the site content JSON file.",
    )
    parser.add_argument(
        "--template",
        default="index.html.j2",
        help="Template filename under the templates directory.",
    )
    parser.add_argument(
        "--out",
        type=Path,
        default=ROOT / "index.html",
        help="Output HTML path.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    render_site(args.content, args.template, args.out)
    print(f"Rendered {args.out}")


if __name__ == "__main__":
    main()
