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
          <article id="role-driver" class="rounded-box border border-success/30 bg-success/5 p-4">
            <h3 class="text-xl font-semibold text-success">Driver</h3>
            <p>Explain the source code, edit it, and request validation checks.</p>
          </article>
          <article id="role-observer" class="rounded-box border border-warning/30 bg-warning/5 p-4">
            <h3 class="text-xl font-semibold text-warning">Observer</h3>
            <p>Describe symptoms, reproduction steps, and the results of experiments.</p>
          </article>
          <article id="role-researcher" class="rounded-box border border-error/30 bg-error/5 p-4">
            <h3 class="text-xl font-semibold text-error">Researcher</h3>
            <p>Use references to propose a hypothesis and a testable experiment.</p>
          </article>
        </div>
      </section>

      <section aria-labelledby="duck-heading" class="space-y-4 rounded-box bg-base-200 p-6">
        <div class="flex items-center gap-6">
          <svg width="100" height="100" viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg" style="animation: spookyFloat 3s ease-in-out infinite; filter: drop-shadow(0 0 10px rgba(255,0,0,0.3)); flex-shrink: 0;">
            <path d="M60,140 Q100,180 140,140 L160,180 L40,180 Z" fill="#4a0404" />
            <path d="M60,120 Q60,80 100,80 Q140,80 140,120 Q140,160 100,160 Q60,160 60,120" fill="#F0E68C" stroke="#8B8000" stroke-width="3"/>
            <path d="M70,90 L60,50 L100,80 L140,50 L130,90 Z" fill="#000" stroke="#4a0404" stroke-width="2"/>
            <circle cx="110" cy="75" r="30" fill="#F0E68C" stroke="#8B8000" stroke-width="3"/>
            <path d="M130,75 L150,75 L135,85 Z" fill="#FF8C00" stroke="#8B8000" stroke-width="2"/>
            <path d="M132,82 L134,86 L136,82 Z" fill="white" />
            <path d="M138,82 L140,86 L142,82 Z" fill="white" />
            <circle cx="120" cy="68" r="4" fill="#2d0000"/>
            <path d="M70,110 Q100,100 130,110" fill="none" stroke="#000" stroke-width="8" stroke-linecap="round"/>
          </svg>
          <div>
            <h2 id="duck-heading" class="text-2xl font-semibold">Quackula</h2>
            <p class="text-sm text-error font-mono animate-pulse">JUDGING YOUR CODE... 🧛‍♂️🦆</p>
          </div>
        </div>
        <style>
          @keyframes spookyFloat {
            0%   { transform: translateY(0px) translateX(0px) rotate(0deg); }
            33%  { transform: translateY(-8px) translateX(3px) rotate(-2deg); }
            66%  { transform: translateY(-3px) translateX(-3px) rotate(2deg); }
            100% { transform: translateY(0px) translateX(0px) rotate(0deg); }
          }
        </style>
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
