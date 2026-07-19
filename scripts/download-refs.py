"""Download the 5 new references from arXiv into Document/references/."""
import os
import sys
import urllib.request

REFS = [
    ("11_Pearce_2022_Asleep_at_the_Keyboard.pdf", "https://arxiv.org/pdf/2108.09293.pdf"),
    ("12_Khoury_2023_How_Secure_is_Code_Generated_by_ChatGPT.pdf", "https://arxiv.org/pdf/2304.09655.pdf"),
    ("13_Sandoval_2023_Lost_at_C.pdf", "https://arxiv.org/pdf/2208.09727.pdf"),
    ("14_Hou_2024_LLMs_for_Software_Engineering_SLR.pdf", "https://arxiv.org/pdf/2308.10620.pdf"),
    ("15_Lenarduzzi_2020_Are_SonarQube_Rules_Inducing_Bugs.pdf", "https://arxiv.org/pdf/2001.10143.pdf"),
]

OUT_DIR = "Document/references"

def download(filename, url):
    path = os.path.join(OUT_DIR, filename)
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (research)"})
    with urllib.request.urlopen(req, timeout=60) as resp:
        data = resp.read()
    with open(path, "wb") as f:
        f.write(data)
    size_kb = round(len(data) / 1024, 1)
    print(f"  OK  {filename}  ({size_kb} KB)")
    return len(data)

def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    total = 0
    for name, url in REFS:
        try:
            total += download(name, url)
        except Exception as e:
            print(f"  FAIL {name}: {e}")
    print(f"Total: {round(total/1024, 1)} KB")

if __name__ == "__main__":
    main()
