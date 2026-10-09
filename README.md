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

On a laptop you can also set `PARKING_BOT_SSH` (see [Running from a laptop](#running-from-a-laptop)). Never set it on the server.

### Where the parking values come from

Registering a plate is the same request the parking poster's web form sends, with the discount covering the whole cost.

- **Tap token** (`PARKING_TAP_TOKEN`): the last part of the poster's page, `https://hotspotparking.com/tapPoster/park/<tap token>`, which the NFC tag or QR code on the parking poster opens. It has changed between seasons (it ends in a number that goes up), so check the poster if registrations start failing.
- **Discount code ID** (`PARKING_DISCOUNT_CODE_ID`): the league hands out a discount code each season, letters plus the year (e.g. `ABCD26`). The form never sends the code itself, only its numeric ID. The poster page embeds every valid code and its ID in its JavaScript:

  ```js
  let discountCodes = {"1234":"ABCD26","1235":"EFGH26"};
  ```

  When you type a code, the form looks up its ID there. `bin/discount` does the same lookup, once, when you set a new code:

  ```bash
  bin/discount ABCD26    # find the code's ID on the poster page, save both to .env, restart the bot
  bin/discount           # check that the code in .env is still listed with the same ID
  ```

  The bot itself never looks codes up; it sends the saved ID. The ID changes whenever the code does (each season), and the old one stops working, so **run `bin/discount <new code>` at the start of each season**. Codes are case-insensitive. `bin/discount` only says whether your code is listed: the page lists other groups' codes too, and those aren't ours to use.
- **Fixed parameters** (`lib/plate_registrar.rb`): `time=3` (hours), `discount=1000` and `fee=NaN`. The form gets the discount from `/TapPoster/dropdownRate` (hours, tap token, discount code ID, plate) and sends the usage fee from a field that's empty, which `parseInt` turns into `NaN`. If the site changes its rates and registrations fail, compare what the form sends (browser dev tools, Network tab, `startParkingSession`) with these.

After registering, the site redirects to `/purchase_success/<reference>`. The bot then sends the confirmation email with the form's CSRF token (`/tapPoster/sendReceipt`).

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

Shows whether the bot is running, when the schedule sync last ran (and what it changed) and runs next, the discount code and ID in `.env`, every upcoming parking time with its game, and the plates. It changes nothing.

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

From a laptop, prefix any of them with SSH: `ssh root@your-server 'systemctl restart parking_bot'`. `bin/dates` and `bin/plates` already restart the bot themselves.

## Running from a laptop

Set `PARKING_BOT_SSH` in your laptop's `.env` to the server's SSH login, e.g. `root@your-server`. The same `bin/status`, `bin/dates`, `bin/plates` and `bin/discount` commands then run on the server over SSH, with your normal SSH key. `PARKING_BOT_DIR` (default `parking_bot`, relative to the SSH user's home) and `PARKING_BOT_SSH_KEY` are optional.

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
