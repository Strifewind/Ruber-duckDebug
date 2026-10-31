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
    {:ok, assign(socket, page_title: "Debug together", prompt_index: 0, selected_role: nil)}
  end

  @impl true
  def handle_event("select_role", %{"role" => role}, socket) do
    {:noreply, assign(socket, selected_role: role, page_title: "#{role} — Debug together")}
  end

  def handle_event("leave_role", _params, socket) do
    {:noreply, assign(socket, selected_role: nil, page_title: "Debug together")}
  end

  def handle_event("next_prompt", _params, socket) do
    {:noreply, update(socket, :prompt_index, &rem(&1 + 1, length(@prompts)))}
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :duck_prompt, Enum.at(@prompts, assigns.prompt_index))

    ~H"""
    <Layouts.app flash={@flash}>
      <.quackula_style />

      <%= if @selected_role do %>
        <.role_screen role={@selected_role} duck_prompt={@duck_prompt} prompt_index={@prompt_index} />
      <% else %>
        <.landing />
      <% end %>
    </Layouts.app>
    """
  end

  defp quackula_style(assigns) do
    ~H"""
    <style>
      @keyframes spookyFloat {
        0%   { transform: translateY(0px) translateX(0px) rotate(0deg); }
        33%  { transform: translateY(-8px) translateX(3px) rotate(-2deg); }
        66%  { transform: translateY(-3px) translateX(-3px) rotate(2deg); }
        100% { transform: translateY(0px) translateX(0px) rotate(0deg); }
      }
    </style>
    """
  end

  defp quackula_svg(assigns) do
    ~H"""
    <svg width={@size} height={@size} viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg"
         style="animation: spookyFloat 3s ease-in-out infinite; filter: drop-shadow(0 0 10px rgba(255,0,0,0.3)); flex-shrink: 0;">
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
    """
  end

  defp landing(assigns) do
    ~H"""
    <section aria-labelledby="welcome-heading" class="space-y-6">
      <p class="text-sm font-semibold uppercase tracking-wide text-base-content">
        Three players. One shared investigation.
      </p>
      <h1 id="welcome-heading" class="text-4xl font-bold">Debug together with the duck</h1>
      <p class="text-lg">
        Practice explaining code, sharing evidence, and testing hypotheses in a cooperative
        debugging game.
      </p>
    </section>

    <section aria-labelledby="roles-heading" class="space-y-4 pt-8">
      <h2 id="roles-heading" class="text-2xl font-semibold">Choose your role</h2>
      <div class="grid gap-4 sm:grid-cols-3">
        <button phx-click="select_role" phx-value-role="Driver"
                class="rounded-box border border-success/30 bg-success/5 p-4 text-left hover:border-success/60 hover:bg-success/10 transition-colors cursor-pointer">
          <h3 class="text-xl font-semibold text-success">Driver</h3>
          <p class="mt-1 text-sm">Explain the source code, edit it, and request validation checks.</p>
        </button>
        <button phx-click="select_role" phx-value-role="Observer"
                class="rounded-box border border-warning/30 bg-warning/5 p-4 text-left hover:border-warning/60 hover:bg-warning/10 transition-colors cursor-pointer">
          <h3 class="text-xl font-semibold text-warning">Observer</h3>
          <p class="mt-1 text-sm">Describe symptoms, reproduction steps, and the results of experiments.</p>
        </button>
        <button phx-click="select_role" phx-value-role="Researcher"
                class="rounded-box border border-error/30 bg-error/5 p-4 text-left hover:border-error/60 hover:bg-error/10 transition-colors cursor-pointer">
          <h3 class="text-xl font-semibold text-error">Researcher</h3>
          <p class="mt-1 text-sm">Use references to propose a hypothesis and a testable experiment.</p>
        </button>
      </div>
    </section>

    <section aria-labelledby="duck-home-heading" class="space-y-4 rounded-box bg-base-200 p-6 mt-8">
      <div class="flex items-center gap-6">
        <.quackula_svg size="80" />
        <div>
          <h2 id="duck-home-heading" class="text-2xl font-semibold">Quackula</h2>
          <p class="text-sm text-error font-mono animate-pulse">JUDGING YOUR CODE... 🧛‍♂️🦆</p>
        </div>
      </div>
      <p class="text-base-content/70">Your AI game master. Pick a role above and Quackula will guide you toward the bug — one cryptic question at a time.</p>
    </section>
    """
  end

  defp role_screen(%{role: "Driver"} = assigns) do
    ~H"""
    <.role_header role="Driver" color="success" label="Driver" />
    <section class="space-y-4 pt-6">
      <h2 class="text-xl font-semibold">Your view: the code</h2>
      <p class="text-base-content/70 text-sm">Only you can see the source. Explain what you see — don't just read it aloud.</p>
      <div class="rounded-box bg-base-200 p-4 font-mono text-sm text-base-content/80 whitespace-pre">
        # [Challenge code will appear here once rooms are wired up]
      </div>
    </section>
    <.quackula_panel duck_prompt={@duck_prompt} />
    """
  end

  defp role_screen(%{role: "Observer"} = assigns) do
    ~H"""
    <.role_header role="Observer" color="warning" label="Observer" />
    <section class="space-y-4 pt-6">
      <h2 class="text-xl font-semibold">Your view: the symptoms</h2>
      <p class="text-base-content/70 text-sm">Only you know what went wrong. Describe it precisely — no peeking at the code.</p>
      <div class="rounded-box bg-base-200 p-4 text-sm text-base-content/80">
        [Bug report / symptoms will appear here once rooms are wired up]
      </div>
    </section>
    <.quackula_panel duck_prompt={@duck_prompt} />
    """
  end

  defp role_screen(%{role: "Researcher"} = assigns) do
    ~H"""
    <.role_header role="Researcher" color="error" label="Researcher" />
    <section class="space-y-4 pt-6">
      <h2 class="text-xl font-semibold">Your view: the references</h2>
      <p class="text-base-content/70 text-sm">You have the docs and context. Form a hypothesis and propose an experiment.</p>
      <div class="rounded-box bg-base-200 p-4 text-sm text-base-content/80">
        [Reference materials will appear here once rooms are wired up]
      </div>
    </section>
    <.quackula_panel duck_prompt={@duck_prompt} />
    """
  end

  defp role_header(assigns) do
    ~H"""
    <div class="flex items-center justify-between">
      <div class="flex items-center gap-3">
        <span class={"badge badge-lg badge-#{@color} font-semibold"}>{@label}</span>
        <h1 class="text-2xl font-bold">Debug together with the duck</h1>
      </div>
      <button phx-click="leave_role" class="btn btn-ghost btn-sm">← Change role</button>
    </div>
    """
  end

  defp quackula_panel(assigns) do
    ~H"""
    <section aria-labelledby="duck-heading" class="space-y-4 rounded-box bg-base-200 p-6 mt-6">
      <div class="flex items-center gap-6">
        <.quackula_svg size="80" />
        <div>
          <h2 id="duck-heading" class="text-2xl font-semibold">Quackula</h2>
          <p class="text-sm text-error font-mono animate-pulse">JUDGING YOUR CODE... 🧛‍♂️🦆</p>
        </div>
      </div>
      <p id="duck-prompt" aria-live="polite" class="text-lg font-medium">{@duck_prompt}</p>
      <button id="next-prompt" phx-click="next_prompt" class="btn btn-primary">
        Another question
      </button>
    </section>
    """
  end
end
