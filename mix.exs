defmodule Construct.Mixfile do
  use Mix.Project

  def project do
    [app: :construct,
     version: "1.0.1",
     elixir: "~> 1.3",
     deps: deps(),
     test_coverage: [tool: ExCoveralls],
     preferred_cli_env: preferred_cli_env(),
     elixirc_paths: elixirc_paths(Mix.env),

     # Hex
     description: description(),
     package: package(),

     # Docs
     name: "Construct",
     docs: docs()]
  end

  def application do
    [applications: []]
  end

  defp preferred_cli_env do
    ["coveralls": :test,
     "coveralls.detail": :test,
     "coveralls.post": :test,
     "coveralls.html": :test]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [{:decimal, "~> 1.3.1", only: [:dev, :test]},
     {:benchfella, "~> 0.3.3", only: [:dev, :test]},
     {:excoveralls, "~> 0.8.0", only: :test},
     {:earmark, "~> 1.2.4", only: :dev},
     {:ex_doc, "~> 0.18.1", only: :dev}]
  end

  defp description do
    "Library for dealing with data structures"
  end

  defp package do
    [
      name: :construct,
      files: ["lib", "mix.exs"],
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
