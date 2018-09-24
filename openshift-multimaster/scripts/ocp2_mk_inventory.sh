#!/usr/bin/env bash

stackname=test

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
        ansible_private_key_file: "key"
        ansible_become: True
        openshift_deployment_type: origin
        domain_name: novalocal
        loadbalancer_fqdn: console.okd.local
    children:
        masters: { children: { master_nodes: }}
        etcd: { children: { master_nodes: }}
        glusterfs: { children: { storage_nodes: }}
        glusterfs_registry: { children: { storage_nodes: }}
        OSEv3:
            children:
                master_nodes:
                app_nodes:
                etcd:
                glusterfs:
                glusterfs_registry:
            vars:
                openshift_master_identity_providers:
                  - name: htpasswd_auth
                    login: true
                    challenge: true
                    kind: HTPasswdPasswordIdentityProvider
                    filename: '/etc/origin/htpasswd'
                openshift_master_cluster_hostname: "{{ loadbalancer_fqdn }}"
                openshift_master_cluster_public_hostname: "{{ loadbalancer_fqdn }}"
                ansible_user: centos
                openshift_deployment_type: origin
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
                openshift_master_ldap_ca_file: freeipa-cacert.p12
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


        dns_servers:
            hosts:
                 dns_server: { ansible_host: $( get_value dnsserver_ip1 )}
            vars:
                lbfqdn_ip: $( get_value cluster_vip_ip1 )
        loadbalancer_nodes:
            children:
                masters:
        management:
            hosts:
                buildhost: { ansible_host: $( get_value buildhost_ip1 )}
        lb:
            children:
                loadbalancer_nodes:
        app_nodes:
            hosts:
                node1: { ansible_host: $( get_value appnode1_ip1 )}
                node2: { ansible_host: $( get_value appnode2_ip1 )}
                node3: { ansible_host: $( get_value appnode3_ip1 )}
            vars:
                openshift_node_group_name: "node-config-compute"
            children:
                storage_nodes:
        master_nodes:
            hosts:
                master1: { ansible_host: $( get_value master1_ip1 )}
                master2: { ansible_host: $( get_value master2_ip1 )}
                master3: { ansible_host: $( get_value master3_ip1 )}
            vars:
                openshift_node_group_name: "node-config-master"
                openshift_schedulable: True
        infra_nodes:
            hosts:
                infra1: { ansible_host: $( get_value infra1_ip1 )}
                infra2: { ansible_host: $( get_value infra2_ip1 )}
                infra3: { ansible_host: $( get_value infra3_ip1 )}
            vars:
                openshift_node_group_name: "node-config-infra"
        nodes:
            children:
                app_nodes:
                infra_nodes:
                master_nodes:
        storage_nodes:
            hosts:
                storage1: { ansible_host: $( get_value storagenode1_ip1 )}
                storage2: { ansible_host: $( get_value storagenode2_ip1 )}
                storage3: { ansible_host: $( get_value storagenode3_ip1 )}
            vars:
                glusterfs_devices: [ "/dev/vdc", "/dev/vde", "/dev/vdd" ]
                openshift_node_group_name: "node-config-infra"

INVENTORY

echo "# Find the private key in ${stackname}.key"

