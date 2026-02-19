#!/bin/bash

# Ask the user to type the project name
read -p "Enter a name for your attendance tracker: " INPUT

if [ -z "$INPUT" ]; then
    echo "Error: No input provided. Please enter a valid name."
    exit 1
fi

if [ -d "attendance_tracker_${INPUT}" ]; then
    echo "Error: Directory 'attendance_tracker_${INPUT}' already exists."
    exit 1
fi

# Handle Ctrl+C - archive the folder before quitting
handle_interrupt() {
    echo " "
    echo " Interrupt detected (SIGINT / Ctrl+C)!"
    echo "   Script was cancelled mid-execution."
    echo " "

    if [ -d "attendance_tracker_${INPUT}" ]; then
        echo " Bundling current state "
        echo " Archiving 'attendance_tracker_${INPUT}' → 'attendance_tracker_${INPUT}_archive' "

        tar -czf "attendance_tracker_${INPUT}_archive" "attendance_tracker_${INPUT}" 2>/dev/null

        if [ -f "attendance_tracker_${INPUT}_archive" ]; then
            echo " Archive created: attendance_tracker_${INPUT}_archive"
        else
            echo " Archive creation failed — skipping."
        fi

        echo " "
        echo " Cleaning up incomplete directory"
        rm -rf "attendance_tracker_${INPUT}"
        echo " Removed incomplete directory: attendance_tracker_${INPUT}"
    else
        echo "   No directory was created yet hence nothing to archive or clean."
    fi

    echo " "
    echo "  Workspace is clean. Exiting gracefully."
    exit 1
}

trap 'handle_interrupt' SIGINT SIGTERM

# Create the folder structure
mkdir -p "attendance_tracker_${INPUT}/Helpers"
mkdir -p "attendance_tracker_${INPUT}/reports"

# Create the main Python script
cat > "attendance_tracker_${INPUT}/attendance_checker.py" << 'EOF'
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
        os.rename('reports/reports.log', f'reports/reports_{timestamp}.log.archive')

    # 3. Process Data
    with open('Helpers/assets.csv', mode='r') as f, open('reports/reports.log', 'w') as log:
        reader = csv.DictReader(f)
        total_sessions = config['total_sessions']
        log.write(f"--- Attendance Report Run: {datetime.now()} ---\n")

        for row in reader:
            name = row['Names']
            email = row['Email']
            attended = int(row['Attendance Count'])

            # Simple Math: (Attended / Total) * 100
            attendance_pct = (attended / total_sessions) * 100
            message = ""

            if attendance_pct < config['thresholds']['failure']:
                message = f"URGENT: {name}, your attendance is {attendance_pct:.1f}%. You will fail this class."
            elif attendance_pct < config['thresholds']['warning']:
                message = f"WARNING: {name}, your attendance is {attendance_pct:.1f}%. Please be careful."

            if message:
                if config['run_mode'] == "live":
                    log.write(f"[{datetime.now()}] ALERT SENT TO {email}: {message}\n")
                    print(f"Logged alert for {name}")
                else:
                    print(f"[DRY RUN] Email to {email}: {message}")

if __name__ == "__main__":
    run_attendance_check()
EOF

# Create assets.csv
cat > "attendance_tracker_${INPUT}/Helpers/assets.csv" << 'EOF'
Email,Names,Attendance Count,Absence Count
alice@example.com,Alice Johnson,14,1
bob@example.com,Bob Smith,7,8
charlie@example.com,Charlie Davis,4,11
diana@example.com,Diana Prince,15,0
EOF

# Create config.json
cat > "attendance_tracker_${INPUT}/Helpers/config.json" << 'EOF'
{
    "thresholds": {
        "warning": 75,
        "failure": 50
    },
    "run_mode": "live",
    "total_sessions": 15
}
EOF

# Create reports.log
cat > "attendance_tracker_${INPUT}/reports/reports.log" << 'EOF'
--- Attendance Report Run: 2026-02-06 18:10:01.468726 ---
[2026-02-06 18:10:01.469363] ALERT SENT TO bob@example.com: URGENT: Bob Smith, your attendance is 46.7%. You will fail this class.
[2026-02-06 18:10:01.469424] ALERT SENT TO charlie@example.com: URGENT: Charlie Davis, your attendance is 26.7%. You will fail this class.
EOF

echo " Directory structure created successfully!"
tree "attendance_tracker_${INPUT}"

# Threshold Configuration
echo "  Attendance Threshold Configuration"
echo " "
echo "  Default Warning threshold : 75%"
echo "  Default Failure threshold : 50%"

read -p "Do you want to change passing score? (yes/no): " choice
if [[ "$choice" == "yes" ]]; then

    while true; do
        read -p "Enter new Warning threshold % (default 75, must be > Failure): " new_warning
        new_warning="${new_warning:-75}"
        if ! [[ "$new_warning" =~ ^[0-9]+$ ]] || [ "$new_warning" -lt 1 ] || [ "$new_warning" -gt 100 ]; then
            echo "  Invalid input. Please enter a whole number between 1 and 100."
        else
            break
        fi
    done

    while true; do
        read -p "Enter new Failure threshold % (default 50, must be < Warning): " new_failure
        new_failure="${new_failure:-50}"
        if ! [[ "$new_failure" =~ ^[0-9]+$ ]] || [ "$new_failure" -lt 1 ] || [ "$new_failure" -gt 100 ]; then
            echo "  Invalid input. Please enter a whole number between 1 and 100."
        elif [ "$new_failure" -ge "$new_warning" ]; then
            echo "  Failure threshold ($new_failure%) must be less than Warning threshold ($new_warning%)."
        else
            break
        fi
    done

    sed -i "s/\"warning\": [0-9]*/\"warning\": $new_warning/" "attendance_tracker_${INPUT}/Helpers/config.json"
    sed -i "s/\"failure\": [0-9]*/\"failure\": $new_failure/" "attendance_tracker_${INPUT}/Helpers/config.json"

    echo " "
    echo " Thresholds updated successfully!"
    echo "  Warning : ${new_warning}%"
    echo "  Failure : ${new_failure}%"
    echo " Updated config.json:"
    cat "attendance_tracker_${INPUT}/Helpers/config.json"
    echo " "

else
    echo " Keeping default thresholds (Warning: 75%, Failure: 50%)."
fi

# Environment Health Check
echo "        ENVIRONMENT HEALTH CHECK         "

HEALTH_PASS=true
echo ""
echo "  [1] Checking python3 installation..."

if command -v python3 &>/dev/null; then
    PYTHON_VERSION=$(python3 --version 2>&1)
    echo " python3 is installed   →  $PYTHON_VERSION"
else
    echo " WARNING: python3 was NOT found on this system."
    echo " The attendance_checker.py file was created, but cannot"
    echo " be executed until python3 is installed."
    echo " Install it with:  sudo apt install python3"
    HEALTH_PASS=false
fi

echo ""
echo "  [2] Verifying application directory structure..."

EXPECTED_ITEMS=(
    "attendance_tracker_${INPUT}"
    "attendance_tracker_${INPUT}/attendance_checker.py"
    "attendance_tracker_${INPUT}/Helpers"
    "attendance_tracker_${INPUT}/Helpers/assets.csv"
    "attendance_tracker_${INPUT}/Helpers/config.json"
    "attendance_tracker_${INPUT}/reports"
    "attendance_tracker_${INPUT}/reports/reports.log"
)

STRUCTURE_OK=true

for item in "${EXPECTED_ITEMS[@]}"; do
    if [ -e "$item" ]; then
        echo "  Found   →  $item"
    else
        echo "  MISSING →  $item"
        STRUCTURE_OK=false
        HEALTH_PASS=false
    fi
done

if [ "$HEALTH_PASS" = true ]; then
    echo " Health Check PASSED — setup is complete and environment is ready."
else
    echo " Health Check FINISHED WITH WARNINGS."
    if [ "$STRUCTURE_OK" = false ]; then
        echo " One or more expected files/folders are missing."
    fi
    if ! command -v python3 &>/dev/null; then
        echo " python3 is not installed. Please install it to run the tracker."
    fi
fi
