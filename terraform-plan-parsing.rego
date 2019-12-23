package terraform.parsing

import input as tfplan

# Top level allow statement

default allow = false
allow {
    not has_default_service_account
    kube_daemonset_rule
    not found_open_ports
}

# Check network security rules

default found_open_ports = false
rules := created_objects["azurerm_network_security_rule"]

found_open_ports {
    some i
    inbound_rule(rules[i])
    # All ports
    rules[i].destination_port_range = "*"
}
found_open_ports {
    some i
    inbound_rule(rules[i])
    # SSH Port
    contains(rules[i].destination_port_range, "22")
}
found_open_ports {
    some i
    inbound_rule(rules[i])
    # RDP Port
    contains(rules[i].destination_port_range, "25")
}

inbound_rule(rule) = check {
    rule.direction = "Inbound"
    rule.access = "Allow"
    rule.source_address_prefix = "Internet"
    check := "true"
} else = check {
    check := "false"
}


# check AKS kured daemonset
default kube_daemonset_rule = false

kube_daemonset_rule {
    count(created_objects["azurerm_kubernetes_cluster"]) = 0
}

kube_daemonset_rule {
    count(created_objects["azurerm_kubernetes_cluster"]) > 0
    count(created_objects["kubernetes_daemonset"]) > 0
    daemonset_list := [res |  res:= created_objects["kubernetes_daemonset"][_]; res; res.spec[_].template[_].spec[_].container[_].image == "docker.io/weaveworks/kured:1.2.0"]
    count(daemonset_list) = count(created_objects["azurerm_kubernetes_cluster"])
}

# Check Kubernetes workloads 
default has_default_service_account = false
sa_key := "service_account_name"

has_default_service_account {
    workloads := array.concat(created_objects["kubernetes_deployment"], created_objects["kubernetes_daemonset"])
    spec := workloads[_].spec[_].template[_].spec[_]
    val(key_func(spec,sa_key), spec,sa_key) == "default"
}

val("has_key", spec, key) = ret {
    ret := spec[key]
}

val("no_key", spec, key) = ret {
    ret := "default"
}

key_func(spec, key) = message {
  message := "has_key"
  has_key(spec, key)
} else = default_out {
  default_out := "no_key"
}

has_key(x, k) { x[k] }

# list of all resources of a given type=
addresses := [ address | address := tfplan.resource_changes[_].address ]

# all created resources
create_action := "create"
created_objects := {resource.type: spec |
    some i
    tfplan.resource_changes[i].change.actions[_] == create_action
    resource := tfplan.resource_changes[i]
    spec := [ after_spec |
        after_spec := tfplan.resource_changes[i].change.after
    ]
}