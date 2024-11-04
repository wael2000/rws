# gitops filder

# create placement objects if not created
oc create -f gitops/placements/apps-placement.yaml
oc create -f gitops/placements/location-placement.yaml


# create hub-apis sa and generate token with cluster-admin role
oc create sa hub-apis
# create token valid for 10days
oc create token hub-apis --duration 14400m
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
  token: HUB-API-SA-TOKEN Base64 encoded
type: Opaque
EOF

# once secret is created, the ndeploy the dashboard app
# deploy dashboard app
oc create -f gitops/dashboard-applicationset.yaml -n openshift-gitops


# delete 
#oc delete  -f dashboard-applicationset.yaml -n openshift-gitops
