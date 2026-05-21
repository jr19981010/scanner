// Phase-3 TODO: bubble sampling.
//
// Inputs:
//   - The perspective-corrected, fiducial-aligned image.
//   - The bubble layout used by the PDF generator (must match exactly):
//       columns of 25 items × choices, fixed pitch, fixed bubble radius.
//
// For each (item_no, choice_index):
//   - Compute the ROI center in pixel coords.
//   - Crop a small box around the bubble.
//   - Count pixels darker than threshold T (Otsu or fixed ~120).
//   - dark_ratio = dark_px / total_px.
//
// Decision per item:
//   - max_ratio > FILL_THRESHOLD (0.45)
//     AND (max_ratio - second_max_ratio) > MARGIN (0.15)
//     → choice index with max_ratio
//   - else → -1 (blank / ambiguous; surface in the result screen).
