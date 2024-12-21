#!/bin/sh

# Detect for VM metadata tag that indicates not to start zk.
for tag in `curl -s http://169.254.169.254/metadata/v1/tags`
do
	if [ "$tag" = 'failback' ]
	then
		echo "Failback tag detected. Performing failback actions."
		/usr/bin/systemctl stop confluent-zookeeper.service
		/usr/bin/systemctl mask confluent-zookeeper.service
		exit
	fi
done
echo "No Failback tag detected."
