"""Builds an HTML walkthrough. Code excerpts come from one git commit, so they match the code exactly.

A content script makes a Walkthrough, adds sections, and calls render. See README.md in this directory.
"""

import html
import subprocess
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
REPO = Path(subprocess.run(["git", "-C", str(TOOLS), "rev-parse", "--show-toplevel"],
                           capture_output=True, text=True, check=True).stdout.strip())


class Walkthrough:
    def __init__(self, commit, title, header):
        self.commit = commit
        self.title = title
        self.header = header
        self.sections = []

    def source(self, path):
        """The file at the walkthrough's commit. Path is relative to the repo root."""
        return subprocess.run(["git", "-C", str(REPO), "show", f"{self.commit}:{path}"],
                              capture_output=True, text=True, check=True).stdout

    def excerpt(self, path, start=None, end=None, extra=0):
        """Lines from the first line that contains start to the next line that contains end, plus extra lines.
        Without start, the whole file. Returns the text and the first line number."""
        lines = self.source(path).rstrip("\n").split("\n")
        if start is None:
            return "\n".join(lines), 1
        i = next(n for n, line in enumerate(lines) if start in line)
        if end is None:
            j = len(lines) - 1
        else:
            j = next(n for n, line in enumerate(lines) if n > i and end in line) + extra
        return "\n".join(lines[i:j + 1]), i + 1

    def code(self, path, lang, start=None, end=None, note=None, extra=0):
        """A code figure with an excerpt from the commit."""
        body, first = self.excerpt(path, start, end, extra)
        label = path if start is None else f"{path} · from line {first}"
        note_html = f'<p class="code-note">{note}</p>' if note else ""
        return (f'<figure class="code"><figcaption><span class="path">{html.escape(label)}</span></figcaption>'
                f'<div class="scroll"><pre><code class="language-{lang}">{html.escape(body)}</code></pre></div>'
                f'{note_html}</figure>')

    def raw(self, text, lang, label):
        """A code figure with text that is not in the repo, for example command output."""
        return (f'<figure class="code"><figcaption><span class="path">{html.escape(label)}</span></figcaption>'
                f'<div class="scroll"><pre><code class="language-{lang}">{html.escape(text.strip())}</code></pre></div></figure>')

    def section(self, id, num, title, body):
        self.sections.append((id, num, title, body))

    def render(self, out):
        toc = "\n".join(f'<li><a href="#{i}"><span class="n">{n}</span>{t}</a></li>' for i, n, t, _ in self.sections)
        body = "\n".join(f'<section id="{i}"><h2><span class="n">{n}</span>{t}</h2>{b}</section>'
                         for i, n, t, b in self.sections)
        page = ((TOOLS / "template.html").read_text()
                .replace("{{TITLE}}", html.escape(self.title))
                .replace("{{HEADER}}", self.header)
                .replace("{{TOC}}", toc)
                .replace("{{BODY}}", body))
        Path(out).write_text(page)
