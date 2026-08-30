# Test Images

Real test-set photos used for `HandRemover` regression checks (see
`HandRemoverTests.swift`).

- Source: BuyNothing cutout test set (13 tools, 13 USB cables, 12 books, 12 tech,
  all hand-held), one spread sample per category: `tools_03/07/11`,
  `usbcable_03/07/11`, `books_03/06/09`, `tech_03/06/09`.
- Resized to max edge 1200px, JPEG quality 85.
  (1200px is chosen because HandRemover's absolute `minComponentPixels` threshold is tuned
  for full/app-resolution photos; at 600px the small-object photos (e.g. usbcable_07) fall
  under the threshold and produce an empty mask. 1200px stays within the algorithm's
  intended operating scale — the Python reference caps its working size at 1500px.)
