"""Writes llms.txt (what the site covers, with a link to every page) and llms-full.txt (all doc pages
in one markdown file) into the built site, for AI tools that read the docs."""

import os

_pages = {}
_order = []


def on_nav(nav, config, files):
    _order.clear()
    _order.extend(page.file.src_uri for page in nav.pages)
    return nav


def on_page_markdown(markdown, page, config, files):
    _pages[page.file.src_uri] = (page.title, page.url, page.meta.get("description", ""), markdown)
    return markdown


def on_post_build(config):
    site = config["site_url"].rstrip("/") + "/"
    summary = [f"# {config['site_name']}", "", f"> {config['site_description']}", "", "## Docs", ""]
    full = [f"# {config['site_name']}", "", config["site_description"], ""]
    for uri in _order:
        if uri not in _pages:
            continue
        title, url, description, markdown = _pages[uri]
        link = site + url
        summary.append(f"* [{title}]({link})" + (f": {description}" if description else ""))
        # The playground page is the web app itself, with no prose to include.
        if uri != "playground.md":
            full += ["", f"Source: {link}", "", markdown.strip(), ""]
    summary += ["", "## Full text", "", f"* [All doc pages in one file]({site}llms-full.txt)", ""]
    for name, lines in (("llms.txt", summary), ("llms-full.txt", full)):
        with open(os.path.join(config["site_dir"], name), "w", encoding="utf-8") as file:
            file.write("\n".join(lines).rstrip() + "\n")
