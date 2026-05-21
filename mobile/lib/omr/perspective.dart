// Phase-3 TODO: paper-edge detection + perspective warp.
//
// Plan:
//   - Convert frame to grayscale.
//   - Gaussian blur 5x5.
//   - Adaptive threshold (inverted).
//   - Find contours, keep the largest 4-point polygon.
//   - Order corners (TL, TR, BR, BL).
//   - Warp to canonical A4 ratio (e.g. 1240x1754 px).
//
// Library choices:
//   - Pure Dart: `image` package supports threshold + simple ops; warp must be
//     implemented manually with a 3x3 homography.
//   - Or wrap OpenCV via `opencv_dart` (FFI) for warpPerspective.
