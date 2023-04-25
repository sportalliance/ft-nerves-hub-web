# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     NervesHubWebCore.Repo.insert!(%NervesHubWWW.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

# The seeds are run on every deploy. Therefore, it is important
# that first check to see if the data you are trying to insert
# has been run yet.
alias NervesHubWebCore.{Accounts, Accounts.User, Repo, Firmwares}

defmodule NervesHubWebCore.SeedHelpers do
  alias NervesHubWebCore.Fixtures

  def seed_product(product_name, user, org) do
    product = Fixtures.product_fixture(user, org, %{name: product_name})

    firmware_versions = ["0.1.0", "0.1.1", "0.1.2", "1.0.0"]

    org_with_keys_and_users =
      org |> NervesHubWebCore.Accounts.Org.with_org_keys() |> Repo.preload(:users)

    org_keys = org_with_keys_and_users |> Map.get(:org_keys)
    user_names = org_with_keys_and_users |> Map.get(:users) |> Enum.map(fn x -> x.username end)

    firmwares =
      for v <- firmware_versions,
          do:
            Fixtures.firmware_fixture(Enum.random(org_keys), product, %{
              version: v,
              author: Enum.random(user_names)
            })

    firmwares = firmwares |> List.to_tuple()

    Fixtures.deployment_fixture(org_with_keys_and_users, firmwares |> elem(2), %{
      conditions: %{"version" => "< 1.0.0", "tags" => ["beta"]}
    })

    Firmwares.update_firmware_ttl(elem(firmwares, 2).id)

    Fixtures.device_fixture(org, product, firmwares |> elem(1), %{last_communication: DateTime.utc_now()})
    |> Fixtures.device_certificate_fixture()
  end

  def nerves_team_seed(root_user_params) do

    user = Fixtures.user_fixture(root_user_params)
    [default_user_org | _] = Accounts.get_user_orgs(user)
    org = Fixtures.org_fixture(user, %{name: "NervesTeam"})
    for _ <- 0..2, do: Fixtures.org_key_fixture(org)
    for _ <- 0..2, do: Fixtures.org_key_fixture(default_user_org)

    ["SmartKiosk", "SmartRentHub"]
    |> Enum.map(fn name -> seed_product(name, user, org) end)

    ["ToyProject", "ConsultingProject"]
    |> Enum.map(fn name -> seed_product(name, user, default_user_org) end)
  end
end

defmodule NervesHubWebCore.SPASeedHelper do
  alias NervesHubWebCore.Fixtures

  alias NervesHubWebCore.{
    Accounts,
    Devices,
    Firmwares,
    Products
  }

  def spa_test_seed(root_user_params) do
    user = Fixtures.user_fixture(root_user_params)
    org = Fixtures.org_fixture(user, %{name: "SPA"})

    Fixtures.org_key_fixture(org)


    set_user_token(user)

    seed_product("FT-Access", user, org, "ft-access")
    seed_product("FT-Vending", user, org, "ft-vending")

    params = %{org_id: org.id}
    {:ok, org_key} =
      Accounts.create_org_key(params |> Map.put(:key, "LzvJ/5Bf7p4o+3q9ftlhyqtcMyZvjAQwwVie1rC6vZk=") |> Map.put(:name, "devkey"))

  end

  def set_user_token(user) do
    test_token = System.get_env("USER_TEST_TOKEN") || "nhu_0005h8y2Y4ClYbUJy7EBUePDIQESyw1yi8ty"
    attrs = %{note: test_token}
    %NervesHubWebCore.Accounts.UserToken{user_id: user.id}
    |> Ecto.Changeset.cast(attrs, [:note, :user_id])
    |> Ecto.Changeset.put_change(:token, test_token)
    |> Ecto.Changeset.validate_required([:token, :note, :user_id])
    |> Ecto.Changeset.validate_format(:token, ~r/^nhu_[a-zA-Z0-9]{36}$/)
    |> Ecto.Changeset.foreign_key_constraint(:user_id)
    |> Ecto.Changeset.unique_constraint(:token)
    |> Repo.insert()
  end

  def seed_product(product_name, user, org, device_id) do
    product = Fixtures.product_fixture(user, org, %{name: product_name})

    firmware_versions = ["0.1.0", "0.1.1", "0.1.2", "1.0.0"]
    device_params = %{identifier: device_id, device_params: %{tags: ["prod"]}}

    org_with_keys_and_users =
      org |> NervesHubWebCore.Accounts.Org.with_org_keys() |> Repo.preload(:users)

    org_keys = org_with_keys_and_users |> Map.get(:org_keys)
    user_names = org_with_keys_and_users |> Map.get(:users) |> Enum.map(fn x -> x.username end)

    firmwares =
      for v <- firmware_versions,
          do:
            Fixtures.firmware_fixture(Enum.random(org_keys), product, %{
              version: v,
              author: Enum.random(user_names)
            })

    firmwares = firmwares |> List.to_tuple()

    Fixtures.deployment_fixture(org_with_keys_and_users, firmwares |> elem(2), %{
      conditions: %{"version" => "< 1.0.0", "tags" => ["prod"]}
    })

    Firmwares.update_firmware_ttl(elem(firmwares, 2).id)

    cert =
      ssl_dir()
      |> Path.join("#{device_id}.pem")
      |> File.read!()
      |> X509.Certificate.from_pem!()

    spa_device_fixture(org, product, firmwares |> elem(1), device_params, %{last_communication: DateTime.utc_now()})
    |> Fixtures.device_certificate_fixture(cert)
  end

  def ssl_dir do
    (System.get_env("NERVES_HUB_CA_DIR") || Path.join(__DIR__, "../../../../../spa-nerves-hub-ca/etc/ssl"))
  |> Path.expand()
  end

  def spa_device_fixture(
        %Accounts.Org{} = org,
        %Products.Product{} = product,
        %Firmwares.Firmware{} = firmware,
        %{identifier: identifier, device_params: device_params},
        params \\ %{}
      ) do
    {:ok, metadata} = Firmwares.metadata_from_firmware(firmware)

    {:ok, device} =
      %{
        org_id: org.id,
        product_id: product.id,
        firmware_metadata: metadata,
        identifier: identifier
      }
      |> Enum.into(params)
      |> Enum.into(device_params)
      |> Devices.create_device()

    device
  end
end

# Create the root user
root_user_name = "nerveshub"
root_user_email = "nerveshub@nerves-hub.org"
# Add a default user
if root_user = Repo.get_by(User, email: root_user_email) do
  root_user
else
  env =
    if function_exported?(Mix, :env, 0) do
      Mix.env() |> to_string()
    else
      System.get_env("ENVIRONMENT")
    end

  if env == "dev" do
    NervesHubWebCore.SPASeedHelper.spa_test_seed(%{
      email: root_user_email,
      username: root_user_name,
      password: root_user_name
    })
  else
    Accounts.create_user(%{
      username: root_user_name,
      email: root_user_email,
      password: "nerveshub"
    })
  end
end
