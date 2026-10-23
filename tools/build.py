"""Test the current source, then build the addon and a separate source/tool package."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "NextReminders"
DIST = ROOT / "dist"


def digest(content):
    return hashlib.sha256(content).hexdigest()


def build():
    files = sorted(p for p in SOURCE.iterdir() if p.suffix in (".lua", ".toc"))
    toc = (SOURCE / "NextReminders.toc").read_text(encoding="utf-8")
    listed = [line.strip() for line in toc.splitlines() if line.strip() and not line.startswith("##")]
    if len(listed) != len(set(listed)) or set(listed) != {p.name for p in files if p.suffix == ".lua"}:
        raise ValueError("TOC/source file list mismatch")
    version = re.search(r"^## Version:\s*(\S+)",toc,re.M)[1]
    if not re.fullmatch(r"\d+\.\d+\.\d+(?:-[\w.-]+)?",version): raise ValueError("Invalid release version")
    core = (SOURCE / "Core.lua").read_text(encoding="utf-8")
    if f'NR.version = "{version}"' not in core: raise ValueError("Core/TOC version mismatch")
    documentation = [ROOT/name for name in ("README.md","LICENSE","requirements-dev.txt")]
    documentation += sorted(p for p in (ROOT/"docs").glob("*.md") if p.name != "HANDOFF.md")
    documentation += sorted((ROOT/"docs").glob("ui-*.html")) + sorted((ROOT/"docs").glob("ui-*.png"))
    media = sorted(p for p in (SOURCE/"Media").glob("*") if p.suffix in (".ogg",".mp3",".tga"))
    if not (SOURCE/"Media"/"burst_meow.ogg").exists(): raise ValueError("Voice pack Media/burst_meow.ogg missing")
    inputs = files + media + documentation + [ROOT/"CONTEXT.md"]
    inputs += sorted(p for p in (ROOT/"tools").glob("*") if p.suffix in (".py",".mjs"))
    inputs += sorted((ROOT/"tests").glob("*.py"))
    inputs += sorted(p for p in (ROOT/"web").rglob("*") if p.is_file() and p.suffix in (".html",".css",".mjs",".json",".png",".jpg",".jpeg",".webp",".svg",".ico"))
    inputs += sorted((ROOT/"docs/research").glob("*.md"))
    snapshot = {str(p.relative_to(ROOT)).replace("\\","/"):p.read_bytes() for p in inputs}

    with tempfile.TemporaryDirectory() as temporary:
        report_path = Path(temporary)/"checks.json"
        env = os.environ.copy(); env["PYTHONIOENCODING"] = "utf-8"
        check = subprocess.run([sys.executable,str(ROOT/"tests/check.py"),"--report",str(report_path)],
                               cwd=ROOT,env=env,capture_output=True,text=True,encoding="utf-8")
        output = check.stdout + check.stderr
        print(output, end="")
        if check.returncode or not report_path.exists(): raise ValueError("Checks failed; no new package built")
        report = json.loads(report_path.read_text(encoding="utf-8"))
        if report["STATIC"] != "PASS" or report["MOCK"] != "PASS" or report["skipped"]:
            raise ValueError("Required checks failed or were skipped")
        if any(p.read_bytes() != snapshot[str(p.relative_to(ROOT)).replace("\\","/")] for p in inputs):
            raise ValueError("Source changed during checks; rebuild required")
        addon_payload = {"NextReminders/"+p.name:snapshot["NextReminders/"+p.name] for p in files}
        addon_payload.update({"NextReminders/Media/"+p.name:snapshot["NextReminders/Media/"+p.name] for p in media})
        addon_payload.update({"NextReminders/README.md":snapshot["README.md"],"NextReminders/LICENSE":snapshot["LICENSE"]})
        names = {f"NextReminders-{version}.zip":addon_payload, f"NextReminders-source-{version}.zip":snapshot}
        staged = {}
        for name,payload in names.items():
            path = Path(temporary)/name
            with zipfile.ZipFile(path,"w",zipfile.ZIP_DEFLATED) as archive:
                for member,content in sorted(payload.items()): archive.writestr(member,content)
            with zipfile.ZipFile(path) as archive:
                if set(archive.namelist()) != set(payload) or any(archive.read(k) != v for k,v in payload.items()):
                    raise ValueError("Archive content mismatch")
            staged[name] = path
        manifest = {
            "version":version, "builtAt":datetime.now(timezone.utc).isoformat(), "source_review":"PENDING",
            **report, "packages":{name:{"sha256":digest(path.read_bytes()),"bytes":path.stat().st_size} for name,path in staged.items()},
            "files":{name:digest(content) for name,content in sorted(snapshot.items())},
        }
        DIST.mkdir(exist_ok=True)
        for name,path in staged.items(): os.replace(path,DIST/name)
        (DIST/"checks.log").write_text(output,encoding="utf-8")
        (DIST/"manifest.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
        for name in staged: print(DIST/name)
        print("执行者自检完成，待 Advisor 验收。LIVE NOT_RUN。")


if __name__ == "__main__":
    try: build()
    except (OSError,ValueError,KeyError,TypeError) as error: raise SystemExit(str(error))
