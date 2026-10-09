# Parking bot

Registers every plate in `config/plates.yml` on each date in `config/dates.yml` (Eastern time), then emails each owner a confirmation. Runs as the `parking_bot` systemd service.

Both config files are gitignored. Edit them with:

```bash
bin/dates                                              # list upcoming dates
bin/dates new "14.10.2026 21:00" "21.10.2026 19:00"    # add dates (day.month.year hour:minute)
bin/dates remove "14.10.2026 21:00"                    # remove dates

bin/plates                                             # list plates
bin/plates new ABC123 friend@example.com               # add plates, or change a plate's email
bin/plates remove ABC123 XYZ789                        # remove plates
```

Each change is checked in full before anything is saved, drops past dates, and restarts the service once so the bot picks it up.
