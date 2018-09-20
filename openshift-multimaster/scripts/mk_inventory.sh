#!/usr/bin/env bash

function get_value() {
    key="$1"
    openstack stack output show k8smulti $key -f value | tail -1 | tr '\n' ' '
}
function get_value2() {
    key="$1"
    openstack stack output show k8smulti $key -f value | sed 1,2d
}

cat << SSH_PRIV_KEY > k8smulti.key
$( get_value2 private_key )
SSH_PRIV_KEY

cat << INVENTORY
all:
    vars:
        ansible_ssh_user: centos
        ansible_private_key_file: key
        ansible_become: True
        openshift_deployment_type: origin
        domain_name: novalocal
        target_hosts: [ app_nodes, master_nodes, infra_nodes, storage_nodes, ]
        management_hosts: [ management, ]
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
            vars:
                ansible_user: centos
                openshift_hosted_registry_storage_kind: glusterfs
                openshift_deployment_type: origin
                openshift_disable_check: 
                  - docker_image_availability
                  - memory_availability
#                  - disk_availability
#                  - package_availability
#                  - package_version
        dns_servers:
            hosts:
                dns_server: { ansible_host: $( get_value dnsserver_ip1 )}
        loadbalancer_nodes:
            children:
                management:
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
                glusterfs_devices: [ "/dev/vdc", "/dev/vdb", "/dev/vdd" ]

INVENTORY

