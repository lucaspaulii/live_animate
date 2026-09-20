defmodule DevWeb.AppWeb.Playground.Studies do
  @moduledoc """
  Data-driven catalog of the production edge cases the harness reproduces
  (see `demo-playground-plan.md` §4). Keeping these as data means the playground
  *is* the documentation — each harness renders its study card from here, so the
  docs can't drift from the thing being demonstrated.
  """

  @studies %{
    destroy_leak: %{
      title: "destroyed() cleanup & leaks",
      what:
        "Removing a motion element must run destroyed(): clear the loop timer, run all _cleanups, disconnect observers, and untrack FLIP.",
      why_risky:
        "Leaked IntersectionObservers, event listeners, or an orphaned setTimeout loop accumulate over a long session.",
      how_to_trigger:
        "Spawn a batch of elements (in_view + loop + hover + layout all set), then destroy them. Repeat several cycles.",
      expected:
        "After Clear all, the FLIP-tracking map returns to 0 and mounted-hook count returns to baseline; nothing climbs monotonically across cycles.",
      failure: "Counters climb every cycle → a leak to fix before rollout.",
      code_refs: ["assets/js/live_animate.js:257 (destroyed)", "assets/js/live_animate.js:477 (IntersectionObserver)"]
    },
    exit_race: %{
      title: "Exit animation race (rapid add/remove)",
      what:
        "Exit uses the phx-remove transition binding (time = duration + 50) plus a MutationObserver on the lm-animating-exit class.",
      why_risky:
        "Removing many elements in one batch, or re-adding an element with the same id mid-exit, can race the observer or strand a position:fixed clone.",
      how_to_trigger: "Add a batch, then Remove all (fast); or Remove + re-add same id, which re-adds 50ms into the exit.",
      expected: "Every exiting element animates out and is fully removed; no ghost fixed clones; the re-added id animates in cleanly.",
      failure: "Leftover fixed-position ghosts, elements that vanish with no exit, or a re-added id that never animates.",
      code_refs: ["assets/js/live_animate.js:326 (_setupExit)", "assets/js/live_animate.js:355 (exit observer)"]
    },
    stream_lifecycle: %{
      title: "Streams — insert / delete / reset / limit",
      what:
        "phx-update=\"stream\" adds/removes/moves elements client-side. Stream reflows move siblings without firing the hook's updated(), and stagger is computed once from sibling index at mount.",
      why_risky:
        "stream_delete mid-animation, stream reset, and a :limit that drops off-screen items each interact with entrance/exit/stagger/FLIP. New items may miss their entrance, or get the wrong stagger.",
      how_to_trigger: "Prepend / append single items, delete a random one, reset the whole stream, and overflow a limited stream.",
      expected:
        "New items get an entrance; deleted items get an exit; limit-dropped items are removed cleanly; reset clears and re-enters. Reorders FLIP instead of jumping.",
      failure: "Missing entrance on streamed items, wrong/duplicated stagger, exit skipped on delete, or FLIP jumping on reflow.",
      code_refs: ["assets/js/live_animate.js:187 (stagger at mount)", "assets/js/live_animate.js:366 (stream reflow note)"]
    }
  }

  @doc "Fetch a study by key."
  def get(key), do: Map.fetch!(@studies, key)
end
