# Loss Surface Golden Reference

This directory freezes the approved visual layout for the OPQ 4-lane
burstiness-vs-rate loss contour. The stored analytical/proxy render is a style
reference only; current math-report evidence must use data emitted by HDL
simulation.

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
- Place the color-bar label to the right of the bar, vertically mirrored
  relative to a left-side label; place the color-bar tick labels to the left of
  the bar.
- Use logarithmic spacing for the color-bar ticks with probability labels
  `1`, `1e-1`, `1e-2`, `1e-3`, `1e-4`, `1e-5`, `1e-6`.
- Keep a visible whitespace gap between the color bar and its tick-value text;
  the tick labels must not visually touch or overlap the bar.
- Make higher loss darker.
- Fill the plot body with a continuous log-loss gradient over the full sampled
  phase-space rectangle, not only contour bands.
- Keep the x/y axis limits matched to that sampled phase-space rectangle so
  there is no empty white margin inside the axis frame.
- Keep the color bar vertically aligned to the plot body's y-span.
- Do not add a second inset color bar inside the plot body.
- Use three interior reference contours:
  `0.000001` dotted and labelled `1e-6`, `0.010` dashed and labelled `1%`,
  and `0.050` solid and labelled `5%`.
- Put compact inline loss-probability labels on those reference contours, with
  the contour stroke broken underneath the text and no filled label box.
- Keep inline labels clear of grid lines and other plotted strokes; move the
  label along the isoline if a grid line would cross through the characters.
- Keep the main contour transition in a visually central interior region, not
  hugging a border.
- User-defined mnemonic to preserve for this figure: "the contour should be in
  the golden ratio region, 3.1415926".

Use this golden reference as the visual baseline when iterating this figure in
the future, but replace the underlying grid with real RTL simulation data
before promoting any plot into `MATH_REPORT.md`.
