# ==================================
# External Services — Database EC2
# ==================================
# These services allow K8s pods to reference "leads-postgres" and
# "leads-elasticsearch" as hostnames.
# They use Endpoints to manually route to the private DB EC2 IP.

apiVersion: v1
kind: Service
metadata:
  name: leads-postgres
  namespace: default
spec:
  ports:
    - port: 5432
      targetPort: 5432
---
apiVersion: v1
kind: Endpoints
metadata:
  name: leads-postgres
  namespace: default
subsets:
  - addresses:
      - ip: ${db_private_ip}
    ports:
      - port: 5432
---
apiVersion: v1
kind: Service
metadata:
  name: leads-elasticsearch
  namespace: default
spec:
  ports:
    - port: 9200
      targetPort: 9200
---
apiVersion: v1
kind: Endpoints
metadata:
  name: leads-elasticsearch
  namespace: default
subsets:
  - addresses:
      - ip: ${db_private_ip}
    ports:
      - port: 9200
