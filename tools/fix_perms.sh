if [ -z "$1" ]; then
    echo "ERROR: Provide a path" >&2
    exit 1
fi

sudo chown -R $(whoami) $1
sudo chmod -R 777 $1
