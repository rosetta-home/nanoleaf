defmodule NanoleafStream.Streamer do
  use GenServer
  require Logger

  @nano :"uuid:3aebec1d-2709-415e-a75a-88a1e0725dd3" #update this with the UDN of your nanoleaf
  @panels [46, 178, 54, 132, 228, 235, 27, 120, 242, 110, 152, 149] # these are panel id's in order of rendering

  def start_link() do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def start() do
    GenServer.cast(__MODULE__, :start)
  end

  def init(:ok) do
    SSDP.Client.start()
    Process.send_after(self(), :start, 5_000)
    {:ok, %{co2: [], panels: []}}
  end

  def handle_info(:start, state) do
    Nanoleaf.Device.set_api_key(@nano, "EXIKpkqbDmsywejvEF8BrAXdi6baDBRP")
    #device_state = Nanoleaf.Device.state(@nano)
    #panels =
    #  device_state.device_state["panelLayout"]["layout"]["positionData"]
    #  |> Enum.sort(&( (&1["y"]+&1["x"]) >= (&2["y"]+&2["x"]) ))
    #Logger.info("#{inspect panels}")
    Nanoleaf.Device.open_stream(@nano)
    Process.send_after(self(), :animate, 1000)
    {:noreply, state}
  end

  def handle_info(:animate, state) do
    multi = 0.1275
    frame = gen_frame(state.co2, multi)
    Nanoleaf.Device.stream(@nano, frame)
    Process.send_after(self(), :animate, 100)
    {:noreply, state}
  end

  def gen_frame(co2, multi) do
    0..11 |> Enum.reduce([12], fn(i, acc) ->
      id = @panels |> Enum.at(i)
      r = Enum.random(1..255)
      g = Enum.random(1..255)
      b = Enum.random(1..255)
      acc ++ [id, 1 ,r, g, b, 0, 1]
    end)
  end

end
