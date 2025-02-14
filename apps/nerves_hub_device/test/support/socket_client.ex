defmodule SocketClient do
  use Slipstream, restart: :temporary

  def start_link(args) do
    Slipstream.start_link(__MODULE__, args)
  end

  def connected?(socket) do
    GenServer.call(socket, :connected?)
  end

  def joined?(socket) do
    GenServer.call(socket, :joined?)
  end

  def reply(socket) do
    GenServer.call(socket, :reply)
  end

  def join(socket, channel) do
    GenServer.call(socket, {:join, channel})
  end

  def wait_connect(_, _ \\ nil)

  def wait_connect(socket, nil) do
    timeout = 2_000
    {:ok, t_ref} = :timer.exit_after(timeout, "Timed out waiting for socket")
    wait_connect(socket, t_ref)
  end

  def wait_connect(socket, timer) do
    if __MODULE__.connected?(socket) do
      :timer.cancel(timer)
    else
      wait_connect(socket, timer)
    end
  end

  def wait_join(_, _ \\ nil)

  def wait_join(socket, nil) do
    timeout = 2_000
    {:ok, t_ref} = :timer.exit_after(timeout, "Timed out waiting for socket")
    wait_join(socket, t_ref)
  end

  def wait_join(socket, timer) do
    if __MODULE__.joined?(socket) do
      :timer.cancel(timer)
    else
      wait_join(socket, timer)
    end
  end

  @impl true
  def init(config) do
    Process.flag(:trap_exit, true)

    socket =
      config
      |> connect!()
      |> assign(:connected?, false)
      |> assign(:joined?, false)
      |> assign(:reply, nil)

    {:ok, socket}
  end

  @impl true
  def handle_connect(socket) do
    {:ok, assign(socket, :connected?, true)}
  end

  @impl true
  def handle_join(_channel, reply, socket) do
    socket =
      socket
      |> assign(:joined?, true)
      |> assign(:reply, reply)

    {:ok, socket}
  end

  @impl true
  def handle_call(:connected?, _from, socket) do
    {:reply, socket.assigns.connected?, socket}
  end

  def handle_call(:joined?, _from, socket) do
    {:reply, socket.assigns.joined?, socket}
  end

  def handle_call(:reply, _from, socket) do
    {:reply, socket.assigns.reply, socket}
  end

  def handle_call({:join, channel}, _from, socket) do
    socket =
      socket
      |> assign(:joined?, false)
      |> Slipstream.join(channel)

    {:reply, :ok, socket}
  end

  def handle_call(:status, _from, socket) do
    {:reply, :ok, socket}
  end
end
