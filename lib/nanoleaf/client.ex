defmodule Nanoleaf.Client do
  use GenServer
  require Logger

  def start_link() do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    SSDP.register()
    {:ok, %{}}
  end

  def handle_info({:device, %{device: %{device_type: "nanoleaf_aurora:light"}} = device}, state) do
    Logger.info "Found Nanoleaf: #{inspect device}"
    Nanoleaf.DeviceSupervisor.start_device(device)
    {:noreply, state}
  end

  def handle_info({:device, other}, state) do
    {:noreply, state}
  end
end
