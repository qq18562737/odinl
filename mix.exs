defmodule Odinl.MixProject do
  use Mix.Project

  def project do
    [
      app: :odinl,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:mnesia_kv, git: "https://github.com/xenomorphtech/mnesia_kv.git"},
      {:ex_actors, git: "https://github.com/xenomorphtech/ex_actors"},
      # {:tz, "~> 0.26.2"},
      {:mitm, git: "https://github.com/xenomorphtech/mitm_ex.git"},
      {:exjsx, "4.0.0"},
      {:utilex,
       git:
         "https://gitlab+deploy-token-3565493:7QsqgYuA1EcKQU7eRUEn@gitlab.com/xenomorph-colonies/utilex.git"}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
