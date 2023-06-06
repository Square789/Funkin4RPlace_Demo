#!/usr/bin/env python3
from argparse import ArgumentParser
from os.path import splitext
from pathlib import Path
import sys

import numpy as np
from PIL import Image

IntPoint = tuple[int, int]


def crop_image(arr: np.ndarray) -> tuple[np.ndarray, IntPoint, IntPoint]:
	# Whereever alpha > 0
	content_space_arr = arr[:, :, 3] > 0
	valid_line_indices = content_space_arr.any(axis=1).nonzero()[0]
	valid_row_indices = content_space_arr.any(axis=0).nonzero()[0]
	if valid_line_indices.size == 0 or valid_row_indices.size == 0:
		return np.array([[[0, 0, 0, 0]]])

	hcrop_start = valid_line_indices.min()
	hcrop_end = valid_line_indices.max()
	vcrop_start = valid_row_indices.min()
	vcrop_end = valid_row_indices.max()

	crop_start = (vcrop_start, hcrop_start)
	crop_end = (vcrop_end, hcrop_end)

	return arr[hcrop_start:hcrop_end+1, vcrop_start:vcrop_end+1], crop_start, crop_end

def is_image(p: Path) -> bool:
	return p.suffix == ".png"

def run(source_dir: Path, target_dir: Path, overwrite_existing: bool):
	existing_crops = {p.name for p in target_dir.iterdir() if is_image(p)}

	for path in source_dir.iterdir():
		if path.is_dir() or not is_image(path):
			continue

		crop_path = target_dir / path.name
		if not overwrite_existing and path.name in existing_crops:
			print(f"Skipping {path.name}, cropped variant exists already.")
			continue

		img = Image.open(path)
		img_array = np.asarray(img)
		cropped_img, crop_start, crop_end = crop_image(img_array)
		shape_difference = (
			(img_array.shape[0] - cropped_img.shape[0]),
			(img_array.shape[1] - cropped_img.shape[1]),
		)
		print(
			f"Cropped {path.name} from {img_array.shape[:2]} to {cropped_img.shape[:2]}. "
			f"Top-left crop start: {crop_start}"
		)
		Image.fromarray(cropped_img).save(crop_path)

def make_absolute_path(p: str) -> Path:
	return Path(p).expanduser().resolve().absolute()

def main() -> int:
	ap = ArgumentParser()
	ap.add_argument("-i", "--in", default=None, dest="source")
	ap.add_argument("-o", "--out", default=None, dest="target")
	ap.add_argument("-f", "--overwrite", action="store_true")

	if len(sys.argv) < 2:
		ap.print_help()
		return 2

	argns = ap.parse_args()
	source = argns.source
	target = argns.target
	if source is None:
		if target is None:
			print("Neither source nor target specified, adieu.")
			return 1
		else:
			source = Path.cwd()
			target = make_absolute_path(target)
	else:
		if target is None:
			source = make_absolute_path(source)
			target = Path.cwd()
		else:
			source = make_absolute_path(source)
			target = make_absolute_path(target)

	if target == source:
		print("Can't use same directory as source and target")
		return 1

	run(source, target, argns.overwrite)
	return 0

if __name__ == "__main__":
	sys.exit(main())


