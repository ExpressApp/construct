defmodule Construct.Mixfile do
  use Mix.Project

  def project do
    [
      app: :construct,
      version: "2.1.10",
      elixir: "~> 1.5",
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env),
      dialyzer: [
        plt_file: {:no_warn, "_build/dialyzer.plt"}
      ],

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
      {:decimal, "~> 1.5", only: [:dev, :test]},
      {:benchfella, "~> 0.3", only: [:dev, :test]},
      {:dialyxir, "~> 1.0.0-rc.7", only: [:dev, :test], runtime: false},
      {:earmark, "~> 1.2", only: :dev},
      {:ex_doc, "~> 0.19", only: :dev},
      {:jason, "~> 1.1", only: :test}
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
      extras: ["README.md"]
    ]
  end
end
