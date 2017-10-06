defmodule Nanoleaf.Device do
  use GenServer
  require Logger

  defmodule StreamInterface do
    defstruct ip: nil, port: nil, protocol: nil, udp: nil
  end

  defmodule State do
    defstruct pid: nil, device: %{}, api_key: nil, device_state: %{}, stream_interface: %StreamInterface{}
  end

  def on(pid), do: GenServer.cast(pid, :on)
  def off(pid), do: GenServer.cast(pid, :off)
  def brightness(pid, value), do: GenServer.cast(pid, {:brightness, value})
  def hue(pid, value), do: GenServer.cast(pid, {:hue, value})
  def saturation(pid, value), do: GenServer.cast(pid, {:saturation, value})
  def color_temperature(pid, value), do: GenServer.cast(pid, {:color_temperature, value})
  def write(pid, payload), do: GenServer.cast(pid, {:write, payload})
  def open_stream(pid), do: GenServer.cast(pid, :start_stream)
  def stream(pid, payload), do: GenServer.cast(pid, {:stream, payload})
  def random(pid), do: GenServer.cast(pid, :random)
  def state(pid), do: GenServer.call(pid, :state)
  def set_api_key(pid, key), do: GenServer.call(pid, {:set_api_key, key})

  def start_link(device) do
    pid = :"#{device.device.udn}"
    GenServer.start_link(__MODULE__, [device, pid], name: pid)
  end

  def init([device, pid]) do
    Process.send_after(self(), :register, 0)
    {:ok, %State{device: device, pid: pid}}
  end

  def handle_call(:state, _from, state), do: {:reply, state, state}

  def handle_call({:set_api_key, key}, _from, state) do
    Process.send_after(self(), :device_state, 0)
    {:reply, :ok, %State{state | api_key: key}}
  end

  def handle_cast({:device_update, device}, state) do
    Logger.info("Device Updating: #{inspect device.device.udn}")
    {:noreply, %State{state | device: device}}
  end

  def handle_cast(:on, state) do
    :ok = put("/state/on", %{value: true}, state)
    {:noreply, state}
  end

  def handle_cast(:off, state) do
    :ok = put("/state/on", %{value: false}, state)
    {:noreply, state}
  end

  def handle_cast({:brightness, value}, state) do
    :ok = put("/state/brightness", %{brightness: %{value: value}}, state)
    {:noreply, state}
  end

  def handle_cast({:hue, value}, state) do
    :ok = put("/state/hue", %{hue: %{value: value}}, state)
    {:noreply, state}
  end

  def handle_cast({:saturation, value}, state) do
    :ok = put("/state/sat", %{sat: %{value: value}}, state)
    {:noreply, state}
  end

  def handle_cast({:color_temperature, value}, state) do
    :ok = put("/state/ct", %{ct: %{value: value}}, state)
    {:noreply, state}
  end

  def handle_cast({:write, value}, state) do
    :ok = put("/effects", value, state)
    {:noreply, state}
  end

  def handle_cast(:start_stream, state) do
    :ok = put("/effects", %{write: %{command: "display", version: "1.0", animType: "extControl", animData: nil, loop: false}}, state)
    {:noreply, state}
  end

  def handle_cast({:stream, value}, state) do
    bin = :erlang.list_to_binary(value)
    :gen_udp.send(state.stream_interface.udp, state.stream_interface.ip, state.stream_interface.port, bin)
    {:noreply, state}
  end

  def handle_cast(:random, state) do
    Process.send_after(self(), :random, 0)
    {:noreply, state}
  end

  def handle_info(:random, state) do
    data = generate_random_colors(state.device_state)
    put("/effects", %{write: %{command: "display", version: "1.0", animType: "custom", animData: data, loop: false}}, state)
    Process.send_after(self(), :random, 1000)
    {:noreply, state}
  end

  def handle_info(:register, %State{api_key: key} = state) when key == nil do
    state =
      case HTTPoison.post("#{state.device.url}/api/v1/new", "") do
        {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
          auth = body |> Poison.decode!
          Logger.info "Registration Success: #{inspect body}"
          Process.send_after(self(), :device_state, 0)
          %State{state | api_key: Map.get(auth, "auth_token")}
        {:ok, %HTTPoison.Response{} = r} ->
          Logger.error("#{inspect r}")
          Process.send_after(self(), :register, 3000)
          state
        {:error, other} ->
          Logger.error("#{inspect other}")
          Process.send_after(self(), :register, 3000)
          state
      end
    {:noreply, state}
  end
  def handle_info(:register, state), do: {:noreply, state}

  def handle_info(:device_state, state) do
    {:ok, device_state} = get("", state)
    {:noreply, %State{state | device_state: device_state}}
  end

  def handle_info({:stream_interface, info}, state) do
    udp_options = [:binary, {:ip, {0,0,0,0}}, {:reuseaddr, true}]
    {:ok, udp} = :gen_udp.open(0, udp_options)
    si = %StreamInterface{state.stream_interface |
      ip: info["streamControlIpAddr"] |> String.to_charlist |> :inet_parse.address() |> elem(1),
      port: info["streamControlPort"],
      protocol: info["streamControlProtocol"],
      udp: udp
    }
    Logger.info "Stream Open: #{inspect si}"
    {:noreply, %State{state | stream_interface: si}}
  end

  def get(url, state) do
    case HTTPoison.get("#{state.device.url}/api/v1/#{state.api_key}#{url}") do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        resp = body |> Poison.decode!
        Logger.debug "Response: #{inspect resp}"
        {:ok, resp}
      {:ok, %HTTPoison.Response{} = r} ->
        Logger.error("#{inspect r}")
        {:error, r}
      {:error, other} ->
        Logger.error("#{inspect other}")
        {:error, other}
    end
  end

  def put(url, payload, state) do
    case HTTPoison.put("#{state.device.url}/api/v1/#{state.api_key}#{url}", payload |> Poison.encode!) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
          Logger.info("Stream opening: #{body}")
          stream_info = body |> Poison.decode!
          Process.send_after(self(), {:stream_interface, stream_info}, 0)
        :ok
      {:ok, %HTTPoison.Response{status_code: 204}} ->
        Logger.debug "Success setting #{url}: #{inspect payload}"
        Process.send_after(self(), :device_state, 0)
        :ok
      {:ok, %HTTPoison.Response{} = r} ->
        Logger.error("#{inspect r}")
        :error
      {:error, other} ->
        Logger.error("#{inspect other}")
        :error
    end
  end

  def generate_random_colors(device_state) do
    num_panels = device_state["panelLayout"]["layout"]["positionData"] |> Enum.count()
    device_state["panelLayout"]["layout"]["positionData"] |> Enum.reduce(num_panels, fn(panel, acc) ->
      id = panel["panelId"]
      frames =
        1..5 |> Enum.reduce("5", fn(_i, acc) ->
          r = Enum.random(1..255)
          g = Enum.random(1..255)
          b = Enum.random(1..255)
          "#{acc} #{r} #{g} #{b} 0 20"
        end)
      "#{acc} #{id} #{frames}"
    end)
  end
end
