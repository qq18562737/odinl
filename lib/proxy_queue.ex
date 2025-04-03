defmodule ProxyQueue do
    use GenServer
    require Logger
  
    def start_link(), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)
  
    def init([]) do
      Process.send_after(self(), :update, 1000)
      {:ok, %{ips_mapping: %{}, good_ips: []}}
    end
  
    def handle_call({:lock, uuid}, _, state) do
      {reply, good_ips} = can_use(uuid, state.ips_mapping, state.good_ips)
      {:reply, reply, %{state | good_ips: good_ips}}
    end
  
    def handle_call({:unlock, uuid}, _, state) do
      delete(uuid)
      {:reply, :ok, state}
    end
  
    def handle_call({:unlock_mapping, uuid}, _, state) do
      delete1(uuid)
      {:reply, :ok, state}
    end
  
    def handle_call(:random, _, state) do
      reply = p_random(state.good_ips)
      {:reply, reply, state}
    end
  
    def handle_call(:rest, _, state) do
      reply = rest_ips(state.good_ips)
      {:reply, reply, state}
    end
  
    def handle_call(:state, _, state) do
      {:reply, state, state}
    end
  
    def handle_call(:clear, _, state) do
      Process.send_after(self(), :update, 1000)
  
      clear_db()
  
      {:noreply, %{ips_mapping: %{}, good_ips: []}}
    end
  
    def handle_info(:update, state) do
      ips = MnesiaKV.get(ProxyPool) |> Enum.filter(&(!!&1[:proxy]))
      ips_mapping = ips |> Enum.map(&{&1.proxy, &1[:acc_uuids] || []})
  
      time_ms_limit = :os.system_time(1000) + 5 * 1000
  
      ips_mapping =
        Enum.map(ips_mapping, fn {proxy, accs} ->
          filtered =
            Enum.filter(accs, fn acc ->
              acc_data = MnesiaKV.get(Account, acc)
  
              !!acc_data && acc_data[:blocked] == nil && !!acc_data[:link] &&
                (acc_data[:next_login] || 0 < time_ms_limit)
            end)
  
          if filtered != accs do
            # MnesiaKV.merge(ProxyPool, proxy.ip, %{acc_uuids: filtered})        
            MnesiaKV.merge(ProxyPool, "#{proxy.ip}:#{proxy.port}", %{acc_uuids: filtered})
          end
  
          {proxy, filtered}
        end)
  
      ips_mapping = Map.new(ips_mapping)
  
      good_ips =
        ips |> Enum.filter(&(&1[:can_connect] == true && &1[:avg_time] != 0 && !&1[:blocked]))
  
      state = %{state | ips_mapping: ips_mapping, good_ips: good_ips}
      Process.send_after(self(), :update, 5 * 1000)
      {:noreply, state}
    end
  
    def can_use(uuid, ips_mapping, good_ips) do
      mapping_proxy = MnesiaKV.get(ProxyStaticMapping, uuid)
      mapped_proxy = mapping_proxy[:proxy]
  
      proxies = Map.keys(ips_mapping)
  
      cond do
        !!mapped_proxy and mapped_proxy not in proxies ->
          MnesiaKV.delete(ProxyStaticMapping, uuid)
          can_use(uuid, ips_mapping, good_ips)
  
        !!mapped_proxy ->
          {mapped_proxy, good_ips}
  
        true ->
          ips =
            Enum.filter(good_ips, fn proxy_info ->
              length(proxy_info[:acc_uuids] || []) < (proxy_info[:accs_limit] || 4)
            end)
            |> Enum.shuffle()
  
          case ips do
            [] ->
              Logger.warning("no proxy for locking #{uuid}, gotta erase")
              {nil, good_ips}
  
            [proxy_info | _] ->
              uuids = [uuid | proxy_info[:acc_uuids] || []]
  
              MnesiaKV.merge(ProxyPool, proxy_info.uuid, %{
                acc_uuids: uuids
              })
  
              MnesiaKV.merge(ProxyStaticMapping, uuid, %{proxy: proxy_info.proxy})
              new_proxy_info = Map.put(proxy_info, :acc_uuids, uuids)
              {proxy_info.proxy, [new_proxy_info | good_ips -- [proxy_info]]}
          end
      end
    end
  
    def delete(uuid) do
      try do
        mapping_proxy = MnesiaKV.get(ProxyStaticMapping, uuid)
  
        if mapping_proxy && !!mapping_proxy[:proxy][:ip] do
          pool = MnesiaKV.get(ProxyPool, mapping_proxy[:proxy][:ip])
  
          pool_port =
            MnesiaKV.get(ProxyPool, "#{mapping_proxy[:proxy][:ip]}:#{mapping_proxy[:proxy][:port]}")
  
          if !!pool,
            do:
              MnesiaKV.merge(ProxyPool, pool.proxy.ip, %{
                acc_uuids: (pool[:acc_uuids] || []) -- [uuid]
              })
  
          if !!pool_port,
            do:
              MnesiaKV.merge(ProxyPool, "#{pool_port.proxy.ip}:#{pool_port.proxy.port}", %{
                acc_uuids: (pool_port[:acc_uuids] || []) -- [uuid]
              })
        end
      catch
        _, _ -> nil
      end
    end
  
    def delete1(uuid) do
      delete(uuid)
      MnesiaKV.delete(ProxyStaticMapping, uuid)
    end
  
    def rest_ips(good_ips) do
      ips =
        Enum.filter(good_ips, fn proxy_info ->
          length(proxy_info[:acc_uuids] || []) < (proxy_info[:accs_limit] || 4)
        end)
        |> Enum.map(& &1.uuid)
  
      count = Enum.count(ips)
      {ips, count}
    end
  
    def get_random() do
      GenServer.call(ProxyQueue, :random)
    end
  
    def get_state() do
      GenServer.call(ProxyQueue, :state)
    end
  
    def p_random([]) do
      {:error, :no_proxy_available}
    end
  
    def p_random(good_ips) do
      good_ips |> Enum.map(& &1.proxy) |> Enum.random()
    end
  
    defp clear_db() do
      MnesiaKV.clear(ProxyStaticMapping)
      MnesiaKV.clear(ProxyPool)
    end
  
    """
      url = "https://api.oxylabs.io/v1/proxies/lists/57d8afd2-1737-11ee-8c70-901b0ec4424b"
      ips = ProxyQueue.download_proxy(url)
      ProxyQueue.update_proxy(ips)
  
    """
  
    def download_proxy(url) do
      case System.cmd("curl", ["-u", "414987790:W7Lw8PTHY3", url]) do
        {res, 0} -> JSX.decode!(res)
        _ -> []
      end
    end
  
    def update_proxy(ips) do
      proxies =
        Enum.map(ips, fn line ->
          %{
            host: line["ip"],
            ip: line["ip"],
            password: "W7Lw8PTHY3",
            port: :erlang.binary_to_integer(line["port"]),
            type: :socks5,
            username: "414987790"
          }
        end)
  
      Enum.each(proxies, fn proxy ->
        MnesiaKV.merge(ProxyPool, "#{proxy.ip}:#{proxy.port}", %{
          proxy: proxy,
          avg_time: :ok,
          can_connect: true
        })
      end)
  
      new = proxies |> Enum.map(& &1.ip)
      del = MnesiaKV.keys(ProxyPool) -- new
      del |> Enum.each(&MnesiaKV.delete(ProxyPool, &1))
    end
  end
  