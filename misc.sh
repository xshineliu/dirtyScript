find /var/run/sensorlog/ -name "*.log" -mmin +60 -mmin -1500 | xargs ls -ltr | awk '{print $9, $6, $7, $8}' | sort -n | awk -F\/ 'BEGIN{i=0}; {print i++, $6}'
