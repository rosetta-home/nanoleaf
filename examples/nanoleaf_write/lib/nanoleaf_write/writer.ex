defmodule NanoleafWrite.Writer do
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
    #Nanoleaf.Device.open_stream(@nano)
    #Process.send_after(self(), :generate_co2, 0)
    Process.send_after(self(), :animate, 1000)
    {:noreply, state}
  end

  def handle_info(:animate, state) do
    co2 = state.co2 |> generate_co2
    multi = 0.1275
    frame = gen_frame(co2, multi)
    Nanoleaf.Device.write(@nano, %{write: %{command: "display", version: "1.0", animType: "custom", animData: frame, loop: false}})
    Process.send_after(self(), :animate, 1000)
    {:noreply, %{state | co2: co2}}
  end

  def gen_frame(co2, multi) do
    0..11 |> Enum.reduce("12", fn(i, acc) ->
      v = co2 |> Enum.at(i)
      id = @panels |> Enum.at(i)
      r = round(v * multi)
      g = 50
      b = 100
      "#{acc} #{id} 1 #{r} #{g} #{b} 1 10"
    end)
  end

  def generate_co2([]), do: 1..12 |> Enum.map(fn(i) -> Enum.random(400..2000) end)
  def generate_co2(co2) do
    co2 |> Enum.drop(-1) |> (fn l -> [Enum.random(400..2000)] ++ l end).()
  end

end
