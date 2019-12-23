package terraform.parsing

import input as tfplan

# check AKS kured daemonset
default kube_daemonset_rule = false

kube_daemonset_rule {
    count(created_objects["azurerm_kubernetes_cluster"]) = 0
}

kube_daemonset_rule {
    count(created_objects["azurerm_kubernetes_cluster"]) > 0
    count(created_objects["kubernetes_daemonset"]) > 0
    daemonset_list := [res |  res:= created_objects["kubernetes_daemonset"][_]; res; res.spec.template.spec.container[_].image == "docker.io/weaveworks/kured:1.2.0"]
    count(daemonset_list) = count(created_objects["azurerm_kubernetes_cluster"])
}

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

# map created resource to resource address
address_by_type := { resource.type : address | 
    some i
    resource := tfplan.planned_values.root_module.resources[i]
    address := [ resource_address |
        resource_address := tfplan.planned_values.root_module.resources[i].address
    ]
}

# map resource address to full expression with refs
address_to_expressions := { resource.address : resource.expressions |
    resource := tfplan.configuration.root_module.resources[_]
}