## Adding metrics
```
ansible-playbook -f 20 -i hosts.yml playbooks/openshift-metrics/config.yml \
   -e openshift_metrics_install_metrics=True \
   -e openshift_metrics_hawkular_hostname=hawkular-metrics.labcloud.litf4 \
   -e openshift_metrics_cassandra_storage_type=dynamic \
   -e openshift_metrics_cassandra_image="docker.io/openshift/origin-metrics-cassandra:v3.11" \
   -e openshift_metrics_hawkular_metrics_image="docker.io/openshift/origin-metrics-hawkular-metrics:v3.11" \
   -e openshift_metrics_heapster_image="docker.io/openshift/origin-metrics-heapster:v3.11" \
   -e openshift_metrics_schema_installer_image="docker.io/openshift/origin-metrics-schema-installer:v3.11"
```
