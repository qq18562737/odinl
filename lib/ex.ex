defmodule NC do
  use Application
  require Logger

  def load_config() do
    config = %{
      caas_port: 0,
      caas_password: Enum.map(0..20, fn x -> <<:random.uniform(25) + 65>> end) |> Enum.join("")
    }

    if File.exists?("local_config.exs") do
      {c, _} = Code.eval_file("local_config.exs")
      Map.merge(config, c)
    else
      config
    end
  end

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    Recompile.mark()

    IO.puts("populating usernames")
    path = "#{:code.priv_dir(:utilex)}/usernames"

    work_folder =
      case Application.fetch_env(:nc, :work_folder) do
        :error -> ""
        {:ok, a} -> a
      end

    path = Path.join([work_folder, "mnesia_kv/"])

    IO.puts("loading mnesia")

    MnesiaKV.load(
      %{
        Cheaper => %{
          key_type: :elixir_term
        },
        Actor => %{index: [:mod, :owner]},
        Account => %{index: [:server, :class, :proxy5]},
        AccountGrave => %{index: [:server, :class]},
        AccountChar => %{
          key_type: :elixir_term,
          index: [:account_uuid, :db_id, :server_id]
        },
        ProxyPool => %{key_type: :elixir_term},
        ProxyStaticMapping => %{key_type: :elixir_term},
        Panel => %{
          key_type: :elixir_term,
          desc: "prices and other panel settings"
        }
      },
      %{path: path}
    )

    IO.puts("- mnesia Ok")

    {:ok, supervisor} =
      Supervisor.start_link(
        [
          {DynamicSupervisor,
           strategy: :one_for_one,
           name: NC.Supervisor,
           max_seconds: 1,
           max_restarts: 999_999_999_999},
          %{id: PG, start: {:pg, :start_link, []}},
          %{
            id: PGAccount,
            start: {:pg, :start_link, [PGAccount]}
          },
          %{
            id: PGMitm,
            start: {:pg, :start_link, [PGMitm]}
          },
          %{
            id: ProxyQueue,
            start: {ProxyQueue, :start_link, []}
          },
          %{
            id: AccountLinkLock,
            start: {QLock, :start_link, [[0], AccountLinkLock]}
          }
        ],
        strategy: :one_for_one,
        max_restarts: 9_999_999_999
      )

    # 會對use Actor 的引用調用tick
    ActorSupervisor.start(NC.Supervisor, %{log_console: true, log_file: true, app_name: :nc})

    {:ok, supervisor}
  end
end
