defmodule Nanoleaf.DeviceSupervisor do
  use Supervisor
  require Logger

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    children = [
      worker(Nanoleaf.Device, [], restart: :transient)
    ]
    supervise(children, strategy: :simple_one_for_one)
  end

  def start_device(device) do
    case Supervisor.start_child(__MODULE__, [device]) do
      {:ok, pid} -> :ok
      {:error, {:already_started, pid}} -> pid |> GenServer.cast({:device_update, device})
      other -> Logger.error("Nanoleaf.Device is not able to be started: #{inspect other}")
    end
  end
end
