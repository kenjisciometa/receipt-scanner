#!/bin/bash
#
# ADB Port Forwarding for LLM Server
#
# This script forwards the llama-server port from PC to Android device
# via USB connection. This allows the Flutter app to access the local
# LLM server without WiFi.
#
# Usage:
#   ./adb-port-forward.sh        # Setup port forwarding
#   ./adb-port-forward.sh stop   # Remove port forwarding
#   ./adb-port-forward.sh status # Check status

PORT=8080

case "${1:-start}" in
    start)
        echo "Setting up ADB port forwarding..."
        echo "  PC localhost:$PORT -> Android localhost:$PORT"
        echo ""

        # Check if ADB is available
        if ! command -v adb &> /dev/null; then
            echo "Error: adb command not found"
            echo "Please install Android SDK Platform Tools"
            exit 1
        fi

        # Check if device is connected
        DEVICES=$(adb devices | grep -v "List of devices" | grep -v "^$" | wc -l)
        if [ "$DEVICES" -eq 0 ]; then
            echo "Error: No Android device connected"
            echo "Please connect your device via USB and enable USB debugging"
            exit 1
        fi

        # Setup reverse port forwarding
        # This makes the Android's localhost:8080 forward to PC's localhost:8080
        adb reverse tcp:$PORT tcp:$PORT

        if [ $? -eq 0 ]; then
            echo "Port forwarding established successfully!"
            echo ""
            echo "Android app can now access llama-server at:"
            echo "  http://localhost:$PORT"
            echo ""
            echo "Make sure llama-server is running on the PC:"
            echo "  /path/to/llama-server -m model.gguf --mmproj mmproj.gguf -ngl 99 --port $PORT"
        else
            echo "Failed to setup port forwarding"
            exit 1
        fi
        ;;

    stop)
        echo "Removing ADB port forwarding..."
        adb reverse --remove tcp:$PORT
        echo "Port forwarding removed"
        ;;

    status)
        echo "Current ADB reverse port forwards:"
        adb reverse --list
        ;;

    *)
        echo "Usage: $0 {start|stop|status}"
        exit 1
        ;;
esac
