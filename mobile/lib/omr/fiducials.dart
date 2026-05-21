// Phase-3 TODO: locate the three printed fiducial squares.
//
// The PDF generator draws 22x22 pt filled black squares at the page corners
// (top-left, top-right, bottom-left). After perspective warp they sit at
// known fractional coordinates. Use these to:
//   - Verify orientation (which corner is missing → BR; rotate as needed).
//   - Compute the affine transform from "design coords" to "pixel coords"
//     so the bubble grid can be sampled accurately.
