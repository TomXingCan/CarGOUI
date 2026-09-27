# CarGOUI — description draft, not uploaded

CarGOUI is a Retail reminder addon with a standalone `/cui` settings window.

- Mobility reminders stay hidden while an admitted ability is available and show its real next-availability countdown when depleted.
- Timed Proc digits sit over the corresponding Blizzard screen graphic, using verified effect mappings and native timing. Multiple regions retain their own positions and optional RGB colors.
- Time Spiral's confirmed free-use effect displays **Free move**, with coordinates independent from ordinary Mobility.
- Mobility settings belong to each class. Proc fonts belong to each class and specialization. Automatic faction Headers and class/spec Body themes require no manual selection.
- Import / Export shares current-class or all-saved settings through a copyable string, with validation, an impact summary, confirmation and a recoverable last-import backup.
- Options closes safely in combat; a combat opening request is deferred once until combat ends. Sliders update immediately and numerical edits save on Enter.

Install both **CarGOUI** and **CarGOUI_Data**. The internal Data addon loads automatically. Existing SavedVariables should be kept when upgrading.

This **1.0.0-rc.2** candidate adds Options drag-session safeguards and retains the admitted Proc implementation for Mage and the other reviewed classes. Native pickup behavior remains pending client regression. Coverage is based on eligible finite effects with native graphics; it does not mean every specialization has a timer. Exact mappings and limitations are listed in the source repository's Proc and Mobility coverage documents.

Target: Retail 12.1 / Interface 120100; existing source audits pin build 69933. This is not a claim that every class/talent has been tested in a live client, that resource use is zero, or that Blizzard has certified the addon. Final native-codec and gameplay acceptance remains pending. Preview samples are clearly marked and isolated from live effects.

This text is a draft only. No CurseForge project upload or formal Release is authorized by this RC task. Confirm the distribution license and final acceptance before publishing.
