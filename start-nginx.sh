if [[ -z "${MODSECURITY_DETECTION_ONLY}" ]] || [[ "${MODSECURITY_DETECTION_ONLY}" == "false" ]]; then
  # DetectionOnly set to false
  sed -i -e 's/SecRuleEngine DetectionOnly/SecRuleEngine On/g' /etc/nginx/modsecurity.d/modsecurity.conf;
elif [[ "${MODSECURITY_DETECTION_ONLY}" == "true" ]]; then
  # DetectionOnly set to true
  # This is the default in modsecurity.conf. Do nothing here
  :
else
  echo "Invalid MODSECURITY_DETECTION_ONLY: ${MODSECURITY_DETECTION_ONLY}. Valid values are: \"true\", \"false\"";
  exit 1;
fi

exec /usr/local/nginx/nginx -g "daemon off;";