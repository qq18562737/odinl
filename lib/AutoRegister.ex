defmodule Actor.AutoRegister do
  require Logger
  use Actor

  @doc """
  创建AutoRegister actor实例
  """
  def create() do
    actor_uuid = MnesiaKV.uuid()

    new(%{
      uuid: actor_uuid,
      # 每5秒检查一次
      tick_interval: 5_000,
      state: %{
        # 上次注册时间
        last_register: 0,
        batch_id: "auto-reg-#{DateTime.utc_now() |> DateTime.to_unix()}",
        # 可注册的站点列表
        sites: [
          "https://pre.kakaogames.com/odinvalhallarising/reservation/6"
        ],
        # 待注册队列
        registration_queue: [],
        # 正在注册的账户
        in_progress: %{},
        # 已完成注册的账户
        completed: [],
        # 注册失败的账户
        failed: [],
        config: %{
          # 最大并发注册数
          max_concurrent: 3,
          # 注册间隔(毫秒)
          delay_between: 5_000,
          # 注册超时时间
          timeout: 600_000,
          # 最大重试次数
          max_retries: 2,
          # 错误冷却时间(秒)
          # 24小时
          error_cooldown: 86_400
        },
        circuit_breaker: %{
          enabled: false,
          last_failure: nil,
          failure_count: 0,
          cooldown_until: nil,
          # 可配置参数
          # 连续失败阈值
          threshold: 10,
          # 5分钟冷却(毫秒)
          cooldown_period: 300_000
        }
      }
    })
  end

  @doc """
  更新配置
  """
  def update_config(uuid, config) do
    actor = MnesiaKV.get(Actor, uuid)

    if actor do
      MnesiaKV.merge(Actor, uuid, %{config: config})
    end
  end

  @doc """
  添加注册站点
  """
  def add_sites(uuid, sites) when is_list(sites) do
    actor = MnesiaKV.get(Actor, uuid)

    if actor do
      current_sites = actor.sites || []
      new_sites = (current_sites ++ sites) |> Enum.uniq()
      MnesiaKV.merge(Actor, uuid, %{sites: new_sites})
    end
  end

  @doc """
  添加注册队列
  """
  def add_to_queue(uuid, count) do
    # 获取可用账户，增加状态检查
    available_accounts =
      MnesiaKV.get(Account)
      |> Enum.filter(fn account ->
        # 基本条件
        basic_cond =
          account[:blocked] == nil &&
            account[:owner] == :admin &&
            !account[:registered_site] &&
            get_in(account, [:keep, :email]) != nil

        # 状态条件
        status_cond =
          case get_in(account, [:status, :type]) do
            nil ->
              true

            :active ->
              true

            :temporary_error ->
              cooldown = get_in(account, [:status, :next_available]) || 0
              cooldown <= System.system_time(:second)

            # 其他状态(如password_error, blocked)不选择
            _ ->
              false
          end

        basic_cond && status_cond
      end)
      |> Enum.take(count)
      |> Enum.map(& &1.uuid)

    # 更新注册队列
    actor = MnesiaKV.get(Actor, uuid)

    if actor do
      current_queue = actor.registration_queue || []
      new_queue = current_queue ++ available_accounts

      MnesiaKV.merge(Actor, uuid, %{registration_queue: new_queue})
      length(available_accounts)
    else
      0
    end
  end

  @doc """
  处理注册结果
  Actor.AutoRegister.proc_result("/root/tmp/06b1mi8k2mgpof1b.log")
  """
  def proc_result(file) do
    out =
      File.read!(file)
      |> String.split("\n")

    tok = out |> Enum.find(&String.starts_with?(&1, "$RESULT$:"))
    tok = tok && String.replace(tok, "$RESULT$:", "") |> String.trim()
    terror = out |> Enum.find(&String.starts_with?(&1, "$ERROR$:"))
    terror = terror && String.replace(terror, "$ERROR$:", "")

    cond do
      tok ->
        case Jason.decode(tok) do
          {:ok, json} -> {:ok, json}
          _ -> {:error, "invalid_json"}
        end

      terror ->
        # 增强错误分类
        case terror do
          "password_error" -> {:failed, :password_error}
          "account_blocked" -> {:failed, :account_blocked}
          "account_not_found" -> {:failed, :account_not_found}
          "verification_required" -> {:failed, :verification_required}
          "proxy_error" -> {:failed, :proxy_error}
          "email_already_exists" -> {:failed, :email_already_exists}
          _ -> {:error, terror}
        end

      true ->
        {:error, out}
    end
  end

  @doc """
  使用Chrome执行自动化注册
  """
  def chromium_py(tag, args, proxy) do
    proxy = JSX.encode!(proxy)
    args = args ++ [proxy]
    args = args |> Enum.map(&"'#{&1}'") |> Enum.join(" ")
    script = "TAG=#{tag} python3.9 -u /root/odinl/script_new.py #{args} > /root/tmp/#{tag}.log"

    Logger.warning(script)
    File.write("/root/tmp/#{tag}", script)
    File.write("/root/tmp/#{tag}.log", "")

    _res = :os.cmd(String.to_charlist("sh /root/tmp/#{tag}"))
    :timer.sleep(500)
    res = proc_result("/root/tmp/#{tag}.log")

    try do
      _ghost =
        :os.cmd(~c"grep -s -l \"TAG=#{tag}\" /proc/*/environ")
        |> :binary.list_to_bin()
        |> String.split("\n")
        |> Enum.filter(&(&1 != ""))
        |> Enum.each(fn x ->
          Logger.warning("killing ghost proccess #{tag} #{x}")
          pid = Enum.at(String.split(x, "/"), 2)
          :os.cmd(~c"kill -9 #{pid}")
        end)
    catch
      _, _ -> nil
    end

    case res do
      {:ok, json} ->
        if json["status"] == "success" do
          {:ok, json}
        else
          {:error, json["error"] || "registration_failed"}
        end

      {:failed, reason} ->
        {:failed, reason}

      {:error, _res} ->
        {:error, "/root/tmp/#{tag}.log"}
    end
  end

  @doc """
  生成代理配置
  """
  def get_proxy(account_uuid) do
    %{
      host: "http://geo.iproyal.com:12321",
      ip: "geo.iproyal.com",
      password: "593chgaqlksdyh91_country-us_session-#{:os.system_time(1000)}_lifetime-5m",
      port: 12321,
      type: :http,
      username: "RCKLZ0XLD3yD8IGm"
    }
  end

  @doc """
  tick函数 - 每个tick_interval被调用一次
  """
  def tick(state) do
    state = ensure_valid_state(state)
    
    #Logger.info("tick #{:os.system_time(1000)} ")

    # 熔断检查优先于正常逻辑
    case check_circuit_breaker(state) do
      {:block, updated_state} ->
        Logger.warning("Registration suspended due to circuit breaker")
        updated_state

      {:continue, updated_state} ->
        # 原有tick逻辑...
        process_normal_registration(updated_state)
    end
  end

  # 原有tick逻辑.
  def process_normal_registration(state) do
    ts_m = :os.system_time(1000)

    # 检查是否到了下一次注册的时间
    delay_between = get_in(state, [:config, :delay_between]) || 5_000

    if ts_m >= state.last_register + delay_between do
      # 处理超时的注册
      timeout = get_in(state, [:config, :timeout]) || 120_000
      {new_in_progress, timed_out} = check_timeouts(state.in_progress, ts_m, timeout)

      next_available =
        System.system_time(:second) + get_in(state, [:config, :error_cooldown]) || 86_400

      # 将超时的添加到失败列表并标记为临时错误
      new_failed =
        Enum.reduce(timed_out, state.failed, fn uuid, acc ->
          MnesiaKV.merge(Account, uuid, %{
            status: %{
              at: DateTime.utc_now(),
              type: :temporary_error,
              last_error: "timeout",
              error_time: System.system_time(:second),
              next_available: next_available,
              error_count: 1
            }
          })

          [uuid | acc]
        end)

      # 计算可以启动的新注册数量
      current_count = map_size(new_in_progress)
      max_concurrent = get_in(state, [:config, :max_concurrent]) || 3
      can_start = max_concurrent - current_count

      # 从队列中获取下一批要注册的账户
      {to_register, remaining_queue} = Enum.split(state.registration_queue, can_start)

      # 为每个要注册的账户启动注册过程
      {updated_in_progress, new_last_register} =
        start_registrations(to_register, new_in_progress, ts_m, state.sites, state.batch_id)

      # 更新状态
      %{
        state
        | last_register: :os.system_time(1000),
          registration_queue: remaining_queue,
          in_progress: updated_in_progress,
          failed: new_failed
      }
    else
      state
    end
  end

  defp check_circuit_breaker(state) do
    cb = state.circuit_breaker

    cond do
      # 冷却期未结束
      cb.enabled && cb.cooldown_until > System.system_time(:millisecond) ->
        {:block, state}

      # 冷却期结束，尝试恢复
      cb.enabled ->
        Logger.info("冷却期结束，尝试恢复...")

        if test_website_available(state) do
          {:continue, reset_circuit_breaker(state)}
        else
          # 延长冷却
          new_state =
            put_in(
              state,
              [:circuit_breaker, :cooldown_until],
              System.system_time(:millisecond) + cb.cooldown_period
            )

          {:block, new_state}
        end

      # 正常状态
      true ->
        {:continue, state}
    end
  end

  # HTTPoison.head(("https://pre.kakaogames.com/odinvalhallarising/reservation/6"))
  defp test_website_available(state, retries \\ 3)
  defp test_website_available(_state, 0), do: false

  defp test_website_available(state, retries) do
    try do
      case site = hd(state.sites || []) do
        nil ->
          Logger.error("No sites configured in state: #{inspect(state)}")
          false

        url ->
          headers = [{"User-Agent", "Mozilla/5.0"}]

          case HTTPoison.head(url, headers,
                 timeout: 10_000,
                 recv_timeout: 15_000,
                 hackney: [pool: :default],
                 follow_redirect: true,
                 ssl: [{:versions, [:"tlsv1.2"]}]
               ) do
            {:ok, %{status_code: code}} when code in 200..399 ->
              true

            {:ok, %{status_code: code}} ->
              Logger.warning("Site returned non-success status: #{code}")
              false

            {:error, %HTTPoison.Error{reason: reason}} ->
              Logger.warning("HTTP request failed: #{inspect(reason)}")
              false
          end
      end
    rescue
      e ->
        Logger.error("""
        Website availability check crashed!
        Error: #{Exception.format(:error, e, System.stacktrace())}
        """)

        if retries > 0 do
          :timer.sleep(1000)
          test_website_available(state, retries - 1)
        else
          false
        end
    end
  end

  # 确保状态中的关键字段有效合法可用
  defp ensure_valid_state(state) do
    state
    |> ensure_map_field(:in_progress)
    |> ensure_list_field(:registration_queue)
    |> ensure_list_field(:completed)
    |> ensure_list_field(:failed)
    |> ensure_map_field(:config)
  end

  # 确保字段是Map类型
  defp ensure_map_field(state, field) do
    value = Map.get(state, field, %{})

    if is_map(value) do
      state
    else
      Map.put(state, field, %{})
    end
  end

  # 确保字段是List类型
  defp ensure_list_field(state, field) do
    value = Map.get(state, field, [])

    if is_list(value) do
      state
    else
      Map.put(state, field, [])
    end
  end

  # 检查超时的注册
  defp check_timeouts(in_progress, current_time, timeout) do
    in_progress = if is_map(in_progress), do: in_progress, else: %{}

    {timed_out, still_in_progress} =
      Enum.split_with(in_progress, fn {_uuid, data} ->
        current_time >= data.start_time + timeout
      end)

    timed_out_uuids = Enum.map(timed_out, fn {uuid, _} -> uuid end)
    {Map.new(still_in_progress), timed_out_uuids}
  end

  # 启动新的注册
  defp start_registrations(account_uuids, in_progress, current_time, sites, batch_id) do
    sites =
      if is_list(sites) && sites != [],
        do: sites,
        else: ["https://pre.kakaogames.com/odinvalhallarising/reservation/6"]

    in_progress = if is_map(in_progress), do: in_progress, else: %{}

    Enum.reduce(account_uuids, {in_progress, current_time}, fn uuid,
                                                               {acc_in_progress, acc_last_time} ->
      account = MnesiaKV.get(Account, uuid)

      if account && get_in(account, [:keep, :email]) do
        site = Enum.random(sites)

        register_data = %{
          site: site,
          start_time: current_time,
          account: account,
          retries: 0
        }

        spawn(fn -> perform_registration(uuid, site, account, batch_id) end)
        :timer.sleep(15000)
        {Map.put(acc_in_progress, uuid, register_data), current_time}
      else
        {acc_in_progress, acc_last_time}
      end
    end)
  end
  # 启动新的注册
  defp start_registrations111(account_uuids, in_progress, current_time, sites, batch_id) do
    sites =
      if is_list(sites) && sites != [],
        do: sites,
        else: ["https://pre.kakaogames.com/odinvalhallarising/reservation/6"]
    
    in_progress = if is_map(in_progress), do: in_progress, else: %{}
    
    # 只从账户列表中选择第一个有效账户进行注册
    case Enum.find(account_uuids, fn uuid ->
      account = MnesiaKV.get(Account, uuid)
      account && get_in(account, [:keep, :email])
    end) do
      nil -> 
        # 没有找到有效账户，返回原始状态
        {in_progress, current_time}
      
      uuid ->
        # 找到有效账户，只为这一个账户启动注册过程
        account = MnesiaKV.get(Account, uuid)
        site = Enum.random(sites)
        register_data = %{
          site: site,
          start_time: current_time,
          account: account,
          retries: 0
        }
        
        # 只执行一次spawn
        spawn(fn -> perform_registration(uuid, site, account, batch_id) end)
        
        # 更新并返回状态
        {Map.put(in_progress, uuid, register_data), current_time}
    end
  end
  # 执行实际注册过程
  defp perform_registration(account_uuid, site, account, batch_id) do
    email = get_in(account, [:keep, :email])
    password = get_in(account, [:keep, :password])
    proxy = get_proxy(account_uuid)
    username = String.split(email, "@") |> List.first()

    registration_args = [
      site,
      email,
      password,
      username,
      # region
      "0",
      # server
      "0"
    ]

    Logger.info("Starting registration for account #{account_uuid} on #{site}")
    result = chromium_py(account_uuid, registration_args, proxy)
    Logger.info("Registration result for #{account_uuid}: #{inspect(result)}")

    case result do
      {:ok, %{"status" => "success"} = json} ->
        # 成功时确保所有字段存在
        server = Map.get(json, "server", "unknown")
        region = Map.get(json, "region", "0")
        char_name = Map.get(json, "char_name", "")

        MnesiaKV.merge(Account, account_uuid, %{
          registered_site: site,
          registration_info: %{
            username: username,
            password: password,
            registration_time: DateTime.utc_now() |> DateTime.to_string(),
            batch_id: batch_id,
            server: server,
            region: region,
            char_name: char_name
          },
          status: %{
            at: DateTime.utc_now(),
            type: :active,
            last_error: nil,
            error_time: nil,
            next_available: nil,
            error_count: 0
          }
        })

        Logger.info(
          "Save to Account  #{account_uuid} on #{username} #{password} #{server} #{region}"
        )

        notify_registration_completed(account_uuid, true)

      {:ok, %{"error" => error_msg}} ->
        Logger.error("API returned error: #{error_msg}")
        update_account_status(account_uuid, error_msg)

      {:error, reason} ->
        Logger.error("Registration failed: #{inspect(reason)}")
        update_account_status(account_uuid, reason)
    end
  end

  # 根据错误类型更新账户状态
  defp update_account_status(account_uuid, reason) do
    account = MnesiaKV.get(Account, account_uuid)
    error_count = get_in(account, [:status, :error_count]) || 0

    status_update =
      case reason do
        # 标记为密码错误，永久禁用
        :password_error ->
          %{
            at: DateTime.utc_now(),
            type: :password_error,
            last_error: "password_error",
            error_time: System.system_time(:second),
            error_count: error_count + 1
          }

        # 标记为封禁状态
        :account_blocked ->
          %{
            at: DateTime.utc_now(),
            type: :blocked,
            last_error: "account_blocked",
            error_time: System.system_time(:second),
            error_count: error_count + 1
          }

        :account_not_found ->
          %{
            at: DateTime.utc_now(),
            type: :not_found,
            last_error: "account_not_found",
            error_time: System.system_time(:second),
            error_count: error_count + 1
          }

        _ ->
          # 临时错误，设置24小时冷却时间
          %{
            at: DateTime.utc_now(),
            type: :temporary_error,
            last_error: to_string(reason),
            error_time: System.system_time(:second),
            # 24小时
            next_available: System.system_time(:second) + 86_400,
            error_count: error_count + 1
          }
      end

    MnesiaKV.merge(Account, account_uuid, %{status: status_update})
  end

  # 通知注册完成
  defp notify_registration_completed(account_uuid, success, reason \\ nil) do
    case :pg.get_members(PGActorAll, Actor.AutoRegister) do
      [pid | _] ->
        send(pid, {:registration_completed, account_uuid, success, reason})

      _ ->
        Logger.error("Cannot find AutoRegister actor process")
    end
  end

  # 处理注册完成消息
  def message({:registration_completed, account_uuid, success, reason}, state) do
    state = ensure_valid_state(state)

    if Map.has_key?(state.in_progress, account_uuid) do
      {_registration_data, new_in_progress} = Map.pop(state.in_progress, account_uuid)

      if success do
        new_completed = [account_uuid | state.completed]
        %{state | in_progress: new_in_progress, completed: new_completed}
      else
        # 失败处理已在perform_registration中完成，这里只需更新状态
        new_failed = [account_uuid | state.failed]
        # %{state | in_progress: new_in_progress, failed: new_failed}
        # 增强：更新熔断器状态
        updated_state = %{
          state
          | in_progress: new_in_progress,
            failed: new_failed,
            circuit_breaker: update_failure_stats(state.circuit_breaker, reason)
        }

        # 检查是否触发熔断
        if updated_state.circuit_breaker.failure_count >= updated_state.circuit_breaker.threshold do
          Logger.error(
            "Triggering circuit breaker! Failure count: #{updated_state.circuit_breaker.failure_count}"
          )

          enable_circuit_breaker(updated_state)
        else
          updated_state
        end
      end
    end
  end

  # 处理其他消息
  def message(msg, state) do
    Logger.warn("Received unknown message: #{inspect(msg)}")
    ensure_valid_state(state)
  end

  defp update_failure_stats(cb, reason) do
    now = System.system_time(:millisecond)

    # 如果是同类错误（如网站维护），增加计数
    if is_system_error(reason) do
      %{
        cb
        | failure_count: cb.failure_count + 1,
          last_failure: now
      }
    else
      # 账户级错误不影响熔断
      cb
    end
  end

  defp is_system_error(reason) do
    reason in [:timeout, :service_unavailable, :connection_failed]
  end

  defp enable_circuit_breaker(state) do
    cb = state.circuit_breaker

    put_in(state, [:circuit_breaker], %{
      cb
      | enabled: true,
        cooldown_until: System.system_time(:millisecond) + cb.cooldown_period
    })
  end

  defp reset_circuit_breaker(state) do
    put_in(state, [:circuit_breaker], %{
      enabled: false,
      last_failure: nil,
      failure_count: 0,
      cooldown_until: nil,
      threshold: state.circuit_breaker.threshold,
      cooldown_period: state.circuit_breaker.cooldown_period
    })
  end

  @doc """
  手动覆盖熔断状态（用于紧急恢复）
  """
  def force_reset_circuit_breaker(uuid) do
    actor = MnesiaKV.get(Actor, uuid)

    if actor do
      MnesiaKV.merge(Actor, uuid, %{
        circuit_breaker: reset_circuit_breaker(actor.circuit_breaker)
      })
    end
  end

  @doc """
  获取当前保护状态
  """
  def get_protection_status(uuid) do
    actor = MnesiaKV.get(Actor, uuid)

    if actor do
      %{
        enabled: actor.circuit_breaker.enabled,
        remaining_cooldown:
          max(0, (actor.circuit_breaker.cooldown_until || 0) - System.system_time(:millisecond)),
        failure_count: actor.circuit_breaker.failure_count,
        last_failure: actor.circuit_breaker.last_failure
      }
    end
  end

  @doc """
  获取注册状态
  """
  def get_status(uuid) do
    actor = MnesiaKV.get(Actor, uuid)

    if actor do
      in_progress = Map.get(actor, :in_progress, %{})
      in_progress = if is_map(in_progress), do: in_progress, else: %{}

      registration_queue = Map.get(actor, :registration_queue, [])
      registration_queue = if is_list(registration_queue), do: registration_queue, else: []

      completed = Map.get(actor, :completed, [])
      completed = if is_list(completed), do: completed, else: []

      failed = Map.get(actor, :failed, [])
      failed = if is_list(failed), do: failed, else: []

      %{
        queue_size: length(registration_queue),
        in_progress: map_size(in_progress),
        completed: length(completed),
        failed: length(failed),
        sites: actor.sites,
        config: actor.config,
        in_progress_details: in_progress,
        last_completed: Enum.take(completed, 5),
        last_failed: Enum.take(failed, 5),
        batch_id: actor.batch_id
      }
    else
      %{
        queue_size: 0,
        in_progress: 0,
        completed: 0,
        failed: 0,
        sites: [],
        config: %{},
        in_progress_details: %{},
        last_completed: [],
        last_failed: [],
        batch_id: nil
      }
    end
  end

  @doc """
  重置状态
  """
  def reset(uuid) do
    MnesiaKV.merge(Actor, uuid, %{
      last_register: 0,
      registration_queue: [],
      in_progress: %{},
      completed: [],
      failed: []
    })
  end

  @doc """
  打印当前状态的调试信息
  """
  def debug(uuid) do
    actor = MnesiaKV.get(Actor, uuid)

    if actor do
      Logger.info("===== AutoRegister Debug Info for #{uuid} =====")
      Logger.info("Batch ID: #{actor.batch_id}")
      Logger.info("Sites: #{inspect(actor.sites)}")
      Logger.info("Queue: #{length(actor.registration_queue || [])} items")
      Logger.info("In Progress: #{map_size(actor.in_progress || %{})} items")
      Logger.info("Completed: #{length(actor.completed || [])} items")
      Logger.info("Failed: #{length(actor.failed || [])} items")
      Logger.info("Config: #{inspect(actor.config)}")

      if map_size(actor.in_progress || %{}) > 0 do
        Logger.info("--- Current In-Progress Registrations ---")

        Enum.each(actor.in_progress || %{}, fn {account_id, data} ->
          Logger.info(
            "#{account_id} -> site: #{data.site}, started: #{DateTime.from_unix!(div(data.start_time, 1000))}"
          )
        end)
      end

      :ok
    else
      Logger.error("AutoRegister actor #{uuid} not found")
      :error
    end
  end

  @doc """
  获取已完成的注册详情
  """
  def get_completed_details(uuid) do
    actor = MnesiaKV.get(Actor, uuid)

    if actor do
      completed_accounts = actor.completed || []

      Enum.map(completed_accounts, fn account_uuid ->
        account = MnesiaKV.get(Account, account_uuid)

        if account do
          %{
            uuid: account_uuid,
            email: get_in(account, [:keep, :email]),
            site: account.registered_site,
            username: get_in(account, [:registration_info, :username]),
            server: get_in(account, [:registration_info, :server]),
            region: get_in(account, [:registration_info, :region]),
            char_name: get_in(account, [:registration_info, :char_name]),
            registration_time: get_in(account, [:registration_info, :registration_time])
          }
        else
          %{uuid: account_uuid, error: :account_not_found}
        end
      end)
    else
      []
    end
  end

  @doc """
  获取账户状态统计
  """
  def get_account_stats() do
    accounts = MnesiaKV.get(Account)

    Enum.reduce(accounts, %{}, fn account, acc ->
      status_type = get_in(account, [:status, :type]) || :active
      Map.update(acc, status_type, 1, &(&1 + 1))
    end)
  end
end
