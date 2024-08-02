# deploy dashboard app
oc create -f dashboard-applicationset.yaml -n openshift-gitops

oc delete  -f dashboard-applicationset.yaml -n openshift-gitops
