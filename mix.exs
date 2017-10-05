defmodule Nanoleaf.Mixfile do
  use Mix.Project

  def project do
    [
      app: :nanoleaf,
      version: "0.1.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :ssdp, :httpoison],
      mod: {Nanoleaf.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ssdp, "~> 0.2.0"},
      {:httpoison, "~> 0.13.0"},
      {:poison, "~> 3.1"}
    ]
  end
end
