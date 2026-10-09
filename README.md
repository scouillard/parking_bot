# Parking bot

Registers every plate in `config/plates.yml` on each date in `config/dates.yml` (Eastern time), then emails each owner a confirmation. Runs as the `parking_bot` systemd service with `TZ=America/New_York`, on system Ruby with the `nokogiri` and `rufus-scheduler` gems.

## Setup

Copy `.env.example` to `.env` and set `PARKING_TAP_TOKEN` and `PARKING_DISCOUNT_CODE_ID`; the bot won't start without them. `config/parking.yml` holds the rest of the parking settings. `.env`, `config/plates.yml` and `config/dates.yml` are gitignored.

## Editing dates and plates

```bash
bin/dates                                              # list upcoming dates
bin/dates new "14.10.2026 21:00" "21.10.2026 19:00"    # add dates (day.month.year hour:minute)
bin/dates remove "14.10.2026 21:00"                    # remove dates

bin/plates                                             # list plates
bin/plates new ABC123 friend@example.com               # add plates, or change a plate's email
bin/plates remove ABC123 XYZ789                        # remove plates
```

Each change is checked in full before anything is saved, drops past dates, and restarts the service once so the bot picks it up.

## Running them from your laptop

Set `PARKING_BOT_SSH` in your laptop's `.env` to the server's SSH login. The same `bin/dates` and `bin/plates` commands then run on the server over SSH, using your normal SSH key. Never set `PARKING_BOT_SSH` in the server's `.env`.
