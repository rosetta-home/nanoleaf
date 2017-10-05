defmodule Nanoleaf.Streamer do
  use GenServer
  require Logger

  @nano :"uuid:3aebec1d-2709-415e-a75a-88a1e0725dd3"

  def start_link() do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def start() do
    GenServer.cast(__MODULE__, :start)
  end

  def init(:ok) do
    {:ok, %{}}
  end

  def handle_cast(:start, state) do
    device_state = Nanoleaf.Device.state(@nano)
    Nanoleaf.Device.open_stream(@nano)
    Process.send_after(self(), :animate, 1000)
    {:noreply, %{device_state: device_state.device_state}}
  end

  def handle_info(:animate, state) do
    frame = gen_frame(state.device_state)
    Logger.info "#{inspect frame}"
    Nanoleaf.Device.stream(:"uuid:3aebec1d-2709-415e-a75a-88a1e0725dd3", frame)
    Process.send_after(self(), :animate, 100)
    {:noreply, state}
  end

  def gen_frame(device_state) do
    num_panels = device_state["panelLayout"]["layout"]["positionData"] |> Enum.count()
    device_state["panelLayout"]["layout"]["positionData"] |> Enum.reduce([num_panels], fn(panel, acc) ->
      id = panel["panelId"]
      r = Enum.random(1..255)
      g = Enum.random(1..255)
      b = Enum.random(1..255)
      acc ++ [id, 1] ++ [r, g, b, 0, 1]
    end)
  end
end
