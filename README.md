# Parking bot

Registers every plate in `config/plates.yml` on each date in `config/dates.yml`, then emails each plate's owner the parking confirmation. It runs as the `parking_bot` systemd service and waits between dates. A daily job keeps the dates in line with the team's game schedule, 30 minutes before each game.

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
PARKING_TAP_TOKEN=...          # the parking poster's tap token (see below)
PARKING_DISCOUNT_CODE=...      # this season's discount code from the league (see below)
PARKING_DISCOUNT_CODE_ID=...   # its numeric ID: filled in by `bin/discount <code>`
SCHEDULE_TEAM_ID=...           # team_id= in the team's hockeyshift schedule URL (stays the same across divisions)
SCHEDULE_CLIENT_SERVICE_ID=... # the league site's ID (client_service_id in the site's page config)
PARKING_MINUTES_BEFORE=30      # optional, default 30
```

### Where the parking values come from

- **Tap token** (`PARKING_TAP_TOKEN`): the last part of the link the parking poster's NFC tag or QR code opens. It can change between seasons, so check the poster if registrations start failing, then set it:

  ```bash
  bin/token NEWTOKEN    # check the new poster exists, save the token, re-check the discount code, restart the bot
  bin/token             # check that the saved token's poster still loads
  ```
- **Discount code** (`PARKING_DISCOUNT_CODE`): the league hands one out each season. The parking form works with the code's numeric ID, so `bin/discount` finds it for you:

  ```bash
  bin/discount ABCD26    # find the code's ID, save both to .env, restart the bot
  bin/discount           # check that the saved code still works
  ```

  **Run `bin/discount <new code>` at the start of each season.** The old ID stops working when the code changes.
- **Fixed parameters** (`lib/plate_registrar.rb`): the parking time and the values the form sends with each registration. If the site changes and registrations fail, compare them with what the form sends (browser dev tools, Network tab).

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

Dates already past when the bot starts are skipped, never run late. With the daily sync on, you don't edit this file: see [Team schedule sync](#team-schedule-sync).

## Checking on it

```bash
bin/status
```

From a laptop: `bin/remote status`. Shows whether the bot is running, when the schedule sync last ran (and what it changed) and runs next, the discount code and ID in `.env`, every upcoming parking time with its game, and the plates. It changes nothing.

## Editing dates and plates

Use the scripts rather than editing the YAML by hand. They check everything before saving, drop past dates, and restart the service once so the bot reloads its config. A hand edit only takes effect after `systemctl restart parking_bot`.

```bash
bin/dates                                              # list upcoming dates
bin/dates new "14.10.2026 21:00" "21.10.2026 19:00"    # add dates (day.month.year hour:minute, Eastern)
bin/dates remove "14.10.2026 21:00"                    # remove dates
bin/dates sync                                         # match the team schedule now (see below)

bin/plates                                             # list plates
bin/plates new ABC123 friend@example.com               # add plates, or change a plate's email
bin/plates new ABC123 a@example.com XYZ789 b@example.com
bin/plates remove ABC123 XYZ789                        # remove plates
```

If one value is invalid, the whole command stops and nothing is saved. A date that's already scheduled, or a plate that isn't in the list, is noted and skipped.

## Team schedule sync

`bin/dates sync` reads the team's public calendar feed (the league's "subscribe to calendar" link) and makes `config/dates.yml` exactly the upcoming games, `PARKING_MINUTES_BEFORE` before each start:

- new games are added;
- past dates, and dates whose game was moved or cancelled, are removed, and so is any date added by hand that isn't a game;
- if the feed can't be read, or comes back empty or malformed, nothing changes;
- the bot restarts only when the dates change.

The `parking_bot-sync.timer` runs it every day at 06:00 Eastern, early enough that a restart can't interrupt an evening registration. Its output goes to `log/sync.log`.

## Starting, stopping and restarting the bot

The bot reads `.env`, `config/plates.yml` and `config/dates.yml` only when it starts, so **after editing any of them by hand, restart it**. On the server:

```bash
systemctl restart parking_bot          # after a manual change: reload the config
systemctl start parking_bot            # start it if it's stopped
systemctl stop parking_bot             # stop it
systemctl status parking_bot           # is it running? (q to quit)

systemctl start parking_bot-sync       # run the schedule sync now (same as bin/dates sync)
systemctl stop parking_bot-sync.timer  # pause the daily sync, e.g. to keep manual dates
systemctl start parking_bot-sync.timer # resume it

tail -f parking_bot.log                # watch the bot's output (Ctrl-C to quit)
tail log/sync.log                      # recent syncs
```

From a laptop, run them through SSH, e.g. `ssh root@your-server 'systemctl restart parking_bot'`. `bin/dates`, `bin/plates`, `bin/discount` and `bin/token` already restart the bot themselves.

## Running from a laptop

`.env` and the `config/` files live on the server, and the scripts always work on the files next to them. From a laptop, put `bin/remote` in front of any of them to run it on the server over SSH:

```bash
bin/remote status
bin/remote dates new "28.10.2026 20:00" "04.11.2026 19:30"
bin/remote plates remove ABC123
bin/remote discount ABCD26
bin/remote token NEWTOKEN
```

Tell it the server's SSH login once, in the gitignored `.remote` file:

```bash
echo root@your-server > .remote
```

It uses your normal SSH key and reuses one connection for 5 minutes, in case the server rate-limits SSH. `PARKING_BOT_SSH` overrides `.remote`, and `PARKING_BOT_DIR` sets the bot's folder on the server (default `parking_bot`, relative to the SSH user's home). The laptop needs no `.env`.

Run on a laptop without `remote`, the scripts only change that laptop's copies and say so.

## Server

- Ruby with the `nokogiri` and `rufus-scheduler` gems, e.g. `apt install ruby ruby-nokogiri` and `gem install rufus-scheduler`.
- The units in `systemd/` (paths assume the repo is at `/root/parking_bot`):

  ```bash
  cp systemd/* /etc/systemd/system/
  systemctl daemon-reload
  systemctl enable --now parking_bot parking_bot-sync.timer
  ```

  `TZ=America/New_York` in the units is required: the bot reads the dates in the server's time zone, so on a UTC server they'd fire hours early.
- Check them with `systemctl status parking_bot` and `systemctl list-timers parking_bot-sync.timer`.
- **Run it on one server only.** Two copies would register every plate twice and send two emails.

Logs: `parking_bot.log` (service output), `log/logs.log` (timestamped results) and `log/sync.log` (daily sync), all gitignored.
