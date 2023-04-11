defmodule Construct.Mixfile do
  use Mix.Project

  def project do
    [
      app: :construct,
      version: "3.0.1",
      elixir: "~> 1.9",
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env),
      consolidate_protocols: Mix.env() != :test,
      dialyzer: [
        plt_file: {:no_warn, "_build/dialyzer.plt"}
      ],

      # Tests
      test_coverage: [tool: ExCoveralls],

      # Hex
      description: description(),
      package: package(),

      # Docs
      name: "Construct",
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: []
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:decimal, "~> 1.6 or ~> 2.0", only: [:dev, :test]},
      {:benchee, "~> 1.0", only: [:dev, :test]},
      {:dialyxir, "~> 1.1.0", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.28", only: :dev},
      {:jason, "~> 1.3", only: :test},
      {:excoveralls, "~> 0.14", only: :test}
    ]
  end

  defp description do
    "Library for dealing with data structures"
  end

  defp package do
    [
      name: :construct,
      maintainers: ["Yuri Artemev", "Alexander Malaev"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/ExpressApp/construct"}
    ]
  end

  defp docs do
    [
      main: "readme",
      source_url: "https://github.com/ExpressApp/construct",
      extras: ["README.md"],
      groups_for_modules: [
        "Provided types": [
          Construct.Types.CommaList,
          Construct.Types.Enum,
          Construct.Types.UUID
        ]
      ]
    ]
  end
end
