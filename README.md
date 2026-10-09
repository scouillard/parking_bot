# Parking bot

Registers every plate in `config/plates.yml` on each date in `config/dates.yml`, then emails each plate's owner the parking confirmation. It runs as the `parking_bot` systemd service and waits between dates.

## Setup

The repo has no plates, dates or tokens, so you add your own files. Each one has an example to copy:

```bash
cp .env.example .env
cp config/plates.example.yml config/plates.yml
cp config/dates.example.yml config/dates.yml
```

All three copies are gitignored. The bot won't start until all of them exist and `.env` has both tokens.

### `.env`

```bash
PARKING_TAP_TOKEN=...          # the parking poster's tap token
PARKING_DISCOUNT_CODE_ID=...   # numeric ID of the discount code
```

On a laptop you can also set `PARKING_BOT_SSH` (see [Running from a laptop](#running-from-a-laptop)). Never set it on the server.

### `config/plates.yml`

A list of cars. `plate` is letters and digits only, no spaces. `email` gets the confirmation:

```yaml
- plate: "ABC123"
  email: "friend@example.com"
- plate: "XYZ789"
  email: "other@example.com"
```

### `config/dates.yml`

A list of quoted `"YYYY-MM-DD HH:MM"` times, in **Eastern time**. Every plate is registered at each time:

```yaml
- "2026-10-14 21:00"
- "2026-10-21 19:00"
```

Dates already past when the bot starts are skipped, never run late.

### `config/parking.yml` (tracked)

`discount` and `fee` are sent to the parking site as is with every registration. Change them only if the site's parameters change.

## Editing dates and plates

Use the scripts rather than editing the YAML by hand. They check everything before saving, drop past dates, and restart the service once so the bot reloads its config. A hand edit only takes effect after `systemctl restart parking_bot`.

```bash
bin/dates                                              # list upcoming dates
bin/dates new "14.10.2026 21:00" "21.10.2026 19:00"    # add dates (day.month.year hour:minute, Eastern)
bin/dates remove "14.10.2026 21:00"                    # remove dates

bin/plates                                             # list plates
bin/plates new ABC123 friend@example.com               # add plates, or change a plate's email
bin/plates new ABC123 a@example.com XYZ789 b@example.com
bin/plates remove ABC123 XYZ789                        # remove plates
```

If one value is invalid, the whole command stops and nothing is saved. A date that's already scheduled, or a plate that isn't in the list, is noted and skipped.

## Running from a laptop

Set `PARKING_BOT_SSH` in your laptop's `.env` to the server's SSH login, e.g. `root@your-server`. The same `bin/dates` and `bin/plates` commands then run on the server over SSH, with your normal SSH key. `PARKING_BOT_DIR` (default `parking_bot`, relative to the SSH user's home) and `PARKING_BOT_SSH_KEY` are optional.

## Server

- Ruby with the `nokogiri` and `rufus-scheduler` gems, e.g. `apt install ruby ruby-nokogiri` and `gem install rufus-scheduler`.
- A systemd unit at `/etc/systemd/system/parking_bot.service`:

  ```ini
  [Unit]
  Description=Parking Bot
  After=network.target

  [Service]
  ExecStart=/usr/bin/ruby /root/parking_bot/bin/parking_bot.rb
  Restart=always
  User=root
  WorkingDirectory=/root/parking_bot/bin
  Environment=TZ=America/New_York
  StandardOutput=append:/root/parking_bot/parking_bot.log
  StandardError=append:/root/parking_bot/parking_bot.log

  [Install]
  WantedBy=multi-user.target
  ```

  `TZ=America/New_York` is required: the bot reads the dates in the server's time zone, so on a UTC server they'd fire hours early.
- `systemctl daemon-reload && systemctl enable --now parking_bot`.
- **Run it on one server only.** Two copies would register every plate twice and send two emails.

Logs: `parking_bot.log` (service output) and `log/logs.log` (timestamped results), both gitignored.
