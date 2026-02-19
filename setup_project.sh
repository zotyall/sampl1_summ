#!/bin/bash

# ============================================================
# setup_project.sh - Attendance Tracker Project Bootstrap
# Usage: ./setup_project.sh
# (Project label is entered interactively when prompted)
# ============================================================

# --- 1. Prompt User for Input ---
echo ""
echo "============================================"
echo " Attendance Tracker Project Bootstrap"
echo "============================================"
read -p " Enter a project label (e.g. v1, beta, prod): " INPUT

if [ -z "$INPUT" ]; then
    echo "Error: Project label cannot be empty."
    exit 1
fi
PROJECT_DIR="attendance_tracker_${INPUT}"

echo " Project Dir   : $PROJECT_DIR"
echo "============================================"
echo ""

# --- 2. Signal Trap (SIGINT / Ctrl+C) ---
cleanup() {
    echo ""
    echo "⚠  Interrupt received! Bundling current state and cleaning up..."

    ARCHIVE_NAME="attendance_tracker_${INPUT}_archive.tar.gz"

    if [ -d "$PROJECT_DIR" ]; then
        tar -czf "$ARCHIVE_NAME" "$PROJECT_DIR" 2>/dev/null
        rm -rf "$PROJECT_DIR"
        echo "✔  Incomplete project archived as: $ARCHIVE_NAME"
        echo "✔  Project directory removed."
    else
        echo "   No project directory found to archive."
    fi

    echo "   Exiting."
    exit 1
}

trap cleanup SIGINT

# --- 3. Guard Against Existing Directory ---
if [ -d "$PROJECT_DIR" ]; then
    echo "Error: Directory '$PROJECT_DIR' already exists. Remove it first or choose a different label."
    exit 1
fi

# --- 4. Create Directory Architecture ---
echo "[1/4] Creating directory structure..."
mkdir -p "$PROJECT_DIR/Helpers"
mkdir -p "$PROJECT_DIR/reports"
echo "      ✔  attendance_tracker_${INPUT}/"
echo "      ✔  attendance_tracker_${INPUT}/Helpers/"
echo "      ✔  attendance_tracker_${INPUT}/reports/"

# --- 5. Generate attendance_checker.py ---
echo "[2/4] Generating source files..."

cat << 'PYEOF' > "$PROJECT_DIR/attendance_checker.py"
import csv
import json
import os
from datetime import datetime


def run_attendance_check():
    # 1. Load Config
    with open('Helpers/config.json', 'r') as f:
        config = json.load(f)

    # 2. Archive old reports.log if it exists
    if os.path.exists('reports/reports.log'):
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        os.rename(
            'reports/reports.log',
            f'reports/reports_{timestamp}.log.archive'
        )

    # 3. Process Data
    with open('Helpers/assets.csv', mode='r') as f, \
         open('reports/reports.log', 'w') as log:

        reader = csv.DictReader(f)
        total_sessions = config['total_sessions']
        log.write(f"--- Attendance Report Run: {datetime.now()} ---\n")

        for row in reader:
            name      = row['Names']
            email     = row['Email']
            attended  = int(row['Attendance Count'])

            attendance_pct = (attended / total_sessions) * 100
            message = ""

            if attendance_pct < config['thresholds']['failure']:
                message = (
                    f"URGENT: {name}, your attendance is "
                    f"{attendance_pct:.1f}%. You will fail this class."
                )
            elif attendance_pct < config['thresholds']['warning']:
                message = (
                    f"WARNING: {name}, your attendance is "
                    f"{attendance_pct:.1f}%. Please be careful."
                )

            if message:
                if config['run_mode'] == "live":
                    log.write(
                        f"[{datetime.now()}] ALERT SENT TO {email}: {message}\n"
                    )
                    print(f"Logged alert for {name}")
                else:
                    print(f"[DRY RUN] Email to {email}: {message}")


if __name__ == "__main__":
    run_attendance_check()
PYEOF

# --- 6. Generate Helpers/assets.csv ---
cat << 'EOF' > "$PROJECT_DIR/Helpers/assets.csv"
Names,Email,Attendance Count
Alice Johnson,alice@example.com,38
Bob Smith,bob@example.com,28
Carol White,carol@example.com,20
David Brown,david@example.com,15
Eve Davis,eve@example.com,10
EOF

# --- 7. Generate Helpers/config.json (with default thresholds) ---
cat << 'EOF' > "$PROJECT_DIR/Helpers/config.json"
{
    "total_sessions": 40,
    "thresholds": {
        "warning": 75,
        "failure": 50
    },
    "run_mode": "live"
}
EOF

# --- 8. Generate reports/reports.log ---
touch "$PROJECT_DIR/reports/reports.log"

echo "      ✔  attendance_checker.py"
echo "      ✔  Helpers/assets.csv"
echo "      ✔  Helpers/config.json"
echo "      ✔  reports/reports.log"

# --- 9. Dynamic Configuration via sed ---
echo ""
echo "[3/4] Threshold Configuration"
echo "      Current defaults → Warning: 75%  |  Failure: 50%"
echo ""

read -p "      Do you want to update the attendance thresholds? (y/n): " UPDATE_CHOICE

if [[ "$UPDATE_CHOICE" == "y" || "$UPDATE_CHOICE" == "Y" ]]; then

    read -p "      Enter new Warning threshold (current: 75): " NEW_WARNING
    read -p "      Enter new Failure threshold (current: 50): " NEW_FAILURE

    # Validate numeric input
    if ! [[ "$NEW_WARNING" =~ ^[0-9]+$ ]] || ! [[ "$NEW_FAILURE" =~ ^[0-9]+$ ]]; then
        echo "      ✘  Invalid input. Thresholds must be integers. Keeping defaults."
    else
        # In-place sed edits on config.json
        sed -i "s/\"warning\": [0-9]*/\"warning\": $NEW_WARNING/" \
            "$PROJECT_DIR/Helpers/config.json"
        sed -i "s/\"failure\": [0-9]*/\"failure\": $NEW_FAILURE/" \
            "$PROJECT_DIR/Helpers/config.json"

        echo "      ✔  config.json updated → Warning: ${NEW_WARNING}%  |  Failure: ${NEW_FAILURE}%"
    fi

else
    echo "      Keeping default thresholds (Warning: 75%, Failure: 50%)."
fi

# --- 10. Environment Validation (Health Check) ---
echo ""
echo "[4/4] Environment Health Check"

# Python check
python3 --version > /dev/null 2>&1
if [ $? -eq 0 ]; then
    PY_VERSION=$(python3 --version 2>&1)
    echo "      ✔  Python detected: $PY_VERSION"
else
    echo "      ⚠  Python3 not found. Install it to run attendance_checker.py."
fi

# Directory structure verification
STRUCTURE_OK=true
for EXPECTED in \
    "$PROJECT_DIR/attendance_checker.py" \
    "$PROJECT_DIR/Helpers/assets.csv" \
    "$PROJECT_DIR/Helpers/config.json" \
    "$PROJECT_DIR/reports/reports.log"; do
    if [ ! -e "$EXPECTED" ]; then
        echo "      ✘  Missing: $EXPECTED"
        STRUCTURE_OK=false
    fi
done

if [ "$STRUCTURE_OK" = true ]; then
    echo "      ✔  Directory structure verified successfully."
fi

# --- Done ---
echo ""
echo "============================================"
echo " Setup Complete!"
echo " Project ready at: ./$PROJECT_DIR"
echo ""
echo " To run the tracker:"
echo "   cd $PROJECT_DIR && python3 attendance_checker.py"
echo ""
echo " To trigger archive manually (simulate interrupt):"
echo "   Press Ctrl+C while the script is running."
echo "============================================"
echo ""
