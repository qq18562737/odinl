# Bot

**TODO: Add description**

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `ex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ex, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/ex>.

# 创建注册管理器
register_uuid = Actor.AutoRegister.create()
06b1srb2ukk609d9
# 添加注册站点 (使用实际注册页面URL)
Actor.AutoRegister.add_sites(register_uuid, [
  "targetsite.com/register",
  "anotherforum.com/signup"
])

# 添加账户到注册队列
added = Actor.AutoRegister.add_to_queue(register_uuid, 3)
IO.puts("Added #{added} accounts to registration queue")

# 检查注册状态
Actor.AutoRegister.debug(register_uuid)
ss -tulnp


# 获取详细状态
status = Actor.AutoRegister.get_status(register_uuid)
IO.inspect(status)

# 获取已完成注册的详细信息
completed = Actor.AutoRegister.get_completed_details(register_uuid)
IO.inspect(completed)
# 停止
Actor.AutoRegister.delete_all


accs = MnesiaKV.get(Account) |> Enum.filter(&(&1[:registration_info])  ) |> Enum.count
accs = MnesiaKV.get(Account) |> Enum.count
actor = MnesiaKV.get(Actor)|> Enum.count
#=====================================
    accs = File.read!("/root/1000.txt")

    (
      accs2 =
        String.split(accs)
        |> Enum.map(
          &Regex.run(
            ~r"([a-zA-Z0-9_\-\.]+@[a-zA-Z0-9_\-\.]+\.[a-zA-Z]{2,10})----(.*?)----([a-zA-Z0-9_\-\.]+@[a-zA-Z0-9_\-\.]+\.[a-zA-Z]{2,10})",
            &1
          )
        )
        |> Enum.filter(&(!!&1))
        |> Enum.map(fn [_, x, y, z] -> {x, y, z} end)
        |> Enum.uniq()

      Enum.each(accs2, fn {user, pass, helper} ->
        Panel.AddAccs.add_acc({user, pass, helper}, "batch1", "manual add")
      end)
    )


