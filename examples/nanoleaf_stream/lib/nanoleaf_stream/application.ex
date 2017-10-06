defmodule NanoleafStream.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    import Supervisor.Spec
    # List all child processes to be supervised
    children = [
      worker(NanoleafStream.Streamer, [])
      # Starts a worker by calling: NanoleafStream.Worker.start_link(arg)
      # {NanoleafStream.Worker, arg},
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: NanoleafStream.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
