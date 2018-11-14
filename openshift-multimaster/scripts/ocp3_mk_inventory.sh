#!/usr/bin/env bash

stackname=${1:-ocp3}

function get_value() {
    key="$1"
    openstack stack output show "$stackname" $key -f value | tail -1 | tr '\n' ' '
}
function get_value2() {
    key="$1"
    openstack stack output show "$stackname" $key -f value | sed 1,2d
}
function get_app_vips() {
    tofile="floating_vips.txt"
    cat /dev/null > $tofile
    for h in {1..10}; do
        get_value app_floating_vip_${h} >> $tofile
        echo >> $tofile
    done
    echo $tofile
}
cat << SSH_PRIV_KEY > "${stackname}.key"
$( get_value2 private_key )
SSH_PRIV_KEY

cat << INVENTORY | tee inventory.${stackname}
all:
    vars:
        ansible_ssh_user: centos
        ansible_become: true
        private_domain: 'ocp.local'
        public_domain: 'labcloud.litf4'
        ansible_private_key_file: 'key'
        api_subnet_cidr: $( get_value api_subnet_cidr )
        storage_subnet_cidr: $( get_value storage_subnet_cidr )
    children:
         # local: { hosts: { 127.0.0.1: }}
         etcd: { children: { masters: }}
         glusterfs_registry: { children: { glusterfs: }}
         dns_servers: { children: { management: }}
         lb: { children: { masters: }}
         OSEv3:
            children:
                masters:
                nodes:
                etcd:
                lb:
                # local:
                glusterfs:
                glusterfs_registry:
            vars:
                ## openshift_logging_es_pvc_storage_class_name: glusterfs-storage-block
                openshift_metrics_cassandra_pvc_storage_class_name: glusterfs-storage-block
                ## openshift_logging_install_logging: true
                ## openshift_logging_es_pvc_dynamic: true
                openshift_master_cluster_method: native
                openshift_master_cluster_hostname: 'ocp.{{ private_domain }}'
                openshift_master_cluster_public_hostname: 'ocp.{{ public_domain }}'
                openshift_master_default_subdomain: 'apps.{{ public_domain }}'
                openshift_master_cluster_ip: $( get_value master_cluster_private_vip )
                openshift_master_cluster_public_ip: $( get_value master_cluster_public_vip )
                openshift_deployment_type: origin
                os_sdn_network_plugin_name: 'redhat/openshift-ovs-multitenant'
                openshift_hosted_registry_storage_volume_size: 15Gi
                openshift_storage_glusterfs_registry_storageclass: True
                etcd_ca_default_days: 3650
                openshift_node_cert_expire_days: 3650
                openshift_master_cert_expire_days: 3650
                openshift_hosted_registry_cert_expire_days: 3650
                
                ## openshift_master_api_port: 443
                ## https://docs.openshift.com/container-platform/3.10/install/configuring_inventory_file.html#advanced-install-cluster-metrics
                ## openshift_metrics_install_metrics: true
                ### --- Added monitoring
                ## openshift_monitoring_deploy: true
                ## openshift_logging_install_logging: true
                ## openshift_logging_es_pvc_dynamic: true
                # Cluster metrics https://docs.openshift.com/container-platform/3.9/install_config/cluster_metrics.html
                # 10G is a default value
                ## openshift_metrics_cassandra_pvc_size: 10G
                ## openshift_metrics_cassandra_storage_type: dynamic
                ## openshift_metrics_cassandra_pvc_storage_class_name: gluster-storage
                ## openshift_metrics_start_cluster: true
                openshift_metrics_hawkular_hostname: 'hawkular-metrics.{{ public_domain }}'
                ### --- addons end
                local_dns: $( get_value local_dns_ip )

                openshift_disable_check:
                  - docker_image_availability
                  - memory_availability
                openshift_storage_glusterfs_namespace: gluster-storage
                openshift_storage_glusterfs_storageclass_default: true
                openshift_storage_glusterfs_block_deploy: true
                openshift_storage_glusterfs_block_host_vol_size: 100
                openshift_storage_glusterfs_block_storageclass: true
                openshift_storage_glusterfs_block_storageclass_default: false
                openshift_storage_glusterfs_is_native: false
                openshift_storage_glusterfs_heketi_is_native: true
                openshift_storage_glusterfs_heketi_executor: ssh
                openshift_storage_glusterfs_heketi_ssh_port: 22
                openshift_storage_glusterfs_heketi_ssh_user: centos
                openshift_storage_glusterfs_heketi_ssh_sudo: true
                openshift_storage_glusterfs_heketi_ssh_keyfile: "/root/deploy/openshift-ansible/key"
                openshift_hosted_registry_storage_kind: glusterfs
                openshift_hosted_registry_selector: 'node-role.kubernetes.io/infra=true'

                openshift_storage_glusterfs_registry_namespace: registry-infra
                openshift_storage_glusterfs_registry_block_deploy: true
                openshift_storage_glusterfs_registry_block_storageclass: true
                openshift_storage_glusterfs_registry_block_storageclass_default: false
                openshift_storage_glusterfs_registry_block_host_vol_size: 20
                openshift_master_ldap_ca_file: '/tmp/freeipa-cacert.p12'    
                openshift_master_htpasswd_file: /etc/openshift/openshift-passwd
                openshift_master_htpasswd_users:
                    dmitrii: "$apr1$Md/Up5SK$v9NUx3RoFZnwLSPb9ghEa0"
                    user: "$apr1$67ev4A5t$ATnReEPlCCpko6FrZW8881"
                    testuser: "$apr1$Eg5yj/Nv$fQyh2FC4gAA8FOSdXER9I/"
                openshift_master_identity_providers:
                    - name: htpasswd_auth
                      login: true
                      challenge: true
                      kind: HTPasswdPasswordIdentityProvider
                      file: /etc/openshift/openshift-passwd 

##                 openshift_master_identity_providers:
##                   - name: FreeIPA
##                     challenge: true
##                     login: true
##                     kind: LDAPPasswordIdentityProvider
##                     attributes:
##                         id: ['dn']
##                         email: ['mail']
##                         name: ['cn']
##                         preferredUsername: ['uid']
##                     bindDN: 'uid=freeipabind,cn=users,cn=accounts,dc=labcloud,dc=litf4'
##                     bindPassword: 'oZP3Z8D+PGjECUQWfc/YN4I9+UA='
##                     insecure: false
##                     # ca: freeipa-cacert.p12
##                     url: 'ldap://freeipa.labcloud.litf4:389/cn=users,cn=accounts,dc=labcloud,dc=litf4?uid?sub?(&(!(memberOf=cn=disabledusers,cn=groups,cn=accounts,dc=labcloud,dc=litf4))(|(memberOf=cn=openshiftusers,cn=groups,cn=accounts,dc=labcloud,dc=litf4)(memberOf=cn=openshiftadmins,cn=groups,cn=accounts,dc=labcloud,dc=litf4)))'

         masters:
             hosts:
                master1:
                    openshift_hostname: 'master1.{{ private_domain }}'
                    ansible_host: $( get_value master1_ip1 )
                    openshift_ip: $( get_value master1_ip2 )
                    glusterfs_ip: $( get_value master1_storage_ip )
                master2:
                    openshift_hostname: 'master2.{{ private_domain }}'
                    ansible_host: $( get_value master2_ip1 )
                    openshift_ip: $( get_value master2_ip2 )
                    glusterfs_ip: $( get_value master2_storage_ip )
                master3:
                    openshift_hostname: 'master3.{{ private_domain }}'
                    ansible_host: $( get_value master3_ip1 )
                    openshift_ip: $( get_value master3_ip2 )
                    glusterfs_ip: $( get_value master3_storage_ip )
             vars:
                 containerized: true
                 openshift_schedulable: true
                 openshift_node_group_name: 'node-config-master-infra'
         infra:
##             hosts:
##                app1: { ansible_host: $( get_value app1_ip1 ), openshift_ip: $( get_value app1_ip2 ), openshift_hostname: 'app1.{{ private_domain }}', glusterfs_ip: $( get_value app1_storage_ip ) }
##                app2: { ansible_host: $( get_value app2_ip1 ), openshift_ip: $( get_value app2_ip2 ), openshift_hostname: 'app2.{{ private_domain }}', glusterfs_ip: $( get_value app2_storage_ip ) }
##             children:
##                app[1-2]:
##             hosts:
##                 infra1:
##                     openshift_hostname: 'app1.{{ private_domain }}'
##                     ansible_host: $( get_value app1_ip1 )
##                     openshift_public_ip: $( get_value app1_ip2 )
##                     openshift_ip: $( get_value app1_ip2 )
##                     glusterfs_ip: $( get_value app1_storage_ip )
##                 infra2:
##                     openshift_hostname: 'app2.{{ private_domain }}'
##                     ansible_host: $( get_value app2_ip1 )
##                     openshift_public_ip: $( get_value app2_ip1 )
##                     openshift_ip: $( get_value app2_ip2 )
##                     glusterfs_ip: $( get_value app2_storage_ip )
##
##             vars:
##                 containerized: true
##                 openshift_schedulable: true
##                 openshift_node_group_name: 'node-config-infra'
##                 public_vips: [ $( get_value app_floating_vip_1 ), $( get_value app_floating_vip_2 )]
         app:
             hosts:
                app1: { ansible_host: $( get_value app1_ip1 ), openshift_ip: $( get_value app1_ip2 ), openshift_hostname: 'app1.{{ private_domain }}', glusterfs_ip: $( get_value app1_storage_ip ) }
                app2: { ansible_host: $( get_value app2_ip1 ), openshift_ip: $( get_value app2_ip2 ), openshift_hostname: 'app2.{{ private_domain }}', glusterfs_ip: $( get_value app2_storage_ip ) }
                app3: { ansible_host: $( get_value app3_ip1 ), openshift_ip: $( get_value app3_ip2 ), openshift_hostname: 'app3.{{ private_domain }}', glusterfs_ip: $( get_value app3_storage_ip ) }
                app4: { ansible_host: $( get_value app4_ip1 ), openshift_ip: $( get_value app4_ip2 ), openshift_hostname: 'app4.{{ private_domain }}', glusterfs_ip: $( get_value app4_storage_ip ) }
                app5: { ansible_host: $( get_value app5_ip1 ), openshift_ip: $( get_value app5_ip2 ), openshift_hostname: 'app5.{{ private_domain }}', glusterfs_ip: $( get_value app5_storage_ip ) }
             vars:
                 containerized: true
                 openshift_schedulable: true
                 openshift_node_group_name: 'node-config-compute'
         glusterfs:
             hosts:
                storage1: { ansible_host: $( get_value storage1_ip1 ), glusterfs_ip: $( get_value storage1_ip3 ), openshift_ip: $( get_value storage1_ip2 ), openshift_hostname: 'storage1.{{ private_domain }}' }
                storage2: { ansible_host: $( get_value storage2_ip1 ), glusterfs_ip: $( get_value storage2_ip3 ), openshift_ip: $( get_value storage2_ip2 ), openshift_hostname: 'storage2.{{ private_domain }}' }
                storage3: { ansible_host: $( get_value storage3_ip1 ), glusterfs_ip: $( get_value storage3_ip3 ), openshift_ip: $( get_value storage3_ip2 ), openshift_hostname: 'storage3.{{ private_domain }}' }
             vars:
                 containerized: true
                 openshift_schedulable: true
                 openshift_node_group_name: 'node-config-master-infra'
                 glusterfs_devices: [ "/dev/vdc", "/dev/vde", "/dev/vdd" ]
         nodes:
             children:
                 masters:
                 # infra:
                 app:
         management:
            hosts:
                bastion:
                    ansible_host: $( get_value bastion_ip1 )
                    openshift_ip: $( get_value bastion_ip2 )
                    openshift_hostname: 'bastion.{{ private_domain }}'

INVENTORY
echo "# Inventory saved as inventory.${stackname}"
echo "# Find the private key in ${stackname}.key"
echo "# Find the Apps floating IPs in $(get_app_vips)"

