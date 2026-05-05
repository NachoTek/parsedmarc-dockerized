#!/bin/bash
# Copyright 2020, Patrik Kernstock.
# Modified 2026 — Grafana dashboard import replaces Kibana.

set -x

echo "## ELASTICSEARCH"
echo "Setting permissions..."
chmod g+rwx -R /usr/share/elasticsearch/data/
chgrp 0 -R /usr/share/elasticsearch/data/

echo "## GRAFANA"
echo "Setting Grafana data permissions..."
if [ -d "/var/lib/grafana" ]; then
	chmod -R 777 /var/lib/grafana
fi

echo "## GRAFANA DASHBOARDS"
dashboardDir="/etc/parsedmarc/grafana_dashboards"
if [ ! -d "${dashboardDir}" ]; then
	mkdir -p "${dashboardDir}"
fi

echo "Downloading Grafana dashboards from GitHub..."

# Dashboard URLs from the parsedmarc project
DASH_URL_1="https://raw.githubusercontent.com/domainaware/parsedmarc/master/dashboards/grafana/Grafana-DMARC_Reports.json"
DASH_URL_2="https://raw.githubusercontent.com/domainaware/parsedmarc/master/dashboards/grafana/Grafana-DMARC_Reports.json-new_panel.json"

for url in $DASH_URL_1 $DASH_URL_2; do
	filename=$(basename "$url")
	target="${dashboardDir}/${filename}"
	tmpfile="${target}.tmp"

	curl -sL "$url" -o "$tmpfile"
	if [ $? -ne 0 ]; then
		echo "Download failed for ${filename}"
		continue
	fi

	# Verify it's a real JSON file (not a 404 page)
	fileSize=$(wc -c "$tmpfile" | awk -F' ' '{ print $1 }')
	if [ "$fileSize" -lt 100 ]; then
		echo "Downloaded file too small (${fileSize} bytes), skipping ${filename}"
		rm -f "$tmpfile"
		continue
	fi

	if [ -f "$target" ]; then
		oldSize=$(wc -c "$target" | awk -F' ' '{ print $1 }')
		if [ "$fileSize" -eq "$oldSize" ]; then
			echo "File size unchanged for ${filename}. Skipping."
			rm -f "$tmpfile"
			continue
		fi
	fi

	echo "Updating ${filename} (${fileSize} bytes)..."
	mv "$tmpfile" "$target"
done

echo "Dashboard check complete."

sleep 3

# Create empty file to let other containers know that we're ready.
touch /ready
sleep infinity

exit 0
