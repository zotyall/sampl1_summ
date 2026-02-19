#!/bin/bash

# Ask the user to type the project name
read -p "Enter project name: " INPUT

if [ -z "$INPUT" ]; then
    echo "Error: Project name cannot be empty."
    exit 1
fi

PROJECT_DIR="attendance_tracker_${INPUT}"

# Handle Ctrl+C - archive the folder before quitting
cleanup() {
    echo ""
    echo "Interrupted! Archiving project..."
    if [ -d "$PROJECT_DIR" ]; then
        tar -czf "attendance_tracker_${INPUT}_archive.tar.gz" "$PROJECT_DIR"
        rm -rf "$PROJECT_DIR"
        echo "Archived and removed."
    fi
    exit 1
}

trap cleanup SIGINT

# Stop if the project already exists
if [ -d "$PROJECT_DIR" ]; then
    echo "Error: Project already exists."
    exit 1
fi

# Create the folder structure
mkdir "$PROJECT_DIR"
mkdir "$PROJECT_DIR/Helpers"
mkdir "$PROJECT_DIR/reports"

# Create assets.csv
cat << 'EOF' > "$PROJECT_DIR/Helpers/assets.csv"
Names,Email,Attendance Count
Alice Johnson,alice@example.com,38
Bob Smith,bob@example.com,28
Carol White,carol@example.com,20
David Brown,david@example.com,15
Eve Davis,eve@example.com,10
EOF

# Create config.json with default thresholds
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

# Create the main Python script
cat << 'PYEOF' > "$PROJECT_DIR/attendance_checker.py"
import csv
import json
import os
from datetime import datetime

def run_attendance_check():
    with open('Helpers/config.json', 'r') as f:
        config = json.load(f)

    if os.path.exists('reports/reports.log'):
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        os.rename('reports/reports.log', f'reports/reports_{timestamp}.log.archive')

    with open('Helpers/assets.csv', mode='r') as f, open('reports/reports.log', 'w') as log:
        reader = csv.DictReader(f)
        total_sessions = config['total_sessions']
        log.write(f"--- Attendance Report: {datetime.now()} ---\n")

        for row in reader:
            name = row['Names']
            email = row['Email']
            attended = int(row['Attendance Count'])
            pct = (attended / total_sessions) * 100
            message = ""

            if pct < config['thresholds']['failure']:
                message = f"URGENT: {name}, your attendance is {pct:.1f}%. You will fail."
            elif pct < config['thresholds']['warning']:
                message = f"WARNING: {name}, your attendance is {pct:.1f}%. Please be careful."

            if message:
                if config['run_mode'] == "live":
                    log.write(f"[{datetime.now()}] ALERT TO {email}: {message}\n")
                    print(f"Alert logged for {name}")
                else:
                    print(f"[DRY RUN] Email to {email}: {message}")

if __name__ == "__main__":
    run_attendance_check()
PYEOF

# Create empty reports.log
touch "$PROJECT_DIR/reports/reports.log"

# Show the created structure as a tree
echo ""
echo "Project structure created successfully"
echo ""
if command -v tree > /dev/null 2>&1; then
    tree "$PROJECT_DIR"
else
    echo "Install 'tree' to see folder structure (sudo apt install tree)"
fi

# Ask if user wants to change thresholds
echo ""
read -p "Do you want to change passing score? (y/n): " choice
if [ "$choice" == "y" ]; then
    read -p "Enter new warning threshold (default 75): " new_warning
    read -p "Enter new failure threshold (default 50): " new_failure
    sed -i "s/\"warning\": [0-9]*/\"warning\": $new_warning/" "$PROJECT_DIR/Helpers/config.json"
    sed -i "s/\"failure\": [0-9]*/\"failure\": $new_failure/" "$PROJECT_DIR/Helpers/config.json"
    echo "Thresholds updated."
fi

# Check if Python3 is installed
python3 --version > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "Python detected ✔"
else
    echo "Python not found ⚠"
fi
