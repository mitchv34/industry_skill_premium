"""Utilities for IPUMS API extract scripts."""

from __future__ import annotations

import argparse
import gzip
import json
import shutil
import sys
import time
from pathlib import Path
from typing import Iterable

from ipumspy import IpumsApiClient, MicrodataExtract, save_extract_as_json

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.append(str(ROOT))

import config  # noqa: E402


def make_client() -> IpumsApiClient:
    api_key = config.get_ipums_api_key()
    if not api_key:
        raise RuntimeError("Missing IPUMS API key. Set IPUMS_API_KEY or pass insert api/ipums.")
    return IpumsApiClient(api_key)


def extract_signature(extract: MicrodataExtract) -> dict[str, object]:
    built = extract.build()
    return {
        "collection": built["collection"],
        "dataFormat": built["dataFormat"],
        "dataStructure": built["dataStructure"],
        "samples": sorted(built["samples"].keys()),
        "variables": sorted(built["variables"].keys()),
    }


def previous_extract_signature(extract_definition: dict) -> dict[str, object]:
    return {
        "collection": extract_definition["collection"],
        "dataFormat": extract_definition["dataFormat"],
        "dataStructure": extract_definition["dataStructure"],
        "samples": sorted(extract_definition["samples"].keys()),
        "variables": sorted(extract_definition["variables"].keys()),
    }


def find_matching_previous_extract(
    client: IpumsApiClient,
    extract: MicrodataExtract,
    limit: int = 100,
) -> int | None:
    target = extract_signature(extract)
    previous = client.get_previous_extracts(extract.collection, limit=limit)
    for item in previous.get("data", []):
        definition = item.get("extractDefinition", {})
        if previous_extract_signature(definition) == target:
            return int(item["number"])
    return None


def submit_or_reuse_extract(
    client: IpumsApiClient,
    extract: MicrodataExtract,
    reuse_limit: int,
    force_submit: bool,
) -> MicrodataExtract:
    if not force_submit:
        previous_id = find_matching_previous_extract(client, extract, limit=reuse_limit)
        if previous_id is not None:
            reused = client.get_extract_by_id(previous_id, extract.collection)
            reused._id = previous_id
            reused._info = client.get_extract_info(previous_id, extract.collection)
            return reused
    return client.submit_extract(extract)


def wait_for_completion(
    client: IpumsApiClient,
    extract: MicrodataExtract,
    poll_seconds: int,
    timeout_seconds: int,
) -> str:
    start = time.monotonic()
    while True:
        status = client.extract_status(extract)
        print(f"IPUMS {extract.collection} extract {extract.extract_id}: {status}")
        if status in {"completed", "failed", "not found"}:
            return status
        if time.monotonic() - start >= timeout_seconds:
            return status
        time.sleep(poll_seconds)


def normalize_download_names(
    download_dir: Path,
    prefix: str,
    extract_id: int,
) -> tuple[Path | None, Path | None]:
    data_path = None
    ddi_path = None
    for path in download_dir.iterdir():
        name = path.name.lower()
        if not name.startswith(f"{prefix}_extract_{extract_id}"):
            if name.endswith((".csv.gz", ".dat.gz", ".xml")) and f"_{extract_id}" in name:
                pass
            else:
                continue
        if name.endswith(".xml"):
            target = download_dir / f"{prefix}_extract_{extract_id}.xml"
            if path != target:
                path.replace(target)
            ddi_path = target
        elif name.endswith(".csv.gz"):
            target = download_dir / f"{prefix}_extract_{extract_id}.csv.gz"
            if path != target:
                path.replace(target)
            data_path = target
        elif name.endswith(".dat.gz"):
            target = download_dir / f"{prefix}_extract_{extract_id}.dat.gz"
            if path != target:
                path.replace(target)
            data_path = target
    return data_path, ddi_path


def download_and_rename(
    client: IpumsApiClient,
    extract: MicrodataExtract,
    download_dir: Path,
    prefix: str,
) -> tuple[Path | None, Path | None]:
    before = {p.name for p in download_dir.iterdir()} if download_dir.exists() else set()
    download_dir.mkdir(parents=True, exist_ok=True)
    client.download_extract(extract, download_dir=download_dir)
    new_paths = [p for p in download_dir.iterdir() if p.name not in before]
    for path in new_paths:
        suffixes = "".join(path.suffixes)
        if suffixes.endswith(".csv.gz"):
            path.replace(download_dir / f"{prefix}_extract_{extract.extract_id}.csv.gz")
        elif suffixes.endswith(".dat.gz"):
            path.replace(download_dir / f"{prefix}_extract_{extract.extract_id}.dat.gz")
        elif path.suffix == ".xml":
            path.replace(download_dir / f"{prefix}_extract_{extract.extract_id}.xml")
    return normalize_download_names(download_dir, prefix, extract.extract_id)


def count_rows(path: Path | None) -> int | None:
    if path is None or not path.exists() or path.suffixes[-2:] != [".csv", ".gz"]:
        return None
    with gzip.open(path, "rt", encoding="utf-8", errors="replace") as handle:
        return max(sum(1 for _ in handle) - 1, 0)


def save_metadata(extract: MicrodataExtract, metadata_path: Path) -> None:
    metadata_path.parent.mkdir(parents=True, exist_ok=True)
    try:
        save_extract_as_json(extract, str(metadata_path))
    except Exception:
        metadata_path.write_text(json.dumps(extract.build(), indent=2) + "\n")
    signature_path = metadata_path.with_suffix(".signature.json")
    signature_path.write_text(json.dumps(extract_signature(extract), indent=2) + "\n")


def run_extract(
    extract: MicrodataExtract,
    prefix: str,
    metadata_path: Path,
    args: argparse.Namespace,
) -> dict[str, object]:
    client = make_client()
    save_metadata(extract, metadata_path)
    if args.extract_id is not None:
        submitted = client.get_extract_by_id(args.extract_id, extract.collection)
        submitted._id = args.extract_id
        submitted._info = client.get_extract_info(args.extract_id, extract.collection)
    else:
        submitted = submit_or_reuse_extract(
            client,
            extract,
            reuse_limit=args.reuse_limit,
            force_submit=args.force_submit,
        )
    save_metadata(submitted, metadata_path)
    status = client.extract_status(submitted)
    data_path = None
    ddi_path = None
    rows = None

    if not args.submit_only:
        status = wait_for_completion(
            client,
            submitted,
            poll_seconds=args.poll_seconds,
            timeout_seconds=args.timeout_seconds,
        )
        if status == "completed":
            data_path, ddi_path = download_and_rename(
                client,
                submitted,
                download_dir=args.download_dir,
                prefix=prefix,
            )
            rows = count_rows(data_path)

    print(
        f"{prefix}: extract={submitted.extract_id} status={status} "
        f"data={data_path} ddi={ddi_path} rows={rows}"
    )
    return {
        "prefix": prefix,
        "extract_id": submitted.extract_id,
        "status": status,
        "data_path": str(data_path) if data_path else None,
        "ddi_path": str(ddi_path) if ddi_path else None,
        "rows": rows,
    }


def add_common_args(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--download-dir", type=Path, default=config.PATH_RAW_CPS)
    parser.add_argument("--metadata-dir", type=Path, default=Path("scripts/data_fetch"))
    parser.add_argument("--extract-id", type=int, help="Resume an already-submitted extract")
    parser.add_argument("--submit-only", action="store_true")
    parser.add_argument("--force-submit", action="store_true")
    parser.add_argument("--reuse-limit", type=int, default=100)
    parser.add_argument("--poll-seconds", type=int, default=60)
    parser.add_argument("--timeout-seconds", type=int, default=6 * 60 * 60)


def as_list(values: Iterable[str]) -> list[str]:
    return list(dict.fromkeys(values))
