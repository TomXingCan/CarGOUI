# Stack-dependent Proc styling: separate research request

The requested outcome is different artwork, color or animation for different stack counts. Merely showing a numeric stack label does not satisfy it.

This is an independent feasibility record, not a production feature or a release dependency. No stack rule, placeholder toggle, generic trigger editor or stack inference is added to 1.0.1.

Three questions require separate target-build audits:

1. Can native `ApplicationCount` / `ApplicationBar` presentation display counts directly under the allowed native binding contract? A native display capability alone does not grant Lua access or arbitrary style selection.
2. Does an individually audited Proc expose distinct, public graphical phases that can legitimately map to specific presentations? Evidence for one Proc cannot be generalized to all Auras or interpreted as an unrestricted stack API.
3. Does the target client provide a supported native declarative mechanism capable of the requested changes of shape, color and animation? Existence of related APIs is not proof that this combination is expressible.

The supplied Demonic Core WARLOCK/266 logs show repeated public SHOW for owner 264173 and texture 2888300. They do not establish that owner/texture parameters distinguish its individual stack counts. The implementation must not count SHOW/HIDE, read native text/visibility/bar values, inspect restricted Aura state, or infer stacks from casts, timing or guesses. Historical WeakAuras behavior is not evidence of present API permission.

Any future proposal must identify the exact build and public contract, demonstrate the desired per-stack styles without restricted readback, and document unsupported cases. This research must not delay the current suppression, numeric-control and tint acceptance work.
