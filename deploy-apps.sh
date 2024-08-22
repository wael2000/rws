# gitops filder

# create placement objects
oc create -f placements/apps-placement.yaml
oc create -f placements/location-placement.yaml

# deploy dashboard app
oc create -f dashboard-applicationset.yaml -n openshift-gitops

# create hub-apis sa and generate token with cluster-admin role
oc create sa hub-apis
oc create token hub-apis
# a secret will be created with the token that can be used fot he API calls (hub-apis-token-XXXXX)
oc adm policy add-cluster-role-to-user cluster-admin system:serviceaccount:hub-ns:hub-apis
# curl -k -H "Authorization: Bearer TOOKEN" "https://api.cluster-sql9s.sql9s.[Base DNS Domain]:6443/apis/policy.open-cluster-management.io/v1/namespaces/openshift-gitops/policies/hub-ns"


# create hub-apis-token secret
cat <<EOF | oc apply -f -
kind: Secret
apiVersion: v1
metadata:
  name: hub-apis-token
  namespace: hub-ns
data:
  token: HUB-API-SA-TOKEN
type: Opaque
EOF


# delete 
#oc delete  -f dashboard-applicationset.yaml -n openshift-gitops
