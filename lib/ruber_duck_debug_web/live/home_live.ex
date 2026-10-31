defmodule RuberDuckDebugWeb.HomeLive do
  use RuberDuckDebugWeb, :live_view

  @prompts [
    "What evidence supports that hypothesis?",
    "What would you expect to observe if your hypothesis is correct?",
    "What is the smallest experiment that could disprove your hypothesis?",
    "How does the observed behavior differ from the expected behavior?"
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Debug together", prompt_index: 0)}
  end

  @impl true
  def handle_event("next_prompt", _params, socket) do
    {:noreply, update(socket, :prompt_index, &rem(&1 + 1, length(@prompts)))}
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :duck_prompt, Enum.at(@prompts, assigns.prompt_index))

    ~H"""
    <Layouts.app flash={@flash}>
      <section aria-labelledby="welcome-heading" class="space-y-6">
        <p class="text-sm font-semibold uppercase tracking-wide text-base-content">
          Three players. One shared investigation.
        </p>
        <h1 id="welcome-heading" class="text-4xl font-bold">Debug together with the duck</h1>
        <p class="text-lg">
          Practice explaining code, sharing evidence, and testing hypotheses in a cooperative
          debugging game.
        </p>
        <p class="rounded-box bg-base-200 p-4">
          Application template: multiplayer rooms and private challenge materials are not enabled yet.
        </p>
      </section>

      <section aria-labelledby="roles-heading" class="space-y-4 pt-8">
        <h2 id="roles-heading" class="text-2xl font-semibold">Everyone has a part to play</h2>
        <div class="grid gap-4 sm:grid-cols-3">
          <article id="role-driver" class="rounded-box border border-base-300 p-4">
            <h3 class="text-xl font-semibold">Driver</h3>
            <p>Explain the source code, edit it, and request validation checks.</p>
          </article>
          <article id="role-observer" class="rounded-box border border-base-300 p-4">
            <h3 class="text-xl font-semibold">Observer</h3>
            <p>Describe symptoms, reproduction steps, and the results of experiments.</p>
          </article>
          <article id="role-researcher" class="rounded-box border border-base-300 p-4">
            <h3 class="text-xl font-semibold">Researcher</h3>
            <p>Use references to propose a hypothesis and a testable experiment.</p>
          </article>
        </div>
      </section>

      <section aria-labelledby="duck-heading" class="space-y-4 rounded-box bg-base-200 p-6">
        <h2 id="duck-heading" class="text-2xl font-semibold">Ask the duck</h2>
        <p>The duck asks questions, not answers. This preview uses local prompts, not an AI service.</p>
        <p id="duck-prompt" aria-live="polite" class="text-lg font-medium">{@duck_prompt}</p>
        <button id="next-prompt" phx-click="next_prompt" class="btn btn-primary">
          Another question
        </button>
        <p class="text-sm">Prompts in this preview belong to your session, not a shared room.</p>
      </section>

      <section aria-labelledby="round-heading" class="space-y-4 pt-8">
        <h2 id="round-heading" class="text-2xl font-semibold">The cooperative round</h2>
        <ol class="list-decimal space-y-2 pl-6">
          <li>Assign roles and deliver each player's private materials.</li>
          <li>The observer describes symptoms; the driver explains the relevant code.</li>
          <li>The researcher proposes a hypothesis and an experiment.</li>
          <li>The driver edits and runs checks; the observer receives the results.</li>
          <li>Revise the hypothesis together or submit a solution.</li>
          <li>Reveal the full challenge in a debrief, then rotate roles.</li>
        </ol>
        <p>Text conversation and an optional round timer keep the focus on cooperation.</p>
      </section>
    </Layouts.app>
    """
  end
end
