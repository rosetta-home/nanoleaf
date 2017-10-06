defmodule Nanoleaf.Application do

  use Application

  def start(_type, _args) do
    import Supervisor.Spec

    children = [
      worker(Nanoleaf.Client, []),
      supervisor(Nanoleaf.DeviceSupervisor, [])
    ]

    opts = [strategy: :one_for_one, name: Nanoleaf.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
