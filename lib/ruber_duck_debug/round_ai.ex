defmodule RuberDuckDebug.RoundAI do
  alias RuberDuckDebug.{Ollama, Runner}
  @moduledoc "Generates verified challenge candidates and evidence-based debriefs."
  @fields ~w(title objective function code solution documentation symptoms explanation hint)
  @context_path Path.expand("../../Context.md", __DIR__)
  @external_resource @context_path
  @context File.read!(@context_path)

  def generate(round \\ 1) do
    properties =
      Map.new(@fields, &{&1, %{"type" => "string", "minLength" => 1, "maxLength" => 8000}})
      |> Map.put("function", %{"type" => "string", "pattern" => "^[a-z][a-z0-9_]{0,40}$"})

    value_schema = %{
      "anyOf" => [
        %{"type" => "number"},
        %{"type" => "boolean"},
        %{"type" => "array", "maxItems" => 16, "items" => %{"type" => "number"}}
      ]
    }

    test_schema = %{
      "type" => "object",
      "properties" => %{
        "args" => %{"type" => "array", "minItems" => 1, "maxItems" => 3, "items" => value_schema},
        "expected" => value_schema
      },
      "required" => ["args", "expected"],
      "additionalProperties" => false
    }

    schema = %{
      "type" => "object",
      "properties" =>
        Map.put(properties, "tests", %{
          "type" => "array",
          "minItems" => 3,
          "maxItems" => 8,
          "items" => test_schema
        }),
      "required" => @fields ++ ["tests"],
      "additionalProperties" => false
    }

    prompt =
      "Round ID: #{round}. Difficulty: beginner. Python 3.12 restricted subset; no libraries, I/O, filesystem, network or external execution. Roles follow the system context. Turn order: Researcher proposes, Driver edits, Observer reviews. No previous-round history. Generate one numeric/list debugging challenge with at least one functional bug. This entire response is PRIVATE application data; the server distributes code to Driver, symptoms to Observer, documentation and objective to Researcher, and keeps solution/tests/explanation hidden until debrief. Return JSON matching this schema: #{Jason.encode!(schema)}. Define exactly one function, no imports, decorators, recursion, attributes, strings, dictionaries, comprehensions or while loops. Use only numeric/boolean values, lists, assignment, if/for, return, indexing, + - * / // %, comparisons and calls to len, sum, min, max, abs, sorted, range. Use tiny inputs; at most 100 iterations. Include a correct solution and at least 3 nonempty test cases including an edge case. Do not include Markdown fences in code. Documentation must explain the relevant Python semantics. Symptoms must contain observed examples without the solution."

    with {:ok, text} <-
           Ollama.chat(
             [
               %{role: "system", content: @context},
               %{role: "user", content: "Example of a complete private challenge package:"},
               %{role: "assistant", content: Jason.encode!(RuberDuckDebug.Challenges.get(1))},
               %{
                 role: "user",
                 content:
                   prompt <>
                     " Generate a different scenario. The function field must contain only the function's identifier, never its signature. Prefer a simple one-line arithmetic/comparison bug with tiny integer inputs. Calculate every expected test result carefully."
               }
             ],
             format: schema
           ),
         {:ok, data} <- Jason.decode(text),
         :ok <- validate_shape(data),
         {:ok, challenge} <- Runner.validate(data) do
      {:ok, challenge}
    else
      {:error, reason} when is_binary(reason) -> {:error, reason}
      _ -> {:error, "Gemma returned an invalid challenge package."}
    end
  end

  def debrief(challenge, record, outcome) do
    # The complete record remains available in the shared debrief UI.
    recent =
      record
      |> Enum.take(-12)
      |> Enum.map(fn event ->
        Map.new(event, fn {key, value} ->
          {key, if(is_binary(value), do: String.slice(value, 0, 1200), else: value)}
        end)
      end)

    summary_challenge = Map.take(challenge, ["title", "objective", "explanation", "solution"])

    prompt =
      "The round has ENDED with confirmed outcome #{outcome}. All challenge data may now be revealed. Write a short plain-text review (no Markdown markup) with Outcome, What went right, What went wrong, How the bug works, and Takeaway. Use only these recorded facts, and do not assume voice dialogue. This is the most recent 12 events; long text is shortened. Acknowledge this limited evidence and do not infer the total number of attempts from it. Challenge: #{Jason.encode!(summary_challenge)}. Events: #{Jason.encode!(recent)}"

    Ollama.chat([%{role: "system", content: @context}, %{role: "user", content: prompt}])
  end

  defp validate_shape(data) when is_map(data) do
    invalid = Enum.reject(@fields, &(is_binary(data[&1]) and byte_size(data[&1]) in 1..8000))

    cond do
      invalid != [] ->
        {:error, "Gemma returned empty or oversized fields: #{Enum.join(invalid, ", ")}."}

      not Regex.match?(~r/^[a-z][a-z0-9_]{0,40}$/, data["function"]) ->
        {:error, "Gemma returned an invalid function name."}

      not is_list(data["tests"]) or length(data["tests"]) not in 3..8 ->
        {:error, "Gemma must return 3–8 tests."}

      not Enum.all?(
        data["tests"],
        &(is_map(&1) and is_list(&1["args"]) and Map.has_key?(&1, "expected"))
      ) ->
        {:error, "Gemma returned invalid test arguments."}

      true ->
        :ok
    end
  end

  defp validate_shape(_), do: {:error, "Expected a challenge object."}
end
