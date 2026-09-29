# Artwork tint controls

The Custom artwork card groups the existing color source, native ColorPicker swatch, desaturation and opacity. The desaturation control no longer requires opening Advanced. The existing current-Proc artwork choice supports recoloring the native shape without selecting another asset.

No color model or saved field is added. Blizzard event color remains `appearance.artColor=nil`; Custom color remains its finite RGB object. Desaturation and opacity display 0–100% while storing the existing `appearance.desaturation` and `appearance.alpha` values from 0 to 1. Their defaults remain 0 and 1. Intermediate desaturation retains some original color; full desaturation removes original color before tinting. Texture brightness and transparency still affect the result, so the selected RGB does not promise a uniform flat color. These explanations are present in all eight supported locales.

Native mode keeps Blizzard's presentation. Recoloring this Proc's shape requires Custom mode with the current-Proc artwork choice. Timer Only draws neither native nor replacement artwork for that region and keeps the native timer. Both modes hide the unrelated artwork card under the existing mode rules.

The native picker keeps the existing guarded session. Drafts affect only the selected artwork presentation, never the database/export or Timer RGB. Cancel restores the saved artwork color; Okay commits to the original valid target. Numeric changes made during a picker session are independent saved edits: canceling its color draft does not undo desaturation or opacity. Region/page/close/spec/combat boundaries retain their cancellation and stale-callback checks. Artwork Reset resets appearance only, preserving Timer XY/RGB and specialization typography.

Pure tint changes update the existing owned rendering without releasing native suppression or replaying unchanged entrance motion. Existing animation choices preserve native suppression too, while a changed preset restarts owned motion according to its new settings. Missing required public evidence still fails open, and actual faults retain the existing Proc safety boundary. Mode/asset/Reset continue through their full cleanup path. This distinction protects a previous native source that can remain in its short fade after another source becomes current for the region.

## Regression and client acceptance

Offline checks cover current/selected assets, 0/partial/full desaturation, opacity endpoints, picker draft/cancel/commit, Timer/sibling isolation, saved reload and Reset, supported locales and card geometry. They inspect owned texture parameters and public native ownership checkpoints; they do not simulate shader pixels or establish native font metrics.

In a fresh Retail session, confirm Native first, then use Custom with this Proc's original artwork. Try blue, green and purple at 0/50/100% desaturation, then lower opacity with animation enabled. Test Cancel and Okay separately, alongside a Native sibling. Acquire, consume and reacquire the real Proc during each relevant transition. The replaced region must not expose native artwork while its custom texture changes; Native/disable must restore it. Repeat with preview active and after closing it. Retain contemporaneous diagnostics and video for any remaining flash or quarantine.

The functional Custom replacement gate remains separate from #15 memory acceptance. A passing offline tint test neither closes that issue nor proves the reported Warlock consumption flash is fixed. See [PROC_SUPPRESSION_ACCEPTANCE.md](PROC_SUPPRESSION_ACCEPTANCE.md) for callback and animation evidence, and [NUMERIC_CONTROLS.md](NUMERIC_CONTROLS.md) for precise numeric interaction.
