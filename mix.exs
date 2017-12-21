defmodule Struct.Mixfile do
  use Mix.Project

  def project do
    [app: :struct,
     version: "1.0.0-rc.1",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     test_coverage: [tool: ExCoveralls],
     preferred_cli_env: preferred_cli_env(),
     description: description(),
     package: package(),
     deps: deps()]
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

  defp deps do
    [{:decimal, "~> 1.3.1", only: [:dev, :test]},
     {:benchfella, "~> 0.3.3", only: [:dev, :test]},
     {:excoveralls, "~> 0.5", only: :test},
     {:earmark, "~> 1.0.1", only: :dev},
     {:ex_doc, "~> 0.13.0", only: :dev}]
  end

  defp description do
    "Library for dealing with data structures"
  end

  defp package do
    [name: :struct,
     files: ["lib", "mix.exs"],
     maintainers: ["Yuri Artemev"],
     licenses: ["MIT"],
     links: %{"GitHub" => "https://github.com/artemeff/struct"}]
  end
end
