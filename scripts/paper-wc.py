"""Rough word-count for the IEEE paper draft."""
import re

with open("Document/paper/ieee-paper.tex", encoding="utf-8") as f:
    tex = f.read()

m = re.search(r"\\maketitle(.*?)\\begin\{thebibliography\}", tex, re.DOTALL)
body = m.group(1) if m else tex

body = re.sub(r"%.*", "", body)
body = re.sub(r"\\[a-zA-Z]+\*?(\[[^\]]*\])?(\{[^}]*\})?", " ", body)
body = body.replace("{", " ").replace("}", " ").replace("&", " ").replace("\\", " ")

words = re.findall(r"[A-Za-z][A-Za-z\-]+", body)
print("Approx body word count:", len(words))
for s in re.findall(r"\\section\{([^}]+)\}", tex):
    print("  -", s)
print("Ref count:", len(re.findall(r"\\bibitem", tex)))
