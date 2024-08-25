# desktop env, JDK17
export JAVA_HOME=/usr/local/opt/openjdk@17
export TESTCONTAINERS_RYUK_DISABLED=true

# argocd 
oc new-project hub-ns
oc adm groups new cluster-admins
oc adm policy add-cluster-role-to-group cluster-admin cluster-admins
oc adm groups add-users cluster-admins admin
oc label ns hub-ns argocd.argoproj.io/managed-by=openshift-gitops --overwrite

# same for azure-native
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

# Start: We usually use web console for this 
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
# End: We usually use web console for this 

# creaet SA account

oc create sa rhsi -n hub-ns
oc adm policy add-cluster-role-to-user cluster-admin system:serviceaccount:hub-ns:rhsi


# create pipelines 
oc create -f gitops/pipelines/tasks/provision-callback.yaml
oc create -f gitops/pipelines/tasks/deployment-callback.yaml

oc create -f gitops/pipelines/provisioning-pipeline.yaml \
          -f gitops/pipelines/provisioning-pipeline-template.yaml \
          -f gitops/pipelines/provisioning-pipeline-triggerbinding.yaml \
          -f gitops/pipelines/provisioning-pipeline-eventlistener.yaml 

oc create -f gitops/pipelines/application-pipeline.yaml \
          -f gitops/pipelines/application-pipeline-template.yaml \
          -f gitops/pipelines/application-pipeline-triggerbinding.yaml \
          -f gitops/pipelines/application-pipeline-eventlistener.yaml 

oc create -f gitops/pipelines/azure-native-pipeline.yaml

# once pipelines created, we need to expose the evernt listener svc
oc expose svc el-application-event-listener
oc expose svc el-provisioning-event-listener
oc expose svc el-azure-event-listener

oc get route | grep el-
# update the dashboard-config configmap with route values 
# el-application-event-listener-hub-ns.apps.cluster-sql9s.sql9s.[Base DNS Domain]
# el-azure-event-listener-hub-ns.apps.cluster-sql9s.sql9s.[Base DNS Domain]
# el-provisioning-event-listener-hub-ns.apps.cluster-sql9s.sql9s.[Base DNS Domain]

# you need to create env secrets
# you can use base64 online site https://emn178.github.io/online-tools/base64_encode.html
# - update cluster-secrets-list.yaml
# - update cluser-secrets.yaml with the three entries (base64 encoded values)
oc create -f cluster-secrets.yaml -n hub-ns


# you need to create all placement rule including 
# placement/apps-placement.yaml
# placement/location-placement.yaml

oc create -f apps-placement.yaml
oc create -f location-placement.yaml

# create azuer native on DC cluster 
# namespace per department 
oc create pss-azure