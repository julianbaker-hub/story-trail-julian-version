# StoryTrail concept library

This directory is the product and experience knowledge base for StoryTrail. Each concept is a Markdown document so it
stays readable in GitHub, code review, and any text editor. A concept may also attach a small interactive explainer.

## Browse the library

Run:

```sh
make concepts
```

Then open <http://localhost:8000> to browse the directory and open the Markdown sources. For formatted articles,
read the files in GitHub or a Markdown editor. `manifest.json` lists the concepts in reading order.
The local server works without external packages or network access.

This archive contains the concept documents; its original browser and optional interactive files were not included.

Run `make concepts-check` to validate the manifest, required metadata, and interactive paths.

## Add a concept

1. Create a Markdown file in this directory.
2. Add its relative path to `manifest.json`.
3. Start the file with this front matter:

```yaml
---
title: A useful, specific title
summary: One sentence that helps someone decide whether to open it.
category: Experience
status: Exploring
interactive: interactives/example.html
---
```

The `interactive` field is optional. When present, it must be a relative path inside this directory. The interactive
should be a self-contained HTML document, use native controls, work at narrow widths, and not depend on the network.
Include a normal Markdown link to it as a fallback for readers outside the concept browser.

Allowed statuses are `Exploring`, `Proposed`, `Validated`, and `Adopted`. A concept explains a durable decision or mental
model; implementation details that change with a single release belong in source comments or feature documentation.
