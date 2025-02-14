# nerves_hub_www

[![CircleCI](https://circleci.com/gh/nerves-hub/nerves_hub_web/tree/main.svg?style=svg)](https://circleci.com/gh/nerves-hub/nerves_hub_web/tree/main)
[![Coverage Status](https://coveralls.io/repos/github/nerves-hub/nerves_hub_web/badge.svg?branch=main)](https://coveralls.io/github/nerves-hub/nerves_hub_web?branch=main)

This is the source code for the NervesHub firmware update and device management
server.

*Important*

The public NervesHub instance at `nerves-hub.org` was turned off on March 31st,
2022. See [NervesHub Sunset](https://elixirforum.com/t/action-advised-nerveshub-sunset/42925).
NervesHub is still actively developed and used. Many of us run NervesHub
instances internally at our companies and really like it.

## Project overview and setup

### Development environment setup

If you haven't already, make sure that your development environment has
Elixir >= 1.11, Erlang 22, and NodeJS.

You'll also need `fwup` and can follow [these installation instructions](https://github.com/fhunleth/fwup#installing) for your platform if needed.

Additionally you will need to install [xdelta3](https://github.com/jmacd/xdelta).

The instructions below use `asdf` which can be installed with the
instructions below ([copied from asdf-vm.com](https://asdf-vm.com/#/core-manage-asdf-vm))

```sh
git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.11.0
# The following steps are for Bash, which is usually the default shell
# If you’re using something else, you probably know the equivalent thing you need to do echo -e '\n. $HOME/.asdf/asdf.sh' >> ~/.bashrc
echo -e '\n. $HOME/.asdf/completions/asdf.bash' >> ~/.bashrc
```

Here are steps for the NodeJS setup if you're using `asdf`:

```sh
cd nerves_hub_web
asdf plugin-add nodejs
bash ~/.asdf/plugins/nodejs/bin/import-release-team-keyring # this requires gpg to be installed
asdf install $(cat .tool-versions | grep nodejs)
```

On Debian/Ubuntu, you will also need to install the following packages:

```sh
sudo apt install docker-compose inotify-tools
```

Local development uses the host `nerves-hub.org` for connections and cert validation. To properly map to your local running server, you'll need to add a host record for it:

```sh
echo "127.0.0.1 nerves-hub.org" | sudo tee -a /etc/hosts
```

### Dependent application setup

NervesHub is designed to run in conjunction with another application [nerves_hub_ca](https://github.com/nerves-hub/nerves_hub_ca).
This application runs on port `8443` and it handles user's certificates. It can also be used to create a suit of certificates that
is needed in order to run both applications. When you create certificates from `nerves_hub_ca` place them in dir:
`nerves_hub_web/test/fixtures/ssl`.

### Local testing
Testing with `ft-reader` and `ft-reader-provisioning-service` requires custom certificates which can be generated from the [spa-nerves-hub-ca](https://github.com/sportalliance/spa-nerves-hub-ca) project from the `test-certs` branch. When new certificates are generated, make sure to rebuild the database with `make reset-db`. Then FT-Access and FT-Vending device will be regenerated with the new certificates. 

Also check the global elixir and erlang settings with `asdf list erlang` and `asdf list elixir` . These versions are used for testing.

Project structure:
github-project-folder
- [ft-reader](https://github.com/sportalliance/ft-reader)
- [ft-reader-provisioning-service](https://github.com/sportalliance/ft-reader-provisioning-service)
- [ft-nerves-hub-web](https://github.com/sportalliance/ft-nerves-hub-web)
- [spa-nerves-hub-ca](https://github.com/sportalliance/spa-nerves-hub-ca)

all project should be checkout out locally. Then the test-certs should be generated in the `spa-nerves-hub-ca` project (branch `test-certs`) with `mix nerves_hub_ca.init --host nerves-hub.org`

All other projects (ft-reader, ft-reader-provisioning-service and ft-nerves-hub-web) use these certificates for testing.
Testing the `ft-reader` project on the hardware requires a local dns resolver which resolves the 
`device.nerves-hub.org` and `provisioning.nerves-hub.org` to the host (MacBook).

#### Option 1 (works only in "host" mode, where ft-access runs on the MacBook)

add `/etc/hosts` entries

```text
127.0.0.1 nerves-hub.org
127.0.0.1 provisioning.nerves-hub.org
127.0.0.1 device.nerves-hub.org
127.0.0.1 api.nerves-hub.org
```

#### Option 2 Full test setup

add the domains above to a local dns resolver and point them to the local's MacBook ip address.
Then the hardware modules can be fully tested and firmware updates work as well.
A FT-Access/Vending devices can be added to Nerveshub:

1. ssh into the access/vending
2. run `FittrackNervesHubLink.Configurator.generate_cert_csv`
3. copy the output into a text editor and save it as csv file.
4. login to the local Nerveshub web interface:
   1. go to FT-Access/Vending device overview
   2. press `Import`
   3. under `Upload a CSV file` upload the generated CSV file
   4. The certificate should be detected and the device can be added
   5. Press import (red arrow next to the device) or `Import all`
   6. done
   7. Keep the csv file as the device would be deleted if `make reset-db` is called.

### First time application setup

1. Setup database connection

     NervesHub currently runs with Postgres 10.7. For development, you can use a local postgres or use the configured docker image:

     **Using Docker**

     * Create directory for local data storage: `mkdir ~/db`
     * Copy `dev.env` to `.env` and customize as needed: `cp dev.env .env`
     * Start the database (may require sudo): `docker compose --env-file /dev/null up -d`

     **Using local postgres**

     * Make sure your postgres is running
     * Copy `dev.env` to `.env` with `cp dev.env .env`
     * Change any of the `DB_*` variables as needed in your `.env`. For local running postgres, you would typically use these settings:

     ```bash
     DB_USER=postgres
     DB_PASSWORD="" # in some cases, this might not be blank
     DB_PORT=5432
     ```

2. Fetch dependencies: `mix do deps.get, compile`
3. Initialize the database: `make reset-db`
4. Compile web assets (this only needs to be done once and requires python2):
   `mix assets.install`

### Starting the application

* `make server` - start the server process
* `make iex-server` - start the server with the
   interactive shell

> **_Note_**: The whole app may need to be compiled the first time you run this, so please be patient

### Running Tests

1. Make sure you've completed your [database connection setup](#development-environment-setup)
2. Fetch and compile `test` dependencies: `MIX_ENV=test mix do deps.get, compile`
3. Initialize the test databases: `make reset-test-db`
4. Run tests: `make test`


### Client-side SSL device authorization

NervesHub uses Client-side SSL to authorize and identify connected devices.
Devices are required to provide a valid certificate that was signed using the
trusted certificate authority NervesHub certificate. This certificate should be
generated and kept secret and private from Internet-connected servers.

For convenience, we use the pre-generated certificates for `dev` and `test`.
Production certificates can be generated by following the SSL certificate
instructions in `test/fixtures/README.md` and setting the following environment
variables to point to the generated key and certificate paths on the server.

```text
NERVESHUB_SSL_KEY
NERVESHUB_SSL_CERT
NERVESHUB_SSL_CACERT
```

### Tags

Tags are arbitrary strings, such as `"stable"` or `"beta"`. They can be added to
Devices and Firmware.

For a Device to be considered eligible for a given Deployment, it must have
*all* the tags in the Deployment's "tags" condition.

### Potential SSL issues

OTP > 24.2.2 switched to use TLS1.3 by default and made quite a few fixes/changes
to how it is implemented in the `:ssl` module. This has affected the setup of
client authentication in a few different ways depending on how you have your
server and device configured:

| Server | Client | Effect |
| --- | --- | --- |
|TLS1.3 | TLS1.3| `certificate_required` error (needs OTP 25.2 - see https://github.com/erlang/otp/issues/6106)  |
|TLS1.3|TLS1.2|  `CLIENT ALERT: Fatal - Handshake Failure - :unacceptable_ecdsa_key` - Happens because the client is attempting to sign with `:she` as the signature algorithm. The workaround is to specify `ssl: [signature_algs: [{:sha256, :ecdsa},{:sha512, :ecdsa}]]`, e.g. as config for `:nerves_hub_link`. |
|TLS1.2 | TLS1.3 or TLS1.2 | Successful|
