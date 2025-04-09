defmodule Panel.AddAccs do
  def page_get() do
    "
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset=utf-8>
        <title>upload</title>
      </head>
      <body>
      <form method=POST enctype=multipart/form-data action=add_accs1>
      输入注释(年-月-日-个数): <input name=comment placeholder=例如：2023-01-01-10000><br>
      <input type=file name=accs><br>
      <input type=submit value=提交>
      </form>
      </body>
      </html>"
  end

  def page_post(body) do
    text = add_accs1(body)

    "<!DOCTYPE html><html><head><meta charset=utf-8><title>add_accs</title></head><body>#{text}</body></html>"
  end

  def parse_form_data() do
  end

  def add_accs1(body) do
    try do
      IO.inspect(body)
      [comment, accs] = String.split(body, "Content-Type: text/plain\r\n\r\n", trim: true)
      comment = String.split(comment, "\r\n", trim: true) |> Enum.at(2)
      IO.puts("add accs #{comment}")
      IO.inspect(accs)
      [year, m, d, count | _] = String.split(comment, "-")

      String.to_integer(year) && String.to_integer(m) && String.to_integer(d) &&
        String.to_integer(count)

      added = MnesiaKV.match_object(AccountBatches, {:_, %{comment: comment}})

      accs2 =
        String.split(accs)
        |> Enum.map(
          &Regex.run(
            ~r"([a-zA-Z0-9_\-\.]+@[a-zA-Z0-9_\-\.]+\.[a-zA-Z]{2,5})----(.*?)----([a-zA-Z0-9_\-\.]+@[a-zA-Z0-9_\-\.]+\.[a-zA-Z]{2,5})",
            &1
          )
        )
        |> Enum.filter(&(!!&1))
        |> Enum.map(fn [_, x, y, z] -> {x, y, z} end)
        |> Enum.uniq()

      case added do
        [] ->
          spawn(fn ->
            accs3 =
              Enum.filter(accs2, fn row ->
                doesnt_exist =
                  [] == MnesiaKV.match_object(Account, %{keep: %{email: elem(row, 0)}})

                mail_is_valid = Regex.match?(~r".*@.*\..*", elem(row, 0))
                doesnt_exist && mail_is_valid
              end)

            batch_id = :os.system_time(1000)

            accs4 = Enum.map(accs3, &add_acc(&1, batch_id, comment))

            MnesiaKV.merge(AccountBatches, batch_id, %{
              time: :os.system_time(1000),
              accs: accs4,
              comment: comment
            })
          end)

          "提交成功，后台进程正在添加中，请耐心等待。（可关闭此页面）"

        [wtf | _] ->
          "账号已存在，请勿重复提交，上次提交时间 #{DateTime.from_unix!(wtf.time + 8 * 60 * 60 * 1000, :millisecond)} （可关闭此页面）"
      end
    catch
      _, _ ->
        "提交失败，格式错误。请检查您的账号和注释的格式！"
    end
  end

  def add_acc({user, pass, helper}, batch_id, comment) do
    # match_spec =
    #  :ets.fun2ms(fn
    #    {account_id, %{keep: %{email: email}}} = account
    #    when email == "cPvQ6F7c@monkeyline.cloud" ->
    #      account
    #  end)

    # TODO: this queries are same as a loop in a loop
    # should have a key for this

    match_spec = [{{:"$1", %{keep: %{email: :"$2"}}}, [{:==, :"$2", user}], [:"$1"]}]
    prev = :ets.select(Account, match_spec)

    case prev do
      [] -> add_acc_1({user, pass, helper}, batch_id, comment)
      _ -> :duplicated
    end
  end

  def add_acc_1({user, pass, helper}, batch_id, comment) do
    acc_info =
      case MnesiaKV.match_object(AccountGrave, %{keep: %{email: user}}) do
        [] ->
          %{uuid: MnesiaKV.uuid()}

        [acc] ->
          Map.drop(acc, [:oauth_token, :blocked, :token_info, :keep])
      end

    acc_info =
      Map.merge(acc_info, %{
        keep: %{
          add_time: :os.system_time(1000),
          batch: %{
            id: batch_id,
            comment: comment
          },
          email: user,
          password: pass,
          helper: helper
        },
        blocked: nil,
        owner: :admin
      })

    MnesiaKV.merge(Account, acc_info.uuid, acc_info)
    MnesiaKV.delete(AccountGrave, acc_info.uuid)

    %{user: user, pass: pass, helper: helper, acc_entry: acc_info.uuid}
  end

  def test() do
    # accs = MnesiaKV.get(Account) |> Enum.filter(& !&1[:oauth_token] && !&1[:blocked])|> Enum.count
    # usage example
    accs = File.read!("/root/24061.txt")

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

    #
  end
end
