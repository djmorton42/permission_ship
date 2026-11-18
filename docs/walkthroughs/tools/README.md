# Walkthrough tools

Scripts that build the HTML walkthroughs in `docs/walkthroughs/`. They use Python 3 and git only.

| File | Content |
| --- | --- |
| `walkthrough.py` | The `Walkthrough` class. It quotes code from one git commit, so the excerpts match the code exactly. |
| `template.html` | The page: styles, contents rail, code highlighting and Mermaid diagrams. |
| `<date>-<topic>.py` | The text of one walkthrough. |

## Build a walkthrough

```sh
python3 docs/walkthroughs/tools/2026-11-17-login-and-foundations.py
```

The script writes `docs/walkthroughs/<date>-<topic>.html`. Commit the HTML file and the script together.

## Write a new walkthrough

1. Copy an existing content script. Give it the date and topic of the new walkthrough.
2. Set `commit` to the commit that the walkthrough describes.
3. Write the sections. In a section, `code(path, lang, start, end)` quotes the lines from the first line that contains `start` to the next line that contains `end`. Paths start at the repo root.
4. Build the page, open it in a browser, and add it to the table in `docs/walkthroughs/README.md`.
