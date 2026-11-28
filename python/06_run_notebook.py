"""
AV-Ready-Saudi - execute the results notebook in place (step 8 of the pipeline).

The notebook notebooks/av_ready_saudi_results.ipynb makes every figure and table of the paper's Results section
(docs/paper/figures/*.png, docs/paper/tables/*.csv) from the outputs of this run, and checks that it reproduces
python/05_readiness_model.py. Running it here keeps the saved notebook, its figures and the run in step.
Usage: python3 python/06_run_notebook.py [path/to/notebook.ipynb]
Needs: nbformat, nbclient, ipykernel (in requirements.txt).
"""
from __future__ import annotations

import sys
import time
from pathlib import Path

import nbformat
from nbclient import NotebookClient

ROOT = Path(__file__).resolve().parents[1]


def main() -> int:
    nb_path = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else ROOT / "notebooks" / "av_ready_saudi_results.ipynb"
    nb = nbformat.read(nb_path, as_version=4)
    t0 = time.time()
    # "python3" resolves to the kernel of the Python running this script (the project's .venv)
    NotebookClient(nb, timeout=1200, kernel_name="python3",
                   resources={"metadata": {"path": str(nb_path.parent)}}).execute()
    nbformat.write(nb, nb_path)
    print(f"executed {nb_path.relative_to(ROOT)} in {time.time() - t0:.0f} s "
          f"(figures: docs/paper/figures/, tables: docs/paper/tables/)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
