# Attendance Tracker

A bash setup script that builds a ready-to-use student attendance tracking workspace in seconds.

---

## Requirements

- Bash (Linux or macOS)
- Python 3 — to run the checker after setup

---

## Usage
```bash
chmod +x setup_attendance_tracker.sh
./setup_attendance_tracker.sh
```

You will be asked to name your project. This creates a folder called attendance_tracker_<yourname>

## Threshold setup

During setup you can configure:

- **Warning threshold** (default 75%) — students below this get a warning
- **Failure threshold** (default 50%) — students below this get an urgent alert

You can also edit these later in `Helpers/config.json`.

---

## Running the checker
```bash
cd attendance_tracker_<yourname>
python3 attendance_checker.py
```

Set `run_mode` to `"dry"` in `config.json` to preview alerts without writing to the log.

---

## Cancelling mid-setup

Pressing `Ctrl+C` during setup will safely archive whatever was created and clean up the incomplete folder automatically.
