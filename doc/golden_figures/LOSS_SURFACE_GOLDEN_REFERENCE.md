# Loss Surface Golden Reference

This directory freezes the approved reference render for the OPQ 4-lane
burstiness-vs-rate loss contour.

Reference assets:
- `loss_surface_contour_golden.png`
- `loss_surface_contour_golden.svg`

Source render path:
- `tb/REPORT/math/loss_surface_contour.png`
- `tb/REPORT/math/loss_surface_contour.svg`

Accepted figure rules:
- Keep only the short title above the figure.
- Put definitions and method notes in a smaller caption below the plot.
- Show the rate axis in percent, not only as a raw `0.xx` fraction.
- Keep the color-bar label as the physical quantity `loss probability`.
- Use logarithmic spacing for the color-bar ticks with probability labels
  `1`, `1e-1`, `1e-2`, `1e-3`, `1e-4`.
- Keep a visible whitespace gap between the color bar and its tick-value text;
  the tick labels must not visually touch or overlap the bar.
- Make higher loss darker.
- Keep the color bar vertically aligned to the plot body's y-span.
- Use three interior reference contours:
  `0.002` dotted, `0.005` dashed, `0.010` solid.
- Keep the main contour transition in a visually central interior region, not
  hugging a border.
- User-defined mnemonic to preserve for this figure: "the contour should be in
  the golden ratio region, 3.1415926".

Use this golden reference as the visual baseline when iterating this figure in
the future.
