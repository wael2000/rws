# dora

# Before proceeding with the cluster provisioning we need to create following configmaps in openshift-gitops ns

# create the same from RHACM UI


acm-placement

kind: ConfigMap
apiVersion: v1
metadata:
  name: acm-placement
data:
  apiVersion: cluster.open-cluster-management.io/v1beta1
  kind: placementdecisions
  matchKey: clusterName
  statusListKey: decisions


acm-placementrule

kind: ConfigMap
apiVersion: v1
metadata:
  name: acm-placementrule
data:
  apiVersion: apps.open-cluster-management.io/v1
  kind: placementrules
  matchKey: clusterName
  statusListKey: decisions
