#!/usr/bin/env bash

stackname=${1:-test}

function get_value() {
    key="$1"
    openstack stack output show "$stackname" $key -f value | tail -1 | tr '\n' ' '
}
function get_value2() {
    key="$1"
    openstack stack output show "$stackname" $key -f value | sed 1,2d
}

cat << SSH_PRIV_KEY > "${stackname}.key"
$( get_value2 private_key )
SSH_PRIV_KEY

cat << INVENTORY
all:
    vars:
        ansible_ssh_user: centos
        ansible_become: true
        private_domain: 'ocp.local'
        public_domain: 'ocp.litf4'
        ansible_private_key_file: 'key'
    children:
         local: { hosts: { 127.0.0.1: }}
         etcd: { children: { masters: }}
         glusterfs_registry: { children: { glusterfs: }}
         lb: { children: { infra: }}
         OSEv3:
            children:
                masters:
                nodes:
                etcd:
                lb:
                local:
                glusterfs:
                glusterfs_registry:
            vars:
                openshift_master_cluster_method: native
                openshift_master_cluster_hostname: '{{ private_domain }}'
                openshift_master_cluster_public_hostname: '{{ public_domain }}'
                openshift_master_default_subdomain: 'apps.{{ public_domain }}'
                openshift_master_cluter_ip: '$( get_value cluster_private_ip )'
                openshift_master_cluster_public_ip: '$( get_value cluster_public_ip )'
                # openshift_master_portal_net: '$( get_value portal_net_cidr )'
                openshift_deployment_type: origin
                os_sdn_network_plugin_name: 'redhat/openshift-ovs-multitenant'
                openshift_hosted_registry_storage_volume_size: 50Gi
                openshift_storage_glusterfs_registry_storageclass: True
                local_dns: '$( get_value local_dns_ip )'
                external_interface: bond0

                openshift_disable_check:
                  - docker_image_availability
                  - memory_availability
                openshift_storage_glusterfs_namespace: app-storage
                openshift_storage_glusterfs_storageclass_default: false
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

                openshift_storage_glusterfs_registry_namespace: infra-storage
                openshift_storage_glusterfs_registry_block_deploy: true
                openshift_storage_glusterfs_registry_block_storageclass: true
                openshift_storage_glusterfs_registry_block_storageclass_default: false
                openshift_storage_glusterfs_registry_block_host_vol_size: 20
                openshift_master_ldap_ca_file: '/tmp/freeipa-cacert.p12'
                openshift_master_identity_providers:
                  - name: FreeIPA
                    challenge: true
                    login: true
                    kind: LDAPPasswordIdentityProvider
                    attributes:
                        id: ['dn']
                        email: ['mail']
                        name: ['cn']
                        preferredUsername: ['uid']
                    bindDN: 'uid=freeipabind,cn=users,cn=accounts,dc=labcloud,dc=litf4'
                    bindPassword: 'oZP3Z8D+PGjECUQWfc/YN4I9+UA='
                    insecure: false
                    # ca: freeipa-cacert.p12
                    url: 'ldap://freeipa.labcloud.litf4:389/cn=users,cn=accounts,dc=labcloud,dc=litf4?uid?sub?(&(!(memberOf=cn=disabledusers,cn=groups,cn=accounts,dc=labcloud,dc=litf4))(|(memberOf=cn=openshiftusers,cn=groups,cn=accounts,dc=labcloud,dc=litf4)(memberOf=cn=openshiftadmins,cn=groups,cn=accounts,dc=labcloud,dc=litf4)))'

         masters:
             hosts:
                master1: { ansible_host: $( get_value master1_ip1 ), openshift_ip: $( get_value master1_ip2 ), openshift_hostname: 'master1.{{ private_domain }}' }
                master2: { ansible_host: $( get_value master2_ip1 ), openshift_ip: $( get_value master2_ip2 ), openshift_hostname: 'master2.{{ private_domain }}' }
                master3: { ansible_host: $( get_value master3_ip1 ), openshift_ip: $( get_value master3_ip2 ), openshift_hostname: 'master3.{{ private_domain }}' }
             vars:
                 containerized: true
                 openshift_schedulable: false
                 openshift_node_group_name: 'node-config-master'
         infra:
             hosts:
                infra1: { ansible_host: $( get_value infra1_ip1 ), openshift_public_ip: $( get_value infra1_ip1 ), openshift_ip: $( get_value infra1_ip2 ), openshift_hostname: 'infra1.{{ private_domain }}' }
                infra2: { ansible_host: $( get_value infra2_ip1 ), openshift_public_ip: $( get_value infra2_ip1 ), openshift_ip: $( get_value infra2_ip2 ), openshift_hostname: 'infra2.{{ private_domain }}' }
                infra3: { ansible_host: $( get_value infra3_ip1 ), openshift_public_ip: $( get_value infra3_ip1 ), openshift_ip: $( get_value infra3_ip2 ), openshift_hostname: 'infra3.{{ private_domain }}' }
             vars:
                 containerized: true
                 openshift_schedulable: true
                 openshift_node_group_name: 'node-config-infra'
         app:
             hosts:
                app1: { ansible_host: $( get_value app1_ip1 ), openshift_ip: $( get_value app1_ip2 ), openshift_hostname: 'app1.{{ private_domain }}' }
                app2: { ansible_host: $( get_value app2_ip1 ), openshift_ip: $( get_value app2_ip2 ), openshift_hostname: 'app2.{{ private_domain }}' }
                app3: { ansible_host: $( get_value app3_ip1 ), openshift_ip: $( get_value app3_ip2 ), openshift_hostname: 'app3.{{ private_domain }}' }
             vars:
                 containerized: true
                 openshift_schedulable: true
                 openshift_node_group_name: 'node-config-compute'
         glusterfs:
             children: { app: }
             hosts:
                storage1: { ansible_host: $( get_value storage1_ip1 ), glusterfs_ip: $( get_value storage1_ip2 ), openshift_hostname: 'storage1.{{ private_domain }}' }
                storage2: { ansible_host: $( get_value storage2_ip1 ), glusterfs_ip: $( get_value storage2_ip2 ), openshift_hostname: 'storage2.{{ private_domain }}' }
                storage3: { ansible_host: $( get_value storage3_ip1 ), glusterfs_ip: $( get_value storage3_ip2 ), openshift_hostname: 'storage3.{{ private_domain }}' }
             vars:
                 containerized: true
                 openshift_schedulable: true
                 openshift_node_group_name: 'node-config-infra'
                 glusterfs_devices: [ "/dev/vdc", "/dev/vde", "/dev/vdd" ]
         nodes:
             children:
                 masters:
                 infra:
                 app:
                 glusterfs:
         bastion:
            hosts:
                bastion: { ansible_host: $( get_value bastion_ip1 ), openshift_ip: $( get_value bastion_ip2 )}

INVENTORY

echo "# Find the private key in ${stackname}.key"

