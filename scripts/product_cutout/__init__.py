"""product_cutout: remove distractors (hands first) from product photos.

Pipeline:
  1. product_region  <- salience model (rembg/u2net): tool + holding hand
  2. conflict        <- broad skin-color test within region (palm, fingers,
                        AND warm-gray tool parts, red ferrules...)
  3. resolve         <- keep conflict parts only if textured (product has
                        seams/text/edges; skin is smooth) AND connected to
                        definite tool (highly saturated product color)
  4. final           <- definite tool + kept conflict, small-comp cleanup
  5. refine (opt)    <- SAM mask-input pass to snap boundaries
  6. feather         <- RGBA output

Distractor list is data-driven: start with "hand", extend to sleeve/arm,
other people, background clutter. See README.md.
"""
