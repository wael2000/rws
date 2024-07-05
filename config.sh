# desktop env, JDK17
export JAVA_HOME=/usr/local/opt/openjdk@17
export TESTCONTAINERS_RYUK_DISABLED=true

# argocd 
oc adm groups new cluster-admins
oc adm policy add-cluster-role-to-group cluster-admin cluster-admins
oc adm groups add-users cluster-admins admin
oc label ns hub-ns argocd.argoproj.io/managed-by=openshift-gitops --overwrite

#pipeline
oc policy add-role-to-user admin system:serviceaccount:hub-ns:pipeline -n openshift-gitops

# lift pipeline permission up 
# create a new cluster role 

cat <<EOF | oc apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: namespaces-manager
rules:
- apiGroups: [""]
  resources: ["namespaces"]
  verbs: ["get", "watch", "list", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["managedclusters"]
  verbs: ["get", "watch", "list", "create", "update", "patch", "delete"]
EOF

# assign namespaces-manager rol to  pipeline service account 
oc adm policy add-cluster-role-to-user namespaces-manager system:serviceaccount:hub-ns:pipeline
# grant pipeline service account access to manage clusters and cluster-sets
oc adm policy add-cluster-role-to-user open-cluster-management:admin:local-cluster system:serviceaccount:hub-ns:pipeline
oc adm policy add-cluster-role-to-user open-cluster-management:cluster-manager-admin system:serviceaccount:hub-ns:pipeline
oc adm policy add-cluster-role-to-user open-cluster-management:managedclusterset:admin:default system:serviceaccount:hub-ns:pipeline
 
# add cluster-reader role
oc adm policy add-cluster-role-to-user cluster-reader system:serviceaccount:hub-ns:pipeline
# add self-provisioner role
oc adm policy \
    add-cluster-role-to-user self-provisioner \
    system:serviceaccount:hub-ns:pipeline

# install operators
# Gitops
oc create ns openshift-gitops-operator
oc label namespace openshift-gitops-operator openshift.io/cluster-monitoring=true

cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: openshift-gitops-operator
  namespace: openshift-gitops-operator
spec:
  upgradeStrategy: Default
EOF

cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: openshift-gitops-operator
  namespace: openshift-gitops-operator
spec:
  channel: latest 
  installPlanApproval: Automatic
  name: openshift-gitops-operator 
  source: redhat-operators 
  sourceNamespace: openshift-marketplace 
EOF


