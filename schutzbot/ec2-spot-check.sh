#!/bin/bash

# Run this script in the background to shut down the GitLab runner gracefully on
# AWS EC2 spot termination. Does nothing for non-EC2 environments.

if [ -f /sys/class/dmi/id/product_uuid ]; then
	UUID=$(tr '[:upper:]' '[:lower:]' < /sys/class/dmi/id/product_uuid)
	if [[ "$UUID" != ec2* ]]; then
		exit 0
	fi
else
	exit 0
fi

while true; do
	TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
	HTTP_CODE=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s -w "%{http_code}" -o /dev/null http://169.254.169.254/latest/meta-data/spot/instance-action)

	if [ "$HTTP_CODE" -eq 200 ]; then
		MSG="EC2 Spot Interruption detected! Shutting down GitLab Runner gracefully."
		echo "$MSG"
		logger -t spot-monitor "$MSG"
		BODY=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/spot/instance-action)
		echo "$BODY"
		logger -t spot-monitor "$BODY"

		schutzbot/update_github_status.sh spot "$FROM_REF" || true
		gitlab-runner stop
		break
	fi

	sleep 30
done
