#!/bin/bash

printf "%-30s %-30s %-5s %-5s %-5s %-5s %-5s %-5s %-5s %-5s %s\n" "instance" "ip address" "CM" "CEM" "NIFI" "NREG" "SREG" "SMM" "HUE" "CDSW" "Model Status"
terraform show -json | jq -r '.values.root_module.resources[] | select(.type == "aws_instance") | "\(.address)[\(.index)] \(.values.public_ip)"' | while read instance ip; do
  CDSW_API="http://cdsw.$ip.nip.io/api/v1"
  CDSW_ALTUS_API="http://cdsw.$ip.nip.io/api/altus-ds-1"
  (curl -L http://$ip:7180/cmf/login 2>/dev/null | grep "<title>Cloudera Manager</title>" > /dev/null 2>&1 && echo Ok) > .cm &
  (curl -L http://$ip:10080/efm/ui/ 2>/dev/null | grep "<title>CEM</title>" > /dev/null 2>&1 && echo Ok) > .cem &
  (curl -L http://$ip:8080/nifi/ 2>/dev/null | grep "<title>NiFi</title>" > /dev/null 2>&1 && echo Ok) > .nifi &
  (curl -L http://$ip:18080/nifi-registry/ 2>/dev/null | grep "<title>NiFi Registry</title>" > /dev/null 2>&1 && echo Ok) > .nifireg &
  (curl -L http://$ip:7788/ 2>/dev/null | grep "<title>Schema Registry</title>" > /dev/null 2>&1 && echo Ok) > .schreg &
  (curl -L http://$ip:9991/ 2>/dev/null | grep "<title>STREAMS MESSAGING MANAGER</title>" > /dev/null 2>&1 && echo Ok) > .smm &
  (curl -L http://$ip:8888/ 2>/dev/null | grep "<title>Hue" > /dev/null 2>&1 && echo Ok) > .hue &
  (curl -L http://cdsw.$ip.nip.io/ 2>/dev/null | grep "<title.*Cloudera Data Science Workbench" > /dev/null 2>&1 && echo Ok) > .cdsw &
  (token=$(curl -X POST --cookie-jar .cj --cookie .cj -H "Content-Type: application/json" --data '{"_local":false,"login":"admin","password":"supersecret1"}' "$CDSW_API/authenticate" 2>/dev/null | jq -r '.auth_token') && \
   curl -X POST --cookie-jar .cj --cookie .cj -H "Content-Type: application/json" -H "Authorization: Bearer $token" --data '{"projectOwnerName":"admin","latestModelDeployment":true,"latestModelBuild":true}' "$CDSW_ALTUS_API/models/list-models" 2>/dev/null | jq -r '.[].latestModelDeployment | select(.model.name == "IoT Prediction Model").status' 2>/dev/null) > .model &
  wait
  printf "%-30s %-30s %-5s %-5s %-5s %-5s %-5s %-5s %-5s %-5s %s\n" "$instance" "$ip" "$(cat .cm)" "$(cat .cem)" "$(cat .nifi)" "$(cat .nifireg)" "$(cat .schreg)" "$(cat .smm)" "$(cat .hue)" "$(cat .cdsw)" "$(cat .model)"
done | sort -t\[ -k2n
