# desktop env, JDK17
 export JAVA_HOME=/usr/local/opt/openjdk@17

# argocd 
oc adm groups new cluster-admins
oc adm policy add-cluster-role-to-group cluster-admin cluster-admins
oc adm groups add-users cluster-admins admin
oc label ns hub-ns argocd.argoproj.io/managed-by=openshift-gitops --overwrite

#pipeline
oc policy add-role-to-user admin system:serviceaccount:hub-ns:pipeline -n openshift-gitops

# lift pipeline permission up 
# create a new cluster role 

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

# add pipeline service account of the project where the pipeline runs to this role 

oc adm policy add-cluster-role-to-user namespaces-manager system:serviceaccount:hub-ns:pipeline

oc adm policy add-cluster-role-to-user open-cluster-management:admin:local-cluster system:serviceaccount:hub-ns:pipeline
oc adm policy add-cluster-role-to-user open-cluster-management:cluster-manager-admin system:serviceaccount:hub-ns:pipeline
oc adm policy add-cluster-role-to-user open-cluster-management:managedclusterset:admin:default system:serviceaccount:hub-ns:pipeline
 

# add cluster-reader role
oc adm policy add-cluster-role-to-user cluster-reader system:serviceaccount:hub-ns:pipeline

oc adm policy \
    add-cluster-role-to-user self-provisioner \
    system:serviceaccount:hub-ns:pipeline