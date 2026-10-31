defmodule RuberDuckDebug.Challenges do
  @moduledoc "Small, reproducible Python challenges for offline play."

  def get(round) do
    Enum.at(all(), rem(round - 1, length(all())))
  end

  def all do
    [
      %{
        "title" => "The missing parcel",
        "objective" =>
          "Calculate the total weight of every parcel in a list. Empty lists total zero.",
        "function" => "parcel_total",
        "code" =>
          "def parcel_total(weights):\n    total = 0\n    for i in range(len(weights) - 1):\n        total += weights[i]\n    return total\n",
        "solution" => "def parcel_total(weights):\n    return sum(weights)\n",
        "documentation" =>
          "range(stop) produces integers from 0 up to, but excluding, stop. len(values) is the number of items. sum(values) totals numeric items and returns 0 for an empty list.",
        "symptoms" =>
          "A shipment with weights [2, 3, 5] reports 5 instead of 10. A single parcel weighing 7 reports 0.",
        "explanation" =>
          "The loop stops before the last parcel. range(len(weights)) visits every valid index; sum(weights) also solves the task.",
        "hint" => "Ask which input positions the loop actually visits.",
        "tests" => [
          %{"args" => [[2, 3, 5]], "expected" => 10},
          %{"args" => [[7]], "expected" => 7},
          %{"args" => [[]], "expected" => 0},
          %{"args" => [[0, 4, 0, 9]], "expected" => 13}
        ]
      },
      %{
        "title" => "The velvet rope",
        "objective" =>
          "Return True when age is at least the minimum age; otherwise return False.",
        "function" => "can_enter",
        "code" => "def can_enter(age, minimum):\n    return age > minimum\n",
        "solution" => "def can_enter(age, minimum):\n    return age >= minimum\n",
        "documentation" =>
          "Python comparisons return booleans. > means strictly greater; >= means greater than or equal. Boundary values are useful experiments.",
        "symptoms" =>
          "Guests older than the minimum enter correctly, but a guest exactly at the minimum is turned away.",
        "explanation" =>
          "The original comparison excluded equality. The requirement includes people exactly at the minimum age.",
        "hint" => "Test the exact boundary, then compare it with a value on each side.",
        "tests" => [
          %{"args" => [18, 18], "expected" => true},
          %{"args" => [17, 18], "expected" => false},
          %{"args" => [21, 18], "expected" => true},
          %{"args" => [0, 0], "expected" => true}
        ]
      },
      %{
        "title" => "Averages gone adrift",
        "objective" =>
          "Return the arithmetic mean of a numeric list, or 0 when the list is empty. Preserve fractional results.",
        "function" => "average",
        "code" =>
          "def average(values):\n    if len(values) == 0:\n        return 0\n    return sum(values) // len(values)\n",
        "solution" =>
          "def average(values):\n    if len(values) == 0:\n        return 0\n    return sum(values) / len(values)\n",
        "documentation" =>
          "The / operator performs true division. The // operator performs floor division. A mean is sum(values) divided by len(values). Handle empty input before dividing.",
        "symptoms" =>
          "The average of [2, 3] is reported as 2, although it should be 2.5. Whole-number averages seem correct.",
        "explanation" =>
          "Floor division discards the fractional part by rounding down. True division preserves fractional means.",
        "hint" => "Choose an example whose correct result is not a whole number.",
        "tests" => [
          %{"args" => [[2, 3]], "expected" => 2.5},
          %{"args" => [[]], "expected" => 0},
          %{"args" => [[4, 4]], "expected" => 4},
          %{"args" => [[-2, -3]], "expected" => -2.5}
        ]
      }
    ]
  end
end
