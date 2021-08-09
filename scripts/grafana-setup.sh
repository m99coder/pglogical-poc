#!/usr/bin/env bash

# set grafana host
GRAFANA_HOST=${1:-http://localhost:3000}
echo "GRAFANA_HOST: $GRAFANA_HOST"

# API KEY ---
create_api_key () {
    # create API key
  GRAFANA_API_KEY_RESPONSE=$(
    curl -s -X POST http://admin:admin@localhost:3000/api/auth/keys \
      -H "Content-Type: application/json" \
      -d '{"name":"apiKeyCurl", "role": "Admin"}')

  # extract and export it
  GRAFANA_API_KEY=$(echo $GRAFANA_API_KEY_RESPONSE | jq -r '.key')
  echo "GRAFANA_API_KEY: $GRAFANA_API_KEY"
}

# DATA SOURCE ---
GRAFANA_PROMETHEUS_DATA_SOURCE_NAME="prometheus"

create_data_source () {
  # create data source
  curl -s -X POST $GRAFANA_HOST/api/datasources \
    -H "Accept: application/json" \
    -H "Content-type: application/json" \
    -H "Authorization: Bearer $GRAFANA_API_KEY" \
    -d '{
        "name": "'$GRAFANA_PROMETHEUS_DATA_SOURCE_NAME'",
        "type": "prometheus",
        "url": "http://prometheus:9090",
        "access": "proxy",
        "basicAuth": false
      }' | jq

  # get data source by name
  curl -s -X GET $GRAFANA_HOST/api/datasources/name/$GRAFANA_PROMETHEUS_DATA_SOURCE_NAME \
    -H "Accept: application/json" \
    -H "Content-type: application/json" \
    -H "Authorization: Bearer $GRAFANA_API_KEY" | jq
}

delete_data_source () {
  # delete data source by name
  curl -s -X DELETE $GRAFANA_HOST/api/datasources/name/$GRAFANA_PROMETHEUS_DATA_SOURCE_NAME \
    -H "Accept: application/json" \
    -H "Content-type: application/json" \
    -H "Authorization: Bearer $GRAFANA_API_KEY" | jq
}

# DASHBOARD ---
GRAFANA_PROMETHEUS_DASHBOARD_ID=""
GRAFANA_PROMETHEUS_DASHBOARD_UID=""

GRAFANA_POSTGRES_DASHBOARD_ID=""
GRAFANA_POSTGRES_DASHBOARD_UID=""

create_dashboard () {
  # create built-in “Prometheus 2.0 Stats” dashboard
  GRAFANA_PROMETHEUS_DASHBOARD_RESPONSE=$(curl -s -X POST $GRAFANA_HOST/api/dashboards/import \
    -H "Accept: application/json" \
    -H "Content-type: application/json" \
    -H "Authorization: Bearer $GRAFANA_API_KEY" \
    -d '{
      "pluginId": "prometheus",
      "path": "dashboards/prometheus_2_stats.json",
      "overwrite": false,
      "inputs": [
        {
          "name": "*",
          "type": "datasource",
          "pluginId": "prometheus",
          "value": "prometheus"
        }
      ]
    }')
  echo $GRAFANA_PROMETHEUS_DASHBOARD_RESPONSE | jq

  # get dashboard by ID
  GRAFANA_PROMETHEUS_DASHBOARD_ID=$(echo $GRAFANA_PROMETHEUS_DASHBOARD_RESPONSE | jq -r '.dashboardId')
  echo "GRAFANA_PROMETHEUS_DASHBOARD_ID: $GRAFANA_PROMETHEUS_DASHBOARD_ID"

  # search for dashboard by ID to retrieve UID
  GRAFANA_PROMETHEUS_DASHBOARD_UID=$(curl -s -X GET $GRAFANA_HOST/api/search\?dashboardIds[]=$GRAFANA_CREATE_DASHBOARD_ID \
    -H "Accept: application/json" \
    -H "Content-type: application/json" \
    -H "Authorization: Bearer $GRAFANA_API_KEY" | jq -r '.[0].uid')
  echo "GRAFANA_PROMETHEUS_DASHBOARD_UID: $GRAFANA_PROMETHEUS_DASHBOARD_UID"
}

delete_dashboards () {
  curl -s -X DELETE $GRAFANA_HOST/api/dashboards/uid/$GRAFANA_PROMETHEUS_DASHBOARD_UID \
    -H "Accept: application/json" \
    -H "Content-type: application/json" \
    -H "Authorization: Bearer $GRAFANA_API_KEY" | jq

  curl -s -X DELETE $GRAFANA_HOST/api/dashboards/uid/$GRAFANA_POSTGRES_DASHBOARD_UID \
    -H "Accept: application/json" \
    -H "Content-type: application/json" \
    -H "Authorization: Bearer $GRAFANA_API_KEY" | jq
}

import_dashboard () {
  # retrieve dashboard
  # https://grafana.com/grafana/dashboards/9628
  JSON=$(curl -s -k -X GET $GRAFANA_HOST/api/gnet/dashboards/9628 \
    -H "Accept: application/json" \
    -H "Content-type: application/json" \
    -H "Authorization: Bearer $GRAFANA_API_KEY" | jq .json)

  # reset `__inputs`
  JSON_MODIFIED=$(echo '{
      "dashboard": '$JSON',
      "overwrite": true,
      "inputs": [
        {
          "name": "'$GRAFANA_PROMETHEUS_DATA_SOURCE_NAME'",
          "type": "datasource",
          "pluginId": "'$GRAFANA_PROMETHEUS_DATA_SOURCE_NAME'",
          "value": "'$GRAFANA_PROMETHEUS_DATA_SOURCE_NAME'"
        }
      ]
    }' | jq '.dashboard.__inputs = []')

  # import it with added data source
  GRAFANA_POSTGRES_DASHBOARD_RESPONSE=$(curl -s -X POST $GRAFANA_HOST/api/dashboards/import \
    -H "Accept: application/json" \
    -H "Content-type: application/json" \
    -H "Authorization: Bearer $GRAFANA_API_KEY" \
    -d "$JSON_MODIFIED")
  echo $GRAFANA_POSTGRES_DASHBOARD_RESPONSE | jq

  # get dashboard by ID
  GRAFANA_POSTGRES_DASHBOARD_ID=$(echo $GRAFANA_POSTGRES_DASHBOARD_RESPONSE | jq -r '.dashboardId')
  echo "GRAFANA_POSTGRES_DASHBOARD_ID: $GRAFANA_POSTGRES_DASHBOARD_ID"

  # search for dashboard by ID to retrieve UID
  GRAFANA_POSTGRES_DASHBOARD_UID=$(curl -s -X GET $GRAFANA_HOST/api/search\?dashboardIds[]=$GRAFANA_POSTGRES_DASHBOARD_ID \
    -H "Accept: application/json" \
    -H "Content-type: application/json" \
    -H "Authorization: Bearer $GRAFANA_API_KEY" | jq -r '.[0].uid')
  echo "GRAFANA_POSTGRES_DASHBOARD_UID: $GRAFANA_POSTGRES_DASHBOARD_UID"
}

# INIT ---
create_api_key
create_data_source
create_dashboard
import_dashboard

# CLEANUP ---
#delete_dashboards
#delete_data_source
