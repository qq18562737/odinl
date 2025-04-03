defmodule Actor.AutoRegister do
    require Logger
    use Actor
  
    # 创建AutoRegister actor实例
    def create() do
      actor_uuid = MnesiaKV.uuid()
      
      new(%{
        uuid: actor_uuid,
        tick_interval: 5_000,  # 每5秒检查一次
        state: %{
          last_register: 0,    # 上次注册时间
          batch_id: "auto-reg-#{DateTime.utc_now() |> DateTime.to_unix()}",
          sites: [             # 可注册的站点列表
            "example.com/register",
            "test-site.net/signup",
            "demo-forum.org/join"
          ],
          registration_queue: [],  # 待注册队列
          in_progress: %{},        # 正在注册的账户
          completed: [],           # 已完成注册的账户
          failed: [],              # 注册失败的账户
          config: %{
            max_concurrent: 3,     # 最大并发注册数
            delay_between: 5_000,  # 注册间隔(毫秒)
            timeout: 120_000,      # 注册超时时间
            max_retries: 2         # 最大重试次数
          }
        }
      })
    end
  
    # 更新配置
    def update_config(uuid, config) do
      # 使用 MnesiaKV.merge
      actor = MnesiaKV.get(Actor, uuid)
      if actor do
        MnesiaKV.merge(Actor, uuid, %{config: config})
      end
    end
  
    # 添加注册站点
    def add_sites(uuid, sites) when is_list(sites) do
      # 使用 MnesiaKV.merge
      actor = MnesiaKV.get(Actor, uuid)
      if actor do
        current_sites = actor.sites || []
        new_sites = (current_sites ++ sites) |> Enum.uniq()
        MnesiaKV.merge(Actor, uuid, %{sites: new_sites})
      end
    end
  
    # 添加注册队列
    def add_to_queue(uuid, count) do
      # 获取可用账户
      available_accounts = 
        MnesiaKV.get(Account)
        |> Enum.filter(&(&1[:blocked] == nil && 
                        &1[:owner] == :admin && 
                        !&1[:registered_site] &&
                        get_in(&1, [:keep, :email]) != nil))
        |> Enum.take(count)
        |> Enum.map(& &1.uuid)
      
      # 更新注册队列
      # 使用 MnesiaKV.merge
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
  
    # 处理注册结果
    def proc_result(file) do
      out =
        File.read!(file)
        |> String.split("\n")
      # Enum.each(out, fn x -> IO.puts(x) end)
      tok = out |> Enum.find(&String.starts_with?(&1, "$RESULT$:"))
      tok = tok && String.replace(tok, "$RESULT$:", "") |> String.trim()
      terror = out |> Enum.find(&String.starts_with?(&1, "$ERROR$:"))
      terror = terror && String.replace(terror, "$ERROR$:", "")
      cond do
        tok ->
          {:ok, tok}
        terror ->
          {:error, terror}
        true ->
          {:error, out}
      end
    end
  
    # 使用Chrome执行自动化注册
    def chromium_py(tag, args, need \\ nil, proxy) do
      proxy = JSX.encode!(proxy)
      args = args ++ [proxy]
      args = args |> Enum.map(&"'#{&1}'") |> Enum.join(" ")
      script = "TAG=#{tag} python3 -u /root/oa_nc.py #{args} > /tmp/#{tag}.log"
      script = "TAG=#{tag} python3 -u /root/baidu-test.py #{args} > /tmp/#{tag}.log"
      
      Logger.warning(script)
      #add option to check if its lxc
      File.write("/var/lib/lxc/ubuntu-e/rootfs/tmp/#{tag}", script)
      File.write("/var/lib/lxc/ubuntu-e/rootfs/tmp/#{tag}.log", "")    
      # 执行命令
     _res = :os.cmd(~c"lxc-attach ubuntu-e -- sh /tmp/#{tag}")

      # if read instantly, the file is complete buffered yet
      :timer.sleep(500)
      res = proc_result("/var/lib/lxc/ubuntu-e/rootfs/tmp/#{tag}.log")
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
        {:ok, tok} ->
          cond do
            !need ->
              {:ok, res}
            true ->
              %{query: query} = URI.parse(tok)
              cond do
                query ->
                  got = URI.decode_query(query) |> Map.get(need)
                  got && {:ok, got}
                true ->
                  {:failed, "unknown"}
              end
          end
        {:error, res}
        when res in [
               "failed_run_chrome",
               "proxy_timeout",
               "registration_error",
               "site_blocked",
               "verification_required",
               "email_already_exists"
             ] ->
          {:failed, res}
        {:error, _res} ->
          {:error, "/var/lib/lxc/ubuntu-e/rootfs/tmp/#{tag}.log"}
      end
    end
  
    # 生成代理配置
    def get_proxy(account_uuid) do
      # 生成唯一会话ID
      session_id = "#{account_uuid}_#{:os.system_time(1000)}"
      
      %{
        host: "http://geo.iproyal.com:12321",
        ip: "geo.iproyal.com",
        password: "593chgaqlksdyh91_country-us_session-#{session_id}_lifetime-5m",
        port: 12321,
        type: :http,
        username: "RCKLZ0XLD3yD8IGm"
      }
    end
  
    # tick函数 - 每个tick_interval被调用一次
    def tick(state) do
      # 确保关键状态字段是正确的类型
      state = ensure_valid_state(state)
      
      ts_m = :os.system_time(1000)
      
      # 检查是否到了下一次注册的时间
      delay_between = get_in(state, [:config, :delay_between]) || 5_000
      
      if ts_m >= state.last_register + delay_between do
        # 处理超时的注册
        timeout = get_in(state, [:config, :timeout]) || 120_000
        {new_in_progress, timed_out} = check_timeouts(state.in_progress, ts_m, timeout)
        
        # 将超时的添加到失败列表
        new_failed = state.failed ++ timed_out
        
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
        %{state | 
          last_register: new_last_register,
          registration_queue: remaining_queue,
          in_progress: updated_in_progress,
          failed: new_failed
        }
      else
        # 不是注册时间，仅返回当前状态
        state
      end
    end
    
    # 确保状态中的关键字段有效
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
      # 确保in_progress是Map
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
      # 确保sites是非空列表
      sites = if is_list(sites) && sites != [], do: sites, else: ["example.com/register"]
      
      # 确保in_progress是Map
      in_progress = if is_map(in_progress), do: in_progress, else: %{}
      
      Enum.reduce(account_uuids, {in_progress, current_time}, fn uuid, {acc_in_progress, acc_last_time} ->
        # 获取账户信息
        account = MnesiaKV.get(Account, uuid)
        
        if account && get_in(account, [:keep, :email]) do
          # 选择一个随机站点
          site = Enum.random(sites)
          
          # 记录此次注册尝试
          register_data = %{
            site: site,
            start_time: current_time,
            account: account,
            retries: 0
          }
          
          # 启动注册进程
          spawn(fn -> perform_registration(uuid, site, account, batch_id) end)
          
          # 更新进行中的注册和最后注册时间
          {Map.put(acc_in_progress, uuid, register_data), current_time}
        else
          # 账户没有邮箱信息，跳过
          {acc_in_progress, acc_last_time}
        end
      end)
    end
    
    # 执行实际注册过程
    defp perform_registration(account_uuid, site, account, batch_id) do
      # 获取账户信息
      email = get_in(account, [:keep, :email])
      password = get_in(account, [:keep, :password]) || generate_password()
      
      # 获取代理
      proxy = get_proxy(account_uuid)
      
      # 构建注册参数
      username = String.split(email, "@") |> List.first()
      registration_args = [
        site,              # 注册网站URL
        email,             # 邮箱
        password,          # 密码
        username,          # 用户名
        batch_id           # 批次ID
      ]
      
      # 执行Chrome自动化注册
      Logger.info("Starting registration for account #{account_uuid} on #{site}")
      result = chromium_py(account_uuid, registration_args, "success", proxy)
      Logger.info("Registration result for #{account_uuid}: #{inspect(result)}")
      
      case result do
        {:ok, _success} ->
          # 注册成功
          Logger.info("Successfully registered account #{account_uuid} on #{site}")
          
          # 更新账户信息
          MnesiaKV.merge(Account, account_uuid, %{
            registered_site: site,
            registration_info: %{
              username: username,
              password: password,
              registration_time: DateTime.utc_now() |> DateTime.to_string(),
              batch_id: batch_id
            }
          })
          
          # 通知Actor注册成功
          notify_registration_completed(account_uuid, true)
          
        {:failed, reason} ->
          # 注册失败
          Logger.warn("Failed to register account #{account_uuid} on #{site}: #{reason}")
          
          # 通知Actor注册失败
          notify_registration_completed(account_uuid, false, reason)
          
        {:error, log_path} ->
          # 出现错误
          Logger.error("Error registering account #{account_uuid} on #{site}, check log: #{log_path}")
          
          # 通知Actor注册错误
          notify_registration_completed(account_uuid, false, "registration_error")
      end
    end
    
    # 生成随机密码
    defp generate_password() do
      # 生成10位随机密码(字母数字混合)
      for _ <- 1..10, into: "", do: <<Enum.random('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789')>>
    end
    
    # 通知注册完成
    defp notify_registration_completed(account_uuid, success, reason \\ nil) do
      # 获取AutoRegister实例的PID
      case :pg.get_members(PGActorAll, Actor.AutoRegister) do
        [pid | _] -> 
          send(pid, {:registration_completed, account_uuid, success, reason})
        _ -> 
          Logger.error("Cannot find AutoRegister actor process")
      end
    end
    
    # 处理注册完成消息
    def message({:registration_completed, account_uuid, success, reason}, state) do
      # 确保状态中的关键字段有效
      state = ensure_valid_state(state)
      
      if Map.has_key?(state.in_progress, account_uuid) do
        # 从in_progress中移除
        {registration_data, new_in_progress} = Map.pop(state.in_progress, account_uuid)
        
        if success do
          # 添加到已完成列表
          new_completed = [account_uuid | state.completed]
          # 记录成功信息
          Logger.info("Registration completed for #{account_uuid} on #{registration_data.site}")
          %{state | in_progress: new_in_progress, completed: new_completed}
        else
          # 记录失败原因
          Logger.warn("Registration failed for #{account_uuid} on #{registration_data.site}: #{reason}")
          
          # 检查是否可以重试
          max_retries = get_in(state, [:config, :max_retries]) || 2
          
          if registration_data.retries < max_retries do
            # 可以重试，放回队列前端
            Logger.info("Scheduling retry #{registration_data.retries + 1}/#{max_retries} for #{account_uuid}")
            new_queue = [account_uuid | state.registration_queue]
            %{state | in_progress: new_in_progress, registration_queue: new_queue}
          else
            # 不能重试，添加到失败列表
            Logger.warn("Max retries reached for #{account_uuid}, marking as failed")
            new_failed = [account_uuid | state.failed]
            %{state | in_progress: new_in_progress, failed: new_failed}
          end
        end
      else
        # 未知的账户ID，忽略
        Logger.warn("Received completion for unknown account: #{account_uuid}")
        state
      end
    end
    
    # 处理其他消息
    def message(msg, state) do
      # 记录未知消息
      Logger.warn("Received unknown message: #{inspect(msg)}")
      # 确保返回的状态有效
      ensure_valid_state(state)
    end
    
    # 获取注册状态
    def get_status(uuid) do
      actor = MnesiaKV.get(Actor, uuid)
      
      if actor do
        # 确保fields存在，防止错误
        in_progress = Map.get(actor, :in_progress, %{})
        in_progress = if is_map(in_progress), do: in_progress, else: %{}
        
        registration_queue = Map.get(actor, :registration_queue, [])
        registration_queue = if is_list(registration_queue), do: registration_queue, else: []
        
        completed = Map.get(actor, :completed, [])
        completed = if is_list(completed), do: completed, else: []
        
        failed = Map.get(actor, :failed, [])
        failed = if is_list(failed), do: failed, else: []
        
        # 返回详细状态
        %{
          queue_size: length(registration_queue),
          in_progress: map_size(in_progress),
          completed: length(completed),
          failed: length(failed),
          sites: actor.sites,
          config: actor.config,
          # 添加详细信息
          in_progress_details: in_progress,
          last_completed: Enum.take(completed, 5),
          last_failed: Enum.take(failed, 5),
          batch_id: actor.batch_id
        }
      else
        # 返回默认空状态
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
    
    # 重置状态
    def reset(uuid) do
      MnesiaKV.merge(Actor, uuid, %{
        last_register: 0,
        registration_queue: [],
        in_progress: %{},
        completed: [],
        failed: []
      })
    end
    
    # 添加: 打印当前状态的调试函数
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
        
        # 输出正在进行中的注册
        if map_size(actor.in_progress || %{}) > 0 do
          Logger.info("--- Current In-Progress Registrations ---")
          Enum.each(actor.in_progress || %{}, fn {account_id, data} ->
            Logger.info("#{account_id} -> site: #{data.site}, started: #{DateTime.from_unix!(div(data.start_time, 1000))}")
          end)
        end
        
        :ok
      else
        Logger.error("AutoRegister actor #{uuid} not found")
        :error
      end
    end
    
    # 添加: 获取已完成的注册详情
    def get_completed_details(uuid) do
      actor = MnesiaKV.get(Actor, uuid)
      
      if actor do
        completed_accounts = actor.completed || []
        
        # 获取已完成账户的详细信息
        Enum.map(completed_accounts, fn account_uuid ->
          account = MnesiaKV.get(Account, account_uuid)
          if account do
            %{
              uuid: account_uuid,
              email: get_in(account, [:keep, :email]),
              site: account.registered_site,
              username: get_in(account, [:registration_info, :username]),
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
  end