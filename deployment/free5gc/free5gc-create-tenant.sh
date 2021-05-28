#!/bin/bash

if [ -z "$1" ]
then
    echo "Please enter mcc!"
    exit
fi

if [ -z "$2" ]
then
    echo "Please enter mnc!"
    exit
fi

if [ -z "$3" ]
then
    echo "Please enter abbreviation of telecom!"
    exit
fi

if [ -z "$4" ]
then
    echo "Please enter nsi id!"
    exit
fi

if [ -z "$5" ]
then
    echo "Please enter amf ip!"
    exit
fi

if [ -z "$6" ]
then
    echo "Please enter core network id!"
    exit
fi

nextip(){
    IP=$1
    IP_HEX=$(printf '%.2X%.2X%.2X%.2X\n' `echo $IP | sed -e 's/\./ /g'`)
    NEXT_IP_HEX=$(printf %.8X `echo $(( 0x$IP_HEX + 1 ))`)
    NEXT_IP=$(printf '%d.%d.%d.%d\n' `echo $NEXT_IP_HEX | sed -r 's/(..)/0x\1 /g'`)
    echo "$NEXT_IP"
}

mcc="$1"
mnc="$2"
abb="$3"
nsi="$4"
amf_ip="$5"
id="$6"
core_network_id="$(printf "%02x\n" $6)"
default_gnb_id="000000010"
gnb_ip=$(nextip $amf_ip)
gnb_n3_ip_b=$(( 200 + id ))

#
# create mongodb
#

mkdir -p $mcc-$mnc/mongodb/base/

cat <<EOF > $mcc-$mnc/mongodb/base/mongodb-configmap.yaml
---
kind: ConfigMap
apiVersion: v1
metadata:
  name: free5gc-mongodb-$mcc-$mnc-config
data:
  mongo_initdb_database: "free5gc"
EOF

cat <<EOF > $mcc-$mnc/mongodb/base/kustomization.yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: free5gc
resources:
 - mongodb-pv.yaml
 - mongodb-pvc.yaml
 - mongodb-configmap.yaml
 - mongodb-service.yaml
 - mongodb-statefulset.yaml
EOF

cat <<EOF > $mcc-$mnc/mongodb/base/mongodb-pv.yaml
---
kind: PersistentVolume
apiVersion: v1
metadata:
  name: mongodb-$mcc-$mnc-pv-volume
  labels:
    type: local
    namespace: free5gc
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    type: DirectoryOrCreate
    path: /mnt/dbdata-$mcc-$mnc
EOF

cat <<EOF > $mcc-$mnc/mongodb/base/mongodb-pvc.yaml
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mongodb-$mcc-$mnc-pv-claim
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF

cat <<EOF > $mcc-$mnc/mongodb/base/mongodb-service.yaml
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: free5gc-mongodb-$mcc-$mnc
  name: free5gc-mongodb-$mcc-$mnc
spec:
  clusterIP: None
  ports:
  - name: free5gc-mongodb
    port: 27017
    targetPort: 27017
    protocol: TCP
  selector:
    app: free5gc-mongodb-$mcc-$mnc
EOF

cat <<EOF > $mcc-$mnc/mongodb/base/mongodb-statefulset.yaml
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: free5gc-mongodb-$mcc-$mnc
spec:
  serviceName: free5gc-mongodb-$mcc-$mnc
  selector:
    matchLabels:
      app: free5gc-mongodb-$mcc-$mnc
  replicas: 1
  template:
    metadata:
      labels:
        app: free5gc-mongodb-$mcc-$mnc
        nsi: "1"
        mcc: "$mcc"
        mnc: "$mnc"
        telecom: $abb
    spec:
      securityContext:
        runAsUser: 0
        runAsGroup: 0
      containers:
      - name: mongodb
        image: mongo:4.2.7
        ports:
        - containerPort: 27017
          name: mongodb
        volumeMounts:
        - name: mongodb-$mcc-$mnc-persistent-storage
          mountPath: /data/db
        env:
          - name: MONGO_INITDB_DATABASE
            valueFrom:
              configMapKeyRef:
                name: free5gc-mongodb-$mcc-$mnc-config
                key: mongo_initdb_database
      volumes:
      - name: mongodb-$mcc-$mnc-persistent-storage
        persistentVolumeClaim:
          claimName: mongodb-$mcc-$mnc-pv-claim
EOF

#
# creata webui
#

mkdir -p $mcc-$mnc/webui/base/config

cat <<EOF > $mcc-$mnc/webui/base/config/webuicfg.yaml
info:
  version: 1.0.0
  description: WebUI initial local configuration

configuration:
  mongodb: # the mongodb connected by this webui
    name: free5gc # name of the mongodb
    url: mongodb://free5gc-mongodb-$mcc-$mnc:27017 # a valid URL of the mongodb
EOF

cat <<EOF > $mcc-$mnc/webui/base/kustomization.yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: free5gc
resources:
  - webui-sa.yaml
  - webui-rbac.yaml
  - webui-service.yaml
  - webui-deployment.yaml

# declare ConfigMap from a ConfigMapGenerator
configMapGenerator:
- name: free5gc-webui-$mcc-$mnc-config
  namespace: free5gc
  files:
    - config/webuicfg.yaml

EOF

cat <<EOF > $mcc-$mnc/webui/base/webui-sa.yaml
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: free5gc-webui-$mcc-$mnc-sa
EOF

cat <<EOF > $mcc-$mnc/webui/base/webui-rbac.yaml
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: free5gc-webui-$mcc-$mnc-rbac
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: free5gc-webui-$mcc-$mnc-sa
EOF

cat <<EOF > $mcc-$mnc/webui/base/webui-service.yaml
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: free5gc-webui-$mcc-$mnc
  name: free5gc-webui-$mcc-$mnc
spec:
  type: NodePort
  ports:
  - name: free5gc-webui
    port: 5000
    protocol: TCP
    targetPort: 5000
  selector:
    app: free5gc-webui-$mcc-$mnc
EOF

cat <<EOF > $mcc-$mnc/webui/base/webui-deployment.yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: free5gc-webui-$mcc-$mnc
  labels:
    app: free5gc-webui-$mcc-$mnc
spec:
  replicas: 1
  selector:
    matchLabels:
      app: free5gc-webui-$mcc-$mnc
  strategy:
    type: RollingUpdate
  template:
    metadata:
      labels:
        app: free5gc-webui-$mcc-$mnc
        nsi: "$nsi"
        mcc: "$mcc"
        mnc: "$mnc"
        telecom: $abb
    spec:
      securityContext:
        runAsUser: 0
        runAsGroup: 0
      containers:
        - name: free5gc-webui
          image: black842679513/free5gc-webui:v3.0.5
          imagePullPolicy: IfNotPresent
          # imagePullPolicy: Always
          securityContext:
            privileged: false
          volumeMounts:
            - name: free5gc-webui-$mcc-$mnc-config
              mountPath: /free5gc/config
          ports:
            - containerPort: 5000
              name: free5gc-webui
              protocol: TCP
        - name: tcpdump
          image: corfr/tcpdump
          command:
            - /bin/sleep
            - infinity
      dnsPolicy: ClusterFirst
      restartPolicy: Always
      schedulerName: default-scheduler
      serviceAccountName: free5gc-webui-$mcc-$mnc-sa
      terminationGracePeriodSeconds: 30
      volumes:
        - name: free5gc-webui-$mcc-$mnc-config
          configMap:
            name: free5gc-webui-$mcc-$mnc-config
EOF

#
# create nrf
#

mkdir -p $mcc-$mnc/nrf/base/config
cp -rf TLS/nrf/ $mcc-$mnc/nrf/base/TLS

cat <<EOF > $mcc-$mnc/nrf/base/config/nrfcfg.yaml
info:
  version: 1.0.0
  description: NRF initial local configuration

configuration:
  MongoDBName: free5gc # database name in MongoDB
  MongoDBUrl: mongodb://free5gc-mongodb-$mcc-$mnc:27017 # a valid URL of the mongodb
  sbi: # Service-based interface information
    scheme: http # the protocol for sbi (http or https)
    registerIPv4: free5gc-nrf-$mcc-$mnc # IP used to serve NFs or register to another NRF
    bindingIPv4: 0.0.0.0  # IP used to bind the service
    port: 8000 # port used to bind the service
  DefaultPlmnId:
    mcc: $mcc # Mobile Country Code (3 digits string, digit: 0~9)
    mnc: $mnc # Mobile Network Code (2 or 3 digits string, digit: 0~9)
  serviceNameList: # the SBI services provided by this NRF, refer to TS 29.510
    - nnrf-nfm # Nnrf_NFManagement service
    - nnrf-disc # Nnrf_NFDiscovery service

# the kind of log output
  # debugLevel: how detailed to output, value: trace, debug, info, warn, error, fatal, panic
  # ReportCaller: enable the caller report or not, value: true or false
logger:
  NRF:
    debugLevel: info
    ReportCaller: false
  PathUtil:
    debugLevel: info
    ReportCaller: false
  OpenApi:
    debugLevel: info
    ReportCaller: false
  MongoDBLibrary:
    debugLevel: info
    ReportCaller: false
EOF

cat <<EOF > $mcc-$mnc/nrf/base/kustomization.yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: free5gc
resources:
  - nrf-sa.yaml
  - nrf-rbac.yaml
  - nrf-service.yaml
  - nrf-deployment.yaml

# declare Secret from a secretGenerator
secretGenerator:
- name: free5gc-nrf-$mcc-$mnc-tls-secret
  namespace: free5gc
  files:
  - TLS/nrf.pem
  - TLS/nrf.key
  type: "Opaque"
generatorOptions:
  disableNameSuffixHash: true

# declare ConfigMap from a ConfigMapGenerator
configMapGenerator:
- name: free5gc-nrf-$mcc-$mnc-config
  namespace: free5gc
  files:
    - config/nrfcfg.yaml
EOF

cat <<EOF > $mcc-$mnc/nrf/base/nrf-sa.yaml
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: free5gc-nrf-$mcc-$mnc-sa
EOF

cat <<EOF > $mcc-$mnc/nrf/base/nrf-rbac.yaml
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: free5gc-nrf-$mcc-$mnc-rbac
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: free5gc-nrf-$mcc-$mnc-sa
EOF

cat <<EOF > $mcc-$mnc/nrf/base/nrf-service.yaml
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: free5gc-nrf-$mcc-$mnc
  name: free5gc-nrf-$mcc-$mnc
spec:
  type: ClusterIP
  ports:
  - name: free5gc-nrf
    port: 8000
    protocol: TCP
    targetPort: 8000
  selector:
    app: free5gc-nrf-$mcc-$mnc
EOF

cat <<EOF > $mcc-$mnc/nrf/base/nrf-deployment.yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: free5gc-nrf-$mcc-$mnc
  labels:
    app: free5gc-nrf-$mcc-$mnc
spec:
  replicas: 1
  selector:
    matchLabels:
      app: free5gc-nrf-$mcc-$mnc
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: free5gc-nrf-$mcc-$mnc
        nsi: "$nsi"
        mcc: "$mcc"
        mnc: "$mnc"
        telecom: $abb
    spec:
      securityContext:
        runAsUser: 0
        runAsGroup: 0
      containers:
        - name: free5gc-nrf
          image: black842679513/free5gc-nrf:v3.0.5
          imagePullPolicy: IfNotPresent
          # imagePullPolicy: Always
          securityContext:
            privileged: false
          volumeMounts:
            - name: free5gc-nrf-$mcc-$mnc-config
              mountPath: /free5gc/config
            - name: free5gc-nrf-$mcc-$mnc-cert
              mountPath: /free5gc/support/TLS
          ports:
            - containerPort: 8000
              name: free5gc-nrf
              protocol: TCP
        - name: tcpdump
          image: corfr/tcpdump
          imagePullPolicy: IfNotPresent
          command:
            - /bin/sleep
            - infinity
      dnsPolicy: ClusterFirst
      restartPolicy: Always
      schedulerName: default-scheduler
      serviceAccountName: free5gc-nrf-$mcc-$mnc-sa
      terminationGracePeriodSeconds: 30
      volumes:
        - name: free5gc-nrf-$mcc-$mnc-cert
          secret:
            secretName: free5gc-nrf-$mcc-$mnc-tls-secret
        - name: free5gc-nrf-$mcc-$mnc-config
          configMap:
            name: free5gc-nrf-$mcc-$mnc-config
EOF

#
# create amf
#

mkdir -p $mcc-$mnc/amf/base/config
cp -rf TLS/amf/ $mcc-$mnc/amf/base/TLS

cat <<EOF > $mcc-$mnc/amf/base/config/amfcfg.yaml
info:
  version: 1.0.0
  description: AMF initial local configuration

configuration:
  amfName: AMF # the name of this AMF
  ngapIpList:  # the IP list of N2 interfaces on this AMF
    - $amf_ip
  sbi: # Service-based interface information
    scheme: http # the protocol for sbi (http or https)
    registerIPv4: free5gc-amf-$mcc-$mnc # IP used to register to NRF
    bindingIPv4: 0.0.0.0  # IP used to bind the service
    port: 8000 # port used to bind the service
  serviceNameList: # the SBI services provided by this AMF, refer to TS 29.518
    - namf-comm # Namf_Communication service
    - namf-evts # Namf_EventExposure service
    - namf-mt   # Namf_MT service
    - namf-loc  # Namf_Location service
    - namf-oam  # OAM service
  servedGuamiList: # Guami (Globally Unique AMF ID) list supported by this AMF
    # <GUAMI> = <MCC><MNC><AMF ID>
    - plmnId: # Public Land Mobile Network ID, <PLMN ID> = <MCC><MNC>
        mcc: $mcc # Mobile Country Code (3 digits string, digit: 0~9)
        mnc: $mnc # Mobile Network Code (2 or 3 digits string, digit: 0~9)
      amfId: cafe00 # AMF identifier (3 bytes hex string, range: 000000~FFFFFF)
  supportTaiList:  # the TAI (Tracking Area Identifier) list supported by this AMF
    - plmnId: # Public Land Mobile Network ID, <PLMN ID> = <MCC><MNC>
        mcc: $mcc # Mobile Country Code (3 digits string, digit: 0~9)
        mnc: $mnc # Mobile Network Code (2 or 3 digits string, digit: 0~9)
      tac: 1 # Tracking Area Code (uinteger, range: 0~16777215)
  plmnSupportList: # the PLMNs (Public land mobile network) list supported by this AMF
    - plmnId: # Public Land Mobile Network ID, <PLMN ID> = <MCC><MNC>
        mcc: $mcc # Mobile Country Code (3 digits string, digit: 0~9)
        mnc: $mnc # Mobile Network Code (2 or 3 digits string, digit: 0~9)
      snssaiList: # the S-NSSAI (Single Network Slice Selection Assistance Information) list supported by this AMF
        - sst: 1 # Slice/Service Type (uinteger, range: 0~255)
          sd: ${core_network_id}0203 # Slice Differentiator (3 bytes hex string, range: 000000~FFFFFF)
        - sst: 1 # Slice/Service Type (uinteger, range: 0~255)
          sd: ${core_network_id}0204 # Slice Differentiator (3 bytes hex string, range: 000000~FFFFFF)
        - sst: 1 # Slice/Service Type (uinteger, range: 0~255)
          sd: ${core_network_id}0205 # Slice Differentiator (3 bytes hex string, range: 000000~FFFFFF)
  supportDnnList:  # the DNN (Data Network Name) list supported by this AMF
    - internet
  nrfUri: http://free5gc-nrf-$mcc-$mnc:8000 # a valid URI of NRF
  security:  # NAS security parameters
    integrityOrder: # the priority of integrity algorithms
      - NIA2
      # - NIA0
    cipheringOrder: # the priority of ciphering algorithms
      - NEA0
      # - NEA2
  networkName:  # the name of this core network
    full: free5GC
    short: free
  t3502Value: 720  # timer value (seconds) at UE side
  t3512Value: 3600 # timer value (seconds) at UE side
  non3gppDeregistrationTimerValue: 3240 # timer value (seconds) at UE side
  # retransmission timer for paging message
  t3513:
    enable: true     # true or false
    expireTime: 6s   # default is 6 seconds
    maxRetryTimes: 4 # the max number of retransmission
  # retransmission timer for NAS Deregistration Request message
  t3522:
    enable: true     # true or false
    expireTime: 6s   # default is 6 seconds
    maxRetryTimes: 4 # the max number of retransmission
  # retransmission timer for NAS Registration Accept message
  t3550:
    enable: true     # true or false
    expireTime: 6s   # default is 6 seconds
    maxRetryTimes: 4 # the max number of retransmission
  # retransmission timer for NAS Authentication Request/Security Mode Command message
  t3560:
    enable: true     # true or false
    expireTime: 6s   # default is 6 seconds
    maxRetryTimes: 4 # the max number of retransmission
  # retransmission timer for NAS Notification message
  t3565:
    enable: true     # true or false
    expireTime: 6s   # default is 6 seconds
    maxRetryTimes: 4 # the max number of retransmission

# the kind of log output
  # debugLevel: how detailed to output, value: trace, debug, info, warn, error, fatal, panic
  # ReportCaller: enable the caller report or not, value: true or false
logger:
  AMF:
    debugLevel: info
    ReportCaller: false
  NAS:
    debugLevel: info
    ReportCaller: false
  FSM:
    debugLevel: info
    ReportCaller: false
  NGAP:
    debugLevel: info
    ReportCaller: false
  Aper:
    debugLevel: info
    ReportCaller: false
  PathUtil:
    debugLevel: info
    ReportCaller: false
  OpenApi:
    debugLevel: info
    ReportCaller: false
EOF

cat <<EOF > $mcc-$mnc/amf/base/kustomization.yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: free5gc
resources:
  - amf-sa.yaml
  - amf-rbac.yaml
  - amf-service.yaml
  - amf-deployment.yaml

# declare Secret from a secretGenerator
secretGenerator:
- name: free5gc-amf-$mcc-$mnc-tls-secret
  namespace: free5gc
  files:
  - TLS/amf.pem
  - TLS/amf.key
  type: "Opaque"
generatorOptions:
  disableNameSuffixHash: true

# declare ConfigMap from a ConfigMapGenerator
configMapGenerator:
- name: free5gc-amf-$mcc-$mnc-config
  namespace: free5gc
  files:
    - config/amfcfg.yaml
EOF

cat <<EOF > $mcc-$mnc/amf/base/amf-sa.yaml
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: free5gc-amf-$mcc-$mnc-sa
EOF

cat <<EOF > $mcc-$mnc/amf/base/amf-rbac.yaml
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: free5gc-amf-$mcc-$mnc-rbac
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: free5gc-amf-$mcc-$mnc-sa
EOF

cat <<EOF > $mcc-$mnc/amf/base/amf-service.yaml
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: free5gc-amf-$mcc-$mnc
  name: free5gc-amf-$mcc-$mnc
spec:
  # type: ClusterIP
  # type: NodePort
  clusterIP: None
  ports:
  - name: free5gc-amf
    port: 8000
    protocol: TCP
    targetPort: 8000
  - name: if-n1n2
    port: 38412
    protocol: SCTP
    targetPort: 38412
  #  nodePort: 32150
  selector:
    app: free5gc-amf-$mcc-$mnc
EOF

cat <<EOF > $mcc-$mnc/amf/base/amf-deployment.yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: free5gc-amf-$mcc-$mnc
  labels:
    app: free5gc-amf-$mcc-$mnc
spec:
  replicas: 1
  selector:
    matchLabels:
      app: free5gc-amf-$mcc-$mnc
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: free5gc-amf-$mcc-$mnc
        nsi: "$nsi"
        mcc: "$mcc"
        mnc: "$mnc"
        telecom: $abb
      annotations:
        k8s.v1.cni.cncf.io/networks: free5gc-macvlan
        free5gc-macvlan.free5gc.kubernetes.io/ip_address: $amf_ip
    spec:
      securityContext:
        runAsUser: 0
        runAsGroup: 0
      containers:
        - name: free5gc-amf
          image: black842679513/free5gc-amf:v3.0.5
          imagePullPolicy: IfNotPresent
          # imagePullPolicy: Always
          securityContext:
            privileged: false
          volumeMounts:
            - name: free5gc-amf-$mcc-$mnc-config
              mountPath: /free5gc/config
            - name: free5gc-amf-$mcc-$mnc-cert
              mountPath: /free5gc/support/TLS
          ports:
            - containerPort: 8000
              name: free5gc-amf
              protocol: TCP
            - containerPort: 38412
              name: if-n1n2
              protocol: SCTP
        - name: tcpdump
          image: corfr/tcpdump
          imagePullPolicy: IfNotPresent
          command:
            - /bin/sleep
            - infinity
      dnsPolicy: ClusterFirst
      restartPolicy: Always
      schedulerName: default-scheduler
      serviceAccountName: free5gc-amf-$mcc-$mnc-sa
      terminationGracePeriodSeconds: 30
      volumes:
        - name: free5gc-amf-$mcc-$mnc-cert
          secret:
            secretName: free5gc-amf-$mcc-$mnc-tls-secret
        - name: free5gc-amf-$mcc-$mnc-config
          configMap:
            name: free5gc-amf-$mcc-$mnc-config
EOF

#
# create ausf
#

mkdir -p $mcc-$mnc/ausf/base/config
cp -rf TLS/ausf/ $mcc-$mnc/ausf/base/TLS

cat <<EOF > $mcc-$mnc/ausf/base/config/ausfcfg.yaml
info:
  version: 1.0.0
  description: AUSF initial local configuration

configuration:
  sbi: # Service-based interface information
    scheme: http # the protocol for sbi (http or https)
    registerIPv4: free5gc-ausf-$mcc-$mnc # IP used to register to NRF
    bindingIPv4: 0.0.0.0  # IP used to bind the service
    port: 8000 # Port used to bind the service
  serviceNameList: # the SBI services provided by this AUSF, refer to TS 29.509
    - nausf-auth # Nausf_UEAuthentication service
  nrfUri: http://free5gc-nrf-$mcc-$mnc:8000 # a valid URI of NRF
  plmnSupportList: # the PLMNs (Public Land Mobile Network) list supported by this AUSF
    - mcc: $mcc # Mobile Country Code (3 digits string, digit: 0~9)
      mnc: $mnc  # Mobile Network Code (2 or 3 digits string, digit: 0~9)
  groupId: ausfGroup001 # ID for the group of the AUSF

# the kind of log output
  # debugLevel: how detailed to output, value: trace, debug, info, warn, error, fatal, panic
  # ReportCaller: enable the caller report or not, value: true or false
logger:
  AUSF:
    debugLevel: info
    ReportCaller: false
  PathUtil:
    debugLevel: info
    ReportCaller: false
  OpenApi:
    debugLevel: info
    ReportCaller: false
EOF

cat <<EOF > $mcc-$mnc/ausf/base/kustomization.yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: free5gc
resources:
  - ausf-sa.yaml
  - ausf-rbac.yaml
  - ausf-service.yaml
  - ausf-deployment.yaml

# declare Secret from a secretGenerator
secretGenerator:
- name: free5gc-ausf-$mcc-$mnc-tls-secret
  namespace: free5gc
  files:
  - TLS/ausf.pem
  - TLS/ausf.key
  type: "Opaque"
generatorOptions:
  disableNameSuffixHash: true

# declare ConfigMap from a ConfigMapGenerator
configMapGenerator:
- name: free5gc-ausf-$mcc-$mnc-config
  namespace: free5gc
  files:
    - config/ausfcfg.yaml
EOF

cat <<EOF > $mcc-$mnc/ausf/base/ausf-sa.yaml
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: free5gc-ausf-$mcc-$mnc-sa
EOF

cat <<EOF > $mcc-$mnc/ausf/base/ausf-rbac.yaml
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: free5gc-ausf-$mcc-$mnc-rbac
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: free5gc-ausf-$mcc-$mnc-sa
EOF

cat <<EOF > $mcc-$mnc/ausf/base/ausf-service.yaml
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: free5gc-ausf-$mcc-$mnc
  name: free5gc-ausf-$mcc-$mnc
spec:
  type: ClusterIP
  ports:
  - name: free5gc-ausf
    port: 8000
    protocol: TCP
    targetPort: 8000
  selector:
    app: free5gc-ausf-$mcc-$mnc
EOF

cat <<EOF > $mcc-$mnc/ausf/base/ausf-deployment.yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: free5gc-ausf-$mcc-$mnc
  labels:
    app: free5gc-ausf-$mcc-$mnc
spec:
  replicas: 1
  selector:
    matchLabels:
      app: free5gc-ausf-$mcc-$mnc
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: free5gc-ausf-$mcc-$mnc
        nsi: "$nsi"
        mcc: "$mcc"
        mnc: "$mnc"
        telecom: $abb
    spec:
      securityContext:
        runAsUser: 0
        runAsGroup: 0
      containers:
        - name: free5gc-ausf
          image: black842679513/free5gc-ausf:v3.0.5
          imagePullPolicy: IfNotPresent
          # imagePullPolicy: Always
          securityContext:
            privileged: true
          volumeMounts:
            - name: free5gc-ausf-$mcc-$mnc-config
              mountPath: /free5gc/config
            - name: free5gc-ausf-$mcc-$mnc-cert
              mountPath: /free5gc/support/TLS
          ports:
            - containerPort: 29509
              name: free5gc-ausf
              protocol: TCP
        - name: tcpdump
          image: corfr/tcpdump
          command:
            - /bin/sleep
            - infinity
      dnsPolicy: ClusterFirst
      restartPolicy: Always
      schedulerName: default-scheduler
      serviceAccountName: free5gc-ausf-$mcc-$mnc-sa
      terminationGracePeriodSeconds: 30
      volumes:
        - name: free5gc-ausf-$mcc-$mnc-cert
          secret:
            secretName: free5gc-ausf-$mcc-$mnc-tls-secret
        - name: free5gc-ausf-$mcc-$mnc-config
          configMap:
            name: free5gc-ausf-$mcc-$mnc-config
EOF

#
# create nssf
#

mkdir -p $mcc-$mnc/nssf/base/config
cp -rf TLS/nssf/ $mcc-$mnc/nssf/base/TLS

cat <<EOF > $mcc-$mnc/nssf/base/config/nssfcfg.yaml
info:
  version: 1.0.0
  description: NSSF initial local configuration

configuration:
  nssfName: NSSF # the name of this NSSF
  sbi: # Service-based interface information
    scheme: http # the protocol for sbi (http or https)
    registerIPv4: free5gc-nssf-$mcc-$mnc # IP used to register to NRF
    bindingIPv4: 0.0.0.0  # IP used to bind the service
    port: 8000 # Port used to bind the service
  serviceNameList: # the SBI services provided by this SMF, refer to TS 29.531
    - nnssf-nsselection # Nnssf_NSSelection service
    - nnssf-nssaiavailability # Nnssf_NSSAIAvailability service
  nrfUri: http://free5gc-nrf-$mcc-$mnc:8000 # a valid URI of NRF
  supportedPlmnList: # the PLMNs (Public land mobile network) list supported by this NSSF
    - mcc: $mcc # Mobile Country Code (3 digits string, digit: 0~9)
      mnc: $mnc # Mobile Network Code (2 or 3 digits string, digit: 0~9)
  supportedNssaiInPlmnList: # Supported S-NSSAI List for each PLMN
    - plmnId: # Public Land Mobile Network ID, <PLMN ID> = <MCC><MNC>
        mcc: $mcc # Mobile Country Code (3 digits string, digit: 0~9)
        mnc: $mnc # Mobile Network Code (2 or 3 digits string, digit: 0~9)
      supportedSnssaiList: # Supported S-NSSAIs of the PLMN
        - sst: 1 # Slice/Service Type (uinteger, range: 0~255)
          sd: ${core_network_id}0203 # Slice Differentiator (3 bytes hex string, range: 000000~FFFFFF)
        - sst: 1 # Slice/Service Type (uinteger, range: 0~255)
          sd: ${core_network_id}0204 # Slice Differentiator (3 bytes hex string, range: 000000~FFFFFF)
        - sst: 1 # Slice/Service Type (uinteger, range: 0~255)
          sd: ${core_network_id}0205 # Slice Differentiator (3 bytes hex string, range: 000000~FFFFFF)
  nsiList: # List of available Network Slice Instance (NSI)
    - snssai: # S-NSSAI of this NSI
        sst: 1 # Slice/Service Type (uinteger, range: 0~255)
        sd: ${core_network_id}0203 # Slice Differentiator (3 bytes hex string, range: 000000~FFFFFF)
      nsiInformationList: # Information list of this NSI
        # the NRF to be used to select the NFs/services within the selected NSI, and an optonal ID
        - nrfId: http://free5gc-nrf-$mcc-$mnc:8000/nnrf-nfm/v1/nf-instances
          nsiId: 10
    - snssai: # S-NSSAI of this NSI
        sst: 1 # Slice/Service Type (uinteger, range: 0~255)
        sd: ${core_network_id}0204 # Slice Differentiator (3 bytes hex string, range: 000000~FFFFFF)
      nsiInformationList: # Information list of this NSI
        # the NRF to be used to select the NFs/services within the selected NSI, and an optonal ID
        - nrfId: http://free5gc-nrf-$mcc-$mnc:8000/nnrf-nfm/v1/nf-instances
          nsiId: 11
    - snssai: # S-NSSAI of this NSI
        sst: 1 # Slice/Service Type (uinteger, range: 0~255)
        sd: ${core_network_id}0205 # Slice Differentiator (3 bytes hex string, range: 000000~FFFFFF)
      nsiInformationList: # Information list of this NSI
        # the NRF to be used to select the NFs/services within the selected NSI, and an optonal ID
        - nrfId: http://free5gc-nrf-$mcc-$mnc:8000/nnrf-nfm/v1/nf-instances
          nsiId: 12
  amfSetList: # List of AMF Sets that my be assigned by this NSSF
    - amfSetId: 1 # the AMF Set identifier
      amfList: # Instance ID of the AMFs in this set
        - ffa2e8d7-3275-49c7-8631-6af1df1d9d26
        - 0e8831c3-6286-4689-ab27-1e2161e15cb1
        - a1fba9ba-2e39-4e22-9c74-f749da571d0d
      # URI of the NRF used to determine the list of candidate AMF(s) from the AMF Set
      nrfAmfSet: http://free5gc-nrf-$mcc-$mnc:8000/nnrf-nfm/v1/nf-instances
      # the Nssai availability data information per TA supported by the AMF
      supportedNssaiAvailabilityData:
        - tai: # Tracking Area Identifier
            plmnId: # Public Land Mobile Network ID, <PLMN ID> = <MCC><MNC>
              mcc: 466 # Mobile Country Code (3 digits string, digit: 0~9)
              mnc: 92 # Mobile Network Code (2 or 3 digits string, digit: 0~9)
            tac: 33456 # Tracking Area Code (uinteger, range: 0~16777215)
          supportedSnssaiList: # Supported S-NSSAIs of the tracking area
            - sst: 1 # Slice/Service Type (uinteger, range: 0~255)
              sd: 000001 # Slice Differentiator (3 bytes hex string, range: 000000~FFFFFF)
            - sst: 1 # Slice/Service Type (uinteger, range: 0~255)
              sd: 000002 # Slice Differentiator (3 bytes hex string, range: 000000~FFFFFF)
            - sst: 2 # Slice/Service Type (uinteger, range: 0~255)
              sd: 000001 # Slice Differentiator (3 bytes hex string, range: 000000~FFFFFF)
        - tai: # Tracking Area Identifier
            plmnId: # Public Land Mobile Network ID, <PLMN ID> = <MCC><MNC>
              mcc: 466 # Mobile Country Code (3 digits string, digit: 0~9)
              mnc: 92 # Mobile Network Code (2 or 3 digits string, digit: 0~9)
            tac: 33457 # Tracking Area Code (uinteger, range: 0~16777215)
          supportedSnssaiList: # Supported S-NSSAIs of the tracking area
            - sst: 1 # Slice/Service Type (uinteger, range: 0~255)
            - sst: 1 # Slice/Service Type (uinteger, range: 0~255)
              sd: 000001 # Slice Differentiator (3 bytes hex string, range: 000000~FFFFFF)
            - sst: 1 # Slice/Service Type (uinteger, range: 0~255)
              sd: 000002 # Slice Differentiator (3 bytes hex string, range: 000000~FFFFFF)
    - amfSetId: 2 # the AMF Set identifier
      # URI of the NRF used to determine the list of candidate AMF(s) from the AMF Set
      nrfAmfSet: http://free5gc-nrf:8084/nnrf-nfm/v1/nf-instances
      # the Nssai availability data information per TA supported by the AMF
      supportedNssaiAvailabilityData:
        - tai: # Tracking Area Identifier
            plmnId: # Public Land Mobile Network ID, <PLMN ID> = <MCC><MNC>
              mcc: 466 # Mobile Country Code (3 digits string, digit: 0~9)
              mnc: 92 # Mobile Network Code (2 or 3 digits string, digit: 0~9)
            tac: 33456 # Tracking Area Code (uinteger, range: 0~16777215)
          supportedSnssaiList: # Supported S-NSSAIs of the tracking area
            - sst: 1 # Slice/Service Type (uinteger, range: 0~255)
            - sst: 1 # Slice/Service Type (uinteger, range: 0~255)
              sd: 000001 # Slice Differentiator (3 bytes hex string, range: 000000~FFFFFF)
            - sst: 1 # Slice/Service Type (uinteger, range: 0~255)
              sd: 000003 # Slice Differentiator (3 bytes hex string, range: 000000~FFFFFF)
            - sst: 2 # Slice/Service Type (uinteger, range: 0~255)
              sd: 000001 # Slice Differentiator (3 bytes hex string, range: 000000~FFFFFF)
        - tai: # Tracking Area Identifier
            plmnId: # Public Land Mobile Network ID, <PLMN ID> = <MCC><MNC>
              mcc: 466 # Mobile Country Code (3 digits string, digit: 0~9)
              mnc: 92 # Mobile Network Code (2 or 3 digits string, digit: 0~9)
            tac: 33458 # Tracking Area Code (uinteger, range: 0~16777215)
          supportedSnssaiList: # Supported S-NSSAIs of the tracking area
            - sst: 1 # Slice/Service Type (uinteger, range: 0~255)
            - sst: 1 # Slice/Service Type (uinteger, range: 0~255)
              sd: 000001 # Slice Differentiator (3 bytes hex string, range: 000000~FFFFFF)
            - sst: 2 # Slice/Service Type (uinteger, range: 0~255)
  amfList: # List of AMFs that may be assigned by this NSSF
    - nfId: 469de254-2fe5-4ca0-8381-af3f500af77c # ID of this AMF
      # The NSSAI availability data information per TA supported by the AMF
      supportedNssaiAvailabilityData:
        - tai: # Tracking Area Identifier
            plmnId: # Public Land Mobile Network ID, <PLMN ID> = <MCC><MNC>
              mcc: 466 # Mobile Country Code (3 digits string, digit: 0~9)
              mnc: 92 # Mobile Network Code (2 or 3 digits string, digit: 0~9)
            tac: 33456 # Tracking Area Code (uinteger, range: 0~16777215)
          supportedSnssaiList: # Supported S-NSSAIs of the tracking area
            - sst: 1 # Slice/Service Type (uinteger, range: 0~255)
            - sst: 1 # Slice/Service Type (uinteger, range: 0~255)
              sd: 000002 # Slice Differentiator (3 bytes hex string, range: 000000~FFFFFF)
            - sst: 2 # Slice/Service Type (uinteger, range: 0~255)
        - tai: # Tracking Area Identifier
            plmnId: # Public Land Mobile Network ID, <PLMN ID> = <MCC><MNC>
              mcc: 466 # Mobile Country Code (3 digits string, digit: 0~9)
              mnc: 92 # Mobile Network Code (2 or 3 digits string, digit: 0~9)
            tac: 33457 # Tracking Area Code (uinteger, range: 0~16777215)
          supportedSnssaiList: # Supported S-NSSAIs of the tracking area
            - sst: 1 # Slice/Service Type (uinteger, range: 0~255)
              sd: 000001 # Slice Differentiator (3 bytes hex string, range: 000000~FFFFFF)
            - sst: 1 # Slice/Service Type (uinteger, range: 0~255)
              sd: 000002 # Slice Differentiator (3 bytes hex string, range: 000000~FFFFFF)
    - nfId: fbe604a8-27b2-417e-bd7c-8a7be2691f8d # ID of this AMF
      # The NSSAI availability data information per TA supported by the AMF
      supportedNssaiAvailabilityData:
        - tai: # Tracking Area Identifier
            plmnId: # Public Land Mobile Network ID, <PLMN ID> = <MCC><MNC>
              mcc: 466 # Mobile Country Code (3 digits string, digit: 0~9)
              mnc: 92 # Mobile Network Code (2 or 3 digits string, digit: 0~9)
            tac: 33458 # Tracking Area Code (uinteger, range: 0~16777215)
          supportedSnssaiList: # Supported S-NSSAIs of the tracking area
            - sst: 1 # Slice/Service Type (uinteger, range: 0~255)
            - sst: 1 # Slice/Service Type (uinteger, range: 0~255)
              sd: 000001 # Slice Differentiator (3 bytes hex string, range: 000000~FFFFFF)
            - sst: 1 # Slice/Service Type (uinteger, range: 0~255)
              sd: 000003 # Slice Differentiator (3 bytes hex string, range: 000000~FFFFFF)
            - sst: 2 # Slice/Service Type (uinteger, range: 0~255)
        - tai: # Tracking Area Identifier
            plmnId: # Public Land Mobile Network ID, <PLMN ID> = <MCC><MNC>
              mcc: 466 # Mobile Country Code (3 digits string, digit: 0~9)
              mnc: 92 # Mobile Network Code (2 or 3 digits string, digit: 0~9)
            tac: 33459 # Tracking Area Code (uinteger, range: 0~16777215)
          supportedSnssaiList: # Supported S-NSSAIs of the tracking area
            - sst: 1 # Slice/Service Type (uinteger, range: 0~255)
            - sst: 1 # Slice/Service Type (uinteger, range: 0~255)
              sd: 000001 # Slice Differentiator (3 bytes hex string, range: 000000~FFFFFF)
            - sst: 2 # Slice/Service Type (uinteger, range: 0~255)
            - sst: 2 # Slice/Service Type (uinteger, range: 0~255)
              sd: 000001 # Slice Differentiator (3 bytes hex string, range: 000000~FFFFFF)
    - nfId: b9e6e2cb-5ce8-4cb6-9173-a266dd9a2f0c # ID of this AMF
      # The NSSAI availability data information per TA supported by the AMF
      supportedNssaiAvailabilityData:
        - tai: # Tracking Area Identifier
            plmnId: # Public Land Mobile Network ID, <PLMN ID> = <MCC><MNC>
              mcc: 466 # Mobile Country Code (3 digits string, digit: 0~9)
              mnc: 92 # Mobile Network Code (2 or 3 digits string, digit: 0~9)
            tac: 33456 # Tracking Area Code (uinteger, range: 0~16777215)
          supportedSnssaiList: # Supported S-NSSAIs of the tracking area
            - sst: 1 # Slice/Service Type (uinteger, range: 0~255)
            - sst: 1 # Slice/Service Type (uinteger, range: 0~255)
              sd: 000001 # Slice Differentiator (3 bytes hex string, range: 000000~FFFFFF)
            - sst: 1 # Slice/Service Type (uinteger, range: 0~255)
              sd: 000002 # Slice Differentiator (3 bytes hex string, range: 000000~FFFFFF)
            - sst: 2 # Slice/Service Type (uinteger, range: 0~255)
        - tai: # Tracking Area Identifier
            plmnId: # Public Land Mobile Network ID, <PLMN ID> = <MCC><MNC>
              mcc: 466 # Mobile Country Code (3 digits string, digit: 0~9)
              mnc: 92 # Mobile Network Code (2 or 3 digits string, digit: 0~9)
            tac: 33458 # Tracking Area Code (uinteger, range: 0~16777215)
          supportedSnssaiList: # Supported S-NSSAIs of the tracking area
            - sst: 1 # Slice/Service Type (uinteger, range: 0~255)
            - sst: 1 # Slice/Service Type (uinteger, range: 0~255)
              sd: 000001 # Slice Differentiator (3 bytes hex string, range: 000000~FFFFFF)
            - sst: 2 # Slice/Service Type (uinteger, range: 0~255)
            - sst: 2 # Slice/Service Type (uinteger, range: 0~255)
              sd: 000001 # Slice Differentiator (3 bytes hex string, range: 000000~FFFFFF)
  taList: # List of supported tracking area and their related information of this NSSF instance
    - tai: # Tracking Area Identity
        plmnId: # Public Land Mobile Network ID, <PLMN ID> = <MCC><MNC>
          mcc: 466 # Mobile Country Code (3 digits string, digit: 0~9)
          mnc: 92 # Mobile Network Code (2 or 3 digits string, digit: 0~9)
        tac: 33456 # Tracking Area Code (uinteger, range: 0~16777215)
      accessType: 3GPP_ACCESS # Access type of the tracking area
      supportedSnssaiList: # List of supported S-NSSAIs of the tracking area
        - sst: 1 # Slice/Service Type (uinteger, range: 0~255)
        - sst: 1 # Slice/Service Type (uinteger, range: 0~255)
          sd: 000001 # Slice Differentiator (3 bytes hex string, range: 000000~FFFFFF)
        - sst: 1 # Slice/Service Type (uinteger, range: 0~255)
          sd: 000002 # Slice Differentiator (3 bytes hex string, range: 000000~FFFFFF)
        - sst: 2 # Slice/Service Type (uinteger, range: 0~255)
    - tai: # Tracking Area Identity
        plmnId: # Public Land Mobile Network ID, <PLMN ID> = <MCC><MNC>
          mcc: 466 # Mobile Country Code (3 digits string, digit: 0~9)
          mnc: 92 # Mobile Network Code (2 or 3 digits string, digit: 0~9)
        tac: 33457 # Tracking Area Code (uinteger, range: 0~16777215)
      accessType: 3GPP_ACCESS # Access type of the tracking area
      supportedSnssaiList: # List of supported S-NSSAIs of the tracking area
        - sst: 1 # Slice/Service Type (uinteger, range: 0~255)
        - sst: 1 # Slice/Service Type (uinteger, range: 0~255)
          sd: 000001 # Slice Differentiator (3 bytes hex string, range: 000000~FFFFFF)
        - sst: 1 # Slice/Service Type (uinteger, range: 0~255)
          sd: 000002 # Slice Differentiator (3 bytes hex string, range: 000000~FFFFFF)
        - sst: 2 # Slice/Service Type (uinteger, range: 0~255)
    - tai: # Tracking Area Identifier
        plmnId: # Public Land Mobile Network ID, <PLMN ID> = <MCC><MNC>
          mcc: 466 # Mobile Country Code (3 digits string, digit: 0~9)
          mnc: 92 # Mobile Network Code (2 or 3 digits string, digit: 0~9)
        tac: 33458 # Tracking Area Code (uinteger, range: 0~16777215)
      accessType: 3GPP_ACCESS # Access type of the tracking area
      supportedSnssaiList: # List of supported S-NSSAIs of the tracking area
        - sst: 1 # Slice/Service Type (uinteger, range: 0~255)
        - sst: 1 # Slice/Service Type (uinteger, range: 0~255)
          sd: 000001 # Slice Differentiator (3 bytes hex string, range: 000000~FFFFFF)
        - sst: 1 # Slice/Service Type (uinteger, range: 0~255)
          sd: 000003 # Slice Differentiator (3 bytes hex string, range: 000000~FFFFFF)
        - sst: 2 # Slice/Service Type (uinteger, range: 0~255)
      restrictedSnssaiList: # List of restricted S-NSSAIs of the tracking area
        - homePlmnId: # Home PLMN identifier
            mcc: 310 # Mobile Country Code (3 digits string, digit: 0~9)
            mnc: 560 # Mobile Network Code (2 or 3 digits string, digit: 0~9)
          sNssaiList: # the S-NSSAIs List
            - sst: 1 # Slice/Service Type (uinteger, range: 0~255)
              sd: 000003 # Slice Differentiator (3 bytes hex string, range: 000000~FFFFFF)
    - tai: # Tracking Area Identifier
        plmnId: # Public Land Mobile Network ID, <PLMN ID> = <MCC><MNC>
          mcc: 466 # Mobile Country Code (3 digits string, digit: 0~9)
          mnc: 92 # Mobile Network Code (2 or 3 digits string, digit: 0~9)
        tac: 33459 # Tracking Area Code (uinteger, range: 0~16777215)
      accessType: 3GPP_ACCESS # Access type of the tracking area
      supportedSnssaiList: # List of supported S-NSSAIs of the tracking area
        - sst: 1 # Slice/Service Type (uinteger, range: 0~255)
        - sst: 1 # Slice/Service Type (uinteger, range: 0~255)
          sd: 000001 # Slice Differentiator (3 bytes hex string, range: 000000~FFFFFF)
        - sst: 2 # Slice/Service Type (uinteger, range: 0~255)
        - sst: 2 # Slice/Service Type (uinteger, range: 0~255)
          sd: 000001 # Slice Differentiator (3 bytes hex string, range: 000000~FFFFFF)
      restrictedSnssaiList: # List of restricted S-NSSAIs of the tracking area
        - homePlmnId: # Home PLMN identifier
            mcc: 310 # Mobile Country Code (3 digits string, digit: 0~9)
            mnc: 560 # Mobile Network Code (2 or 3 digits string, digit: 0~9)
          sNssaiList: # the S-NSSAIs List
            - sst: 2 # Slice/Service Type (uinteger, range: 0~255)
              sd: 000001 # Slice Differentiator (3 bytes hex string, range: 000000~FFFFFF)
  # List of mappings of S-NSSAI in the serving network and the value of the home network
  mappingListFromPlmn:
    - operatorName: NTT Docomo # Home PLMN name
      homePlmnId: # Home PLMN identifier
        mcc: 440 # Mobile Country Code (3 digits string, digit: 0~9)
        mnc: 10 # Mobile Network Code (2 or 3 digits string, digit: 0~9)
      mappingOfSnssai: # List of S-NSSAIs mapping
        - servingSnssai: # S-NSSAI in the serving network
            sst: 1 # Slice/Service Type (uinteger, range: 0~255)
            sd: 000001 # Slice Differentiator (3 bytes hex string, range: 000000~FFFFFF)
          homeSnssai: # S-NSSAI in the home network
            sst: 1 # Slice/Service Type (uinteger, range: 0~255)
            sd: 1 # Slice Differentiator (3 bytes hex string, range: 000000~FFFFFF)
        - servingSnssai: # S-NSSAI in the serving network
            sst: 1 # Slice/Service Type (uinteger, range: 0~255)
            sd: 000002 # Slice Differentiator (3 bytes hex string, range: 000000~FFFFFF)
          homeSnssai: # S-NSSAI in the home network
            sst: 1 # Slice/Service Type (uinteger, range: 0~255)
            sd: 000003 # Slice Differentiator (3 bytes hex string, range: 000000~FFFFFF)
        - servingSnssai: # S-NSSAI in the serving network
            sst: 1 # Slice/Service Type (uinteger, range: 0~255)
            sd: 000003 # Slice Differentiator (3 bytes hex string, range: 000000~FFFFFF)
          homeSnssai: # S-NSSAI in the home network
            sst: 1 # Slice/Service Type (uinteger, range: 0~255)
            sd: 000004 # Slice Differentiator (3 bytes hex string, range: 000000~FFFFFF)
        - servingSnssai: # S-NSSAI in the serving network
            sst: 2 # Slice/Service Type (uinteger, range: 0~255)
            sd: 000001 # Slice Differentiator (3 bytes hex string, range: 000000~FFFFFF)
          homeSnssai: # S-NSSAI in the home network
            sst: 2 # Slice/Service Type (uinteger, range: 0~255)
            sd: 000002 # Slice Differentiator (3 bytes hex string, range: 000000~FFFFFF)
    - operatorName: AT&T Mobility # Home PLMN name
      homePlmnId: # Home PLMN identifier
        mcc: 310 # Mobile Country Code (3 digits string, digit: 0~9)
        mnc: 560 # Mobile Network Code (2 or 3 digits string, digit: 0~9)
      mappingOfSnssai:
        - servingSnssai: # S-NSSAI in the serving network
            sst: 1 # Slice/Service Type (uinteger, range: 0~255)
            sd: 000001 # Slice Differentiator (3 bytes hex string, range: 000000~FFFFFF)
          homeSnssai: # S-NSSAI in the home network
            sst: 1 # Slice/Service Type (uinteger, range: 0~255)
            sd: 000002 # Slice Differentiator (3 bytes hex string, range: 000000~FFFFFF)
        - servingSnssai: # S-NSSAI in the serving network
            sst: 1 # Slice/Service Type (uinteger, range: 0~255)
            sd: 000002 # Slice Differentiator (3 bytes hex string, range: 000000~FFFFFF)
          homeSnssai: # S-NSSAI in the home network
            sst: 1 # Slice/Service Type (uinteger, range: 0~255)
            sd: 000003 # Slice Differentiator (3 bytes hex string, range: 000000~FFFFFF)

# the kind of log output
  # debugLevel: how detailed to output, value: trace, debug, info, warn, error, fatal, panic
  # ReportCaller: enable the caller report or not, value: true or false
logger:
  NSSF:
    debugLevel: info
    ReportCaller: false
  PathUtil:
    debugLevel: info
    ReportCaller: false
  OpenApi:
    debugLevel: info
    ReportCaller: false
EOF

cat <<EOF > $mcc-$mnc/nssf/base/kustomization.yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: free5gc
resources:
  - nssf-sa.yaml
  - nssf-rbac.yaml
  - nssf-service.yaml
  - nssf-deployment.yaml

# declare Secret from a secretGenerator
secretGenerator:
- name: free5gc-nssf-$mcc-$mnc-tls-secret
  namespace: free5gc
  files:
  - TLS/nssf.pem
  - TLS/nssf.key
  type: "Opaque"
generatorOptions:
  disableNameSuffixHash: true

# declare ConfigMap from a ConfigMapGenerator
configMapGenerator:
- name: free5gc-nssf-$mcc-$mnc-config
  namespace: free5gc
  files:
    - config/nssfcfg.yaml
EOF

cat <<EOF > $mcc-$mnc/nssf/base/nssf-sa.yaml
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: free5gc-nssf-$mcc-$mnc-sa
EOF

cat <<EOF > $mcc-$mnc/nssf/base/nssf-rbac.yaml
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: free5gc-nssf-$mcc-$mnc-rbac
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: free5gc-nssf-$mcc-$mnc-sa
EOF

cat <<EOF > $mcc-$mnc/nssf/base/nssf-service.yaml
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: free5gc-nssf-$mcc-$mnc
  name: free5gc-nssf-$mcc-$mnc
spec:
  type: ClusterIP
  ports:
  - name: free5gc-nssf
    port: 8000
    protocol: TCP
    targetPort: 8000
  selector:
    app: free5gc-nssf-$mcc-$mnc
EOF

cat <<EOF > $mcc-$mnc/nssf/base/nssf-deployment.yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: free5gc-nssf-$mcc-$mnc
  labels:
    app: free5gc-nssf-$mcc-$mnc
spec:
  replicas: 1
  selector:
    matchLabels:
      app: free5gc-nssf-$mcc-$mnc
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: free5gc-nssf-$mcc-$mnc
        nsi: "$nsi"
        mcc: "$mcc"
        mnc: "$mnc"
        telecom: $abb
    spec:
      securityContext:
        runAsUser: 0
        runAsGroup: 0
      containers:
        - name: free5gc-nssf
          image: black842679513/free5gc-nssf:v3.0.5
          imagePullPolicy: IfNotPresent
          # imagePullPolicy: Always
          securityContext:
            privileged: false
          volumeMounts:
            - name: free5gc-nssf-$mcc-$mnc-config
              mountPath: /free5gc/config
            - name: free5gc-nssf-$mcc-$mnc-cert
              mountPath: /free5gc/support/TLS
          ports:
            - containerPort: 8000
              name: free5gc-nssf
              protocol: TCP
        - name: tcpdump
          image: corfr/tcpdump
          command:
            - /bin/sleep
            - infinity
      dnsPolicy: ClusterFirst
      restartPolicy: Always
      schedulerName: default-scheduler
      serviceAccountName: free5gc-nssf-$mcc-$mnc-sa
      terminationGracePeriodSeconds: 30
      volumes:
        - name: free5gc-nssf-$mcc-$mnc-cert
          secret:
            secretName: free5gc-nssf-$mcc-$mnc-tls-secret
        - name: free5gc-nssf-$mcc-$mnc-config
          configMap:
            name: free5gc-nssf-$mcc-$mnc-config
EOF

#
# create pcf
#

mkdir -p $mcc-$mnc/pcf/base/config
cp -rf TLS/pcf/ $mcc-$mnc/pcf/base/TLS

cat <<EOF > $mcc-$mnc/pcf/base/config/pcfcfg.yaml
info:
  version: 1.0.0
  description: PCF initial local configuration

configuration:
  pcfName: PCF # the name of this PCF
  sbi: # Service-based interface information
    scheme: http # the protocol for sbi (http or https)
    registerIPv4: free5gc-pcf-$mcc-$mnc # IP used to register to NRF
    bindingIPv4: 0.0.0.0  # IP used to bind the service
    port: 8000              # port used to bind the service
  timeFormat: 2019-01-02 15:04:05 # time format of this PCF
  defaultBdtRefId: BdtPolicyId-   # BDT Reference ID, indicating transfer policies of background data transfer.
  nrfUri: http://free5gc-nrf-$mcc-$mnc:8000  # a valid URI of NRF
  serviceList:   # the SBI services provided by this PCF, refer to TS 29.507
    - serviceName: npcf-am-policy-control # Npcf_AMPolicyControl service
    - serviceName: npcf-smpolicycontrol   # Npcf_SMPolicyControl service
      suppFeat: 3fff # the features supported by Npcf_SMPolicyControl, name defined in TS 29.512 5.8-1, value defined in TS 29.571 5.2.2
    - serviceName: npcf-bdtpolicycontrol    # Npcf_BDTPolicyControl service
    - serviceName: npcf-policyauthorization # Npcf_PolicyAuthorization service
      suppFeat: 3    # the features supported by Npcf_PolicyAuthorization, name defined in TS 29.514 5.8-1, value defined in TS 29.571 5.2.2
    - serviceName: npcf-eventexposure       # Npcf_EventExposure service
    - serviceName: npcf-ue-policy-control   # Npcf_UEPolicyControl service
  mongodb:       # the mongodb connected by this PCF
    name: free5gc                  # name of the mongodb
    url: mongodb://free5gc-mongodb-$mcc-$mnc:27017 # a valid URL of the mongodb

# the kind of log output
  # debugLevel: how detailed to output, value: trace, debug, info, warn, error, fatal, panic
  # ReportCaller: enable the caller report or not, value: true or false
logger:
  PCF:
    debugLevel: info
    ReportCaller: false
  PathUtil:
    debugLevel: info
    ReportCaller: false
  OpenApi:
    debugLevel: info
    ReportCaller: false
EOF

cat <<EOF > $mcc-$mnc/pcf/base/kustomization.yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: free5gc
resources:
  - pcf-sa.yaml
  - pcf-rbac.yaml
  - pcf-service.yaml
  - pcf-deployment.yaml

# declare Secret from a secretGenerator
secretGenerator:
- name: free5gc-pcf-$mcc-$mnc-tls-secret
  namespace: free5gc
  files:
  - TLS/pcf.pem
  - TLS/pcf.key
  type: "Opaque"
generatorOptions:
  disableNameSuffixHash: true

# declare ConfigMap from a ConfigMapGenerator
configMapGenerator:
- name: free5gc-pcf-$mcc-$mnc-config
  namespace: free5gc
  files:
    - config/pcfcfg.yaml
EOF

cat <<EOF > $mcc-$mnc/pcf/base/pcf-sa.yaml
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: free5gc-pcf-$mcc-$mnc-sa
EOF

cat <<EOF > $mcc-$mnc/pcf/base/pcf-rbac.yaml
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: free5gc-pcf-$mcc-$mnc-rbac
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: free5gc-pcf-$mcc-$mnc-sa
EOF

cat <<EOF > $mcc-$mnc/pcf/base/pcf-service.yaml
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: free5gc-pcf-$mcc-$mnc
  name: free5gc-pcf-$mcc-$mnc
spec:
  type: ClusterIP
  ports:
  - name: free5gc-pcf
    port: 8000
    protocol: TCP
    targetPort: 8000
  selector:
    app: free5gc-pcf-$mcc-$mnc
EOF

cat <<EOF > $mcc-$mnc/pcf/base/pcf-deployment.yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: free5gc-pcf-$mcc-$mnc
  labels:
    app: free5gc-pcf-$mcc-$mnc
spec:
  replicas: 1
  selector:
    matchLabels:
      app: free5gc-pcf-$mcc-$mnc
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: free5gc-pcf-$mcc-$mnc
        nsi: "$nsi"
        mcc: "$mcc"
        mnc: "$mnc"
        telecom: $abb
    spec:
      securityContext:
        runAsUser: 0
        runAsGroup: 0
      containers:
        - name: free5gc-pcf
          image: black842679513/free5gc-pcf:v3.0.5
          imagePullPolicy: IfNotPresent
          # imagePullPolicy: Always
          securityContext:
            privileged: false
          volumeMounts:
            - name: free5gc-pcf-$mcc-$mnc-config
              mountPath: /free5gc/config
            - name: free5gc-pcf-$mcc-$mnc-cert
              mountPath: /free5gc/support/TLS
          ports:
            - containerPort: 8000
              name: free5gc-pcf
              protocol: TCP
        - name: tcpdump
          image: corfr/tcpdump
          command:
            - /bin/sleep
            - infinity
      dnsPolicy: ClusterFirst
      restartPolicy: Always
      schedulerName: default-scheduler
      serviceAccountName: free5gc-pcf-$mcc-$mnc-sa
      terminationGracePeriodSeconds: 30
      volumes:
        - name: free5gc-pcf-$mcc-$mnc-cert
          secret:
            secretName: free5gc-pcf-$mcc-$mnc-tls-secret
        - name: free5gc-pcf-$mcc-$mnc-config
          configMap:
            name: free5gc-pcf-$mcc-$mnc-config
EOF

#
# create udm
#

mkdir -p $mcc-$mnc/udm/base/config
cp -rf TLS/udm/ $mcc-$mnc/udm/base/TLS

cat <<EOF > $mcc-$mnc/udm/base/config/udmcfg.yaml
info:
  version: 1.0.0
  description: UDM initial local configuration

configuration:
  serviceNameList: # the SBI services provided by this UDM, refer to TS 29.503
    - nudm-sdm # Nudm_SubscriberDataManagement service
    - nudm-uecm # Nudm_UEContextManagement service
    - nudm-ueau # Nudm_UEAuthenticationManagement service
    - nudm-ee # Nudm_EventExposureManagement service
    - nudm-pp # Nudm_ParameterProvisionDataManagement service
  sbi: # Service-based interface information
    scheme: http # the protocol for sbi (http or https)
    registerIPv4: free5gc-udm-$mcc-$mnc # IP used to register to NRF
    bindingIPv4: 0.0.0.0  # IP used to bind the service
    port: 8000 # Port used to bind the service
    tls: # the local path of TLS key
      log: free5gc/udmsslkey.log # UDM keylog
      pem: free5gc/support/TLS/udm.pem # UDM TLS Certificate
      key: free5gc/support/TLS/udm.key # UDM TLS Private key
  nrfUri: http://free5gc-nrf-$mcc-$mnc:8000 # a valid URI of NRF

  # test data set from TS33501-f60 Annex C.4
  keys:
    udmProfileAHNPublicKey: 5a8d38864820197c3394b92613b20b91633cbd897119273bf8e4a6f4eec0a650
    udmProfileAHNPrivateKey: c53c22208b61860b06c62e5406a7b330c2b577aa5558981510d128247d38bd1d
    udmProfileBHNPublicKey: 0472DA71976234CE833A6907425867B82E074D44EF907DFB4B3E21C1C2256EBCD15A7DED52FCBB097A4ED250E036C7B9C8C7004C4EEDC4F068CD7BF8D3F900$
    udmProfileBHNPrivateKey: F1AB1074477EBCC7F554EA1C5FC368B1616730155E0041AC447D6301975FECDA

# the kind of log output
  # debugLevel: how detailed to output, value: trace, debug, info, warn, error, fatal, panic
  # ReportCaller: enable the caller report or not, value: true or false
logger:
  UDM:
    debugLevel: info
    ReportCaller: false
  OpenApi:
    debugLevel: info
    ReportCaller: false
  PathUtil:
    debugLevel: info
    ReportCaller: false
EOF

cat <<EOF > $mcc-$mnc/udm/base/kustomization.yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: free5gc
resources:
  - udm-sa.yaml
  - udm-rbac.yaml
  - udm-service.yaml
  - udm-deployment.yaml

# declare Secret from a secretGenerator
secretGenerator:
- name: free5gc-udm-$mcc-$mnc-tls-secret
  namespace: free5gc
  files:
  - TLS/udm.pem
  - TLS/udm.key
  type: "Opaque"
generatorOptions:
  disableNameSuffixHash: true

# declare ConfigMap from a ConfigMapGenerator
configMapGenerator:
- name: free5gc-udm-$mcc-$mnc-config
  namespace: free5gc
  files:
    - config/udmcfg.yaml
EOF

cat <<EOF > $mcc-$mnc/udm/base/udm-sa.yaml
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: free5gc-udm-$mcc-$mnc-sa
EOF

cat <<EOF > $mcc-$mnc/udm/base/udm-rbac.yaml
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: free5gc-udm-$mcc-$mnc-rbac
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: free5gc-udm-$mcc-$mnc-sa
EOF

cat <<EOF > $mcc-$mnc/udm/base/udm-service.yaml
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: free5gc-udm-$mcc-$mnc
  name: free5gc-udm-$mcc-$mnc
spec:
  type: ClusterIP
  ports:
  - name: free5gc-udm
    port: 8000
    protocol: TCP
    targetPort: 8000
  selector:
    app: free5gc-udm-$mcc-$mnc
EOF

cat <<EOF > $mcc-$mnc/udm/base/udm-deployment.yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: free5gc-udm-$mcc-$mnc
  labels:
    app: free5gc-udm-$mcc-$mnc
spec:
  replicas: 1
  selector:
    matchLabels:
      app: free5gc-udm-$mcc-$mnc
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: free5gc-udm-$mcc-$mnc
        nsi: "$nsi"
        mcc: "$mcc"
        mnc: "$mnc"
        telecom: $abb
    spec:
      securityContext:
        runAsUser: 0
        runAsGroup: 0
      containers:
        - name: free5gc-udm
          image: black842679513/free5gc-udm:v3.0.5
          imagePullPolicy: IfNotPresent
          # imagePullPolicy: Always
          securityContext:
            privileged: false
          volumeMounts:
            - name: free5gc-udm-$mcc-$mnc-config
              mountPath: /free5gc/config
            - name: free5gc-udm-$mcc-$mnc-cert
              mountPath: /free5gc/support/TLS
          ports:
            - containerPort: 8000
              name: free5gc-udm
              protocol: TCP
        - name: tcpdump
          image: corfr/tcpdump
          command:
            - /bin/sleep
            - infinity
      dnsPolicy: ClusterFirst
      restartPolicy: Always
      schedulerName: default-scheduler
      serviceAccountName: free5gc-udm-$mcc-$mnc-sa
      terminationGracePeriodSeconds: 30
      volumes:
        - name: free5gc-udm-$mcc-$mnc-cert
          secret:
            secretName: free5gc-udm-$mcc-$mnc-tls-secret
        - name: free5gc-udm-$mcc-$mnc-config
          configMap:
            name: free5gc-udm-$mcc-$mnc-config
EOF

#
# create udr
#

mkdir -p $mcc-$mnc/udr/base/config
cp -rf TLS/udr/ $mcc-$mnc/udr/base/TLS

cat <<EOF > $mcc-$mnc/udr/base/config/udrcfg.yaml
info:
  version: 1.0.0
  description: UDR initial local configuration

configuration:
  sbi: # Service-based interface information
    scheme: http # the protocol for sbi (http or https)
    registerIPv4: free5gc-udr-$mcc-$mnc # IP used to register to NRF
    bindingIPv4: 0.0.0.0  # IP used to bind the service
    port: 8000 # port used to bind the service
  mongodb:
    name: free5gc # Database name in MongoDB
    url: mongodb://free5gc-mongodb-$mcc-$mnc:27017 # URL of MongoDB
  nrfUri: http://free5gc-nrf-$mcc-$mnc:8000 # a valid URI of NRF

# the kind of log output
  # debugLevel: how detailed to output, value: trace, debug, info, warn, error, fatal, panic
  # ReportCaller: enable the caller report or not, value: true or false
logger:
  UDR:
    debugLevel: info
    ReportCaller: false
  MongoDBLibrary:
    debugLevel: info
    ReportCaller: false
  PathUtil:
    debugLevel: info
    ReportCaller: false
  OpenApi:
    debugLevel: info
    ReportCaller: false
EOF

cat <<EOF > $mcc-$mnc/udr/base/kustomization.yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: free5gc
resources:
  - udr-sa.yaml
  - udr-rbac.yaml
  - udr-service.yaml
  - udr-deployment.yaml

# declare Secret from a secretGenerator
secretGenerator:
- name: free5gc-udr-$mcc-$mnc-tls-secret
  namespace: free5gc
  files:
  - TLS/udr.pem
  - TLS/udr.key
  type: "Opaque"
generatorOptions:
  disableNameSuffixHash: true

# declare ConfigMap from a ConfigMapGenerator
configMapGenerator:
- name: free5gc-udr-$mcc-$mnc-config
  namespace: free5gc
  files:
    - config/udrcfg.yaml
EOF

cat <<EOF > $mcc-$mnc/udr/base/udr-sa.yaml
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: free5gc-udr-$mcc-$mnc-sa
EOF

cat <<EOF > $mcc-$mnc/udr/base/udr-rbac.yaml
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: free5gc-udr-$mcc-$mnc-rbac
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: free5gc-udr-$mcc-$mnc-sa
EOF

cat <<EOF > $mcc-$mnc/udr/base/udr-service.yaml
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: free5gc-udr-$mcc-$mnc
  name: free5gc-udr-$mcc-$mnc
spec:
  type: ClusterIP
  ports:
  - name: free5gc-udr
    port: 8000
    protocol: TCP
    targetPort: 8000
  selector:
    app: free5gc-udr-$mcc-$mnc
EOF

cat <<EOF > $mcc-$mnc/udr/base/udr-deployment.yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: free5gc-udr-$mcc-$mnc
  labels:
    app: free5gc-udr-$mcc-$mnc
spec:
  replicas: 1
  selector:
    matchLabels:
      app: free5gc-udr-$mcc-$mnc
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: free5gc-udr-$mcc-$mnc
        nsi: "$nsi"
        mcc: "$mcc"
        mnc: "$mnc"
        telecom: $abb
    spec:
      securityContext:
        runAsUser: 0
        runAsGroup: 0
      containers:
        - name: free5gc-udr
          image: black842679513/free5gc-udr:v3.0.5
          imagePullPolicy: IfNotPresent
          # imagePullPolicy: Always
          securityContext:
            privileged: false
          volumeMounts:
            - name: free5gc-udr-$mcc-$mnc-config
              mountPath: /free5gc/config
            - name: free5gc-udr-$mcc-$mnc-cert
              mountPath: /free5gc/support/TLS
          ports:
            - containerPort: 8000
              name: free5gc-udr
              protocol: TCP
        - name: tcpdump
          image: corfr/tcpdump
          command:
            - /bin/sleep
            - infinity
      dnsPolicy: ClusterFirst
      restartPolicy: Always
      schedulerName: default-scheduler
      serviceAccountName: free5gc-udr-$mcc-$mnc-sa
      terminationGracePeriodSeconds: 30
      volumes:
        - name: free5gc-udr-$mcc-$mnc-cert
          secret:
            secretName: free5gc-udr-$mcc-$mnc-tls-secret
        - name: free5gc-udr-$mcc-$mnc-config
          configMap:
            name: free5gc-udr-$mcc-$mnc-config
EOF

#
# create gNB custom resource
#

mkdir -p $mcc-$mnc/UERANSIM-gnb/base/custom-resource

cat <<EOF > $mcc-$mnc/UERANSIM-gnb/base/custom-resource/gnb-cr.yaml
---
apiVersion: "nso.free5gc.com/v1"
kind: gNB
metadata:
  name: "$mcc-$mnc-$default_gnb_id"
spec:
  mcc: "$mcc"
  mnc: "$mnc"
  ue-nums: 0
  n3_cidr: "10.$gnb_n3_ip_b.100.0/24"
  external_ip: "$gnb_ip"
EOF

#
# create default gNB
#

mkdir -p $mcc-$mnc/UERANSIM-gnb/base/config
mkdir -p $mcc-$mnc/UERANSIM-gnb/base/network-attachment-definition
mkdir -p $mcc-$mnc/UERANSIM-gnb/base/subnet

cat <<EOF > $mcc-$mnc/UERANSIM-gnb/base/config/free5gc-gnb-$mcc-$mnc-$default_gnb_id.yaml
---
apiVersion: v1
kind: ConfigMap
metadata:
  creationTimestamp: null
  name: free5gc-ueransim-gnb-$mcc-$mnc-$default_gnb_id-config
  namespace: free5gc
data:
  free5gc-gnb.yaml: |+
    mcc: '$mcc'          # Mobile Country Code value
    mnc: '$mnc'           # Mobile Network Code value (2 or 3 digits)

    nci: '$default_gnb_id'  # NR Cell Identity (36-bit)
    idLength: 32        # NR gNB ID length in bits [22...32]
    tac: 1              # Tracking Area Code

    linkIp: $gnb_ip   # gNB's local IP address for Radio Link Simulation (Usually same with local IP)
    ngapIp: $gnb_ip   # gNB's local IP address for N2 Interface (Usually same with local IP)
    gtpIp: 10.$gnb_n3_ip_b.100.3    # gNB's local IP address for N3 Interface (Usually same with local IP)

    # List of AMF address information
    amfConfigs:
      - address: $amf_ip
        port: 38412

    # List of supported S-NSSAIs by this gNB
    slices:
      - sst: 0x1
        sd: 0x${core_network_id}0203
      - sst: 0x1
        sd: 0x${core_network_id}0204
      - sst: 0x1
        sd: 0x${core_network_id}0205

    # Indicates whether or not SCTP stream number errors should be ignored.
    ignoreStreamIds: true
EOF

cat <<EOF > $mcc-$mnc/UERANSIM-gnb/base/network-attachment-definition/free5gc-n3-$mcc-$mnc-$default_gnb_id.yaml
---
apiVersion: "k8s.cni.cncf.io/v1"
kind: NetworkAttachmentDefinition
metadata:
  name: free5gc-n3-$mcc-$mnc-$default_gnb_id
  namespace: free5gc
spec:
  config: '{
      "cniVersion": "0.3.1",
      "type": "kube-ovn",
      "server_socket": "/run/openvswitch/kube-ovn-daemon.sock",
      "provider": "free5gc-n3-$mcc-$mnc-$default_gnb_id.free5gc.ovn"
    }'
EOF

cat <<EOF > $mcc-$mnc/UERANSIM-gnb/base/subnet/free5gc-n3-$mcc-$mnc-$default_gnb_id.yaml
---
apiVersion: kubeovn.io/v1
kind: Subnet
metadata:
  name: free5gc-n3-$mcc-$mnc-$default_gnb_id
  namespace: free5gc
  labels:
    nsi: "$nsi"        # Network Slice Instance of three networks (RAN,TN,CN)
    mcc: "$mcc"
    mnc: "$mnc"
    nci: "$default_gnb_id"
    telecom: $abb
spec:
  protocol: IPv4
  cidrBlock: 10.$gnb_n3_ip_b.100.0/24
  gateway: 10.$gnb_n3_ip_b.100.1
EOF

cat <<EOF > $mcc-$mnc/UERANSIM-gnb/base/kustomization.yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: free5gc
resources:
  - custom-resource/gnb-cr.yaml
  - network-attachment-definition/free5gc-n3-$mcc-$mnc-$default_gnb_id.yaml
  - subnet/free5gc-n3-$mcc-$mnc-$default_gnb_id.yaml
  - ueransim-gnb-sa.yaml
  - ueransim-gnb-rbac.yaml
  - ueransim-gnb-service.yaml
  - ueransim-gnb-deployment.yaml
  - config/free5gc-gnb-$mcc-$mnc-$default_gnb_id.yaml
EOF

cat <<EOF > $mcc-$mnc/UERANSIM-gnb/base/ueransim-gnb-sa.yaml
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: free5gc-ueransim-gnb-$mcc-$mnc-$default_gnb_id-sa
EOF

cat <<EOF > $mcc-$mnc/UERANSIM-gnb/base/ueransim-gnb-rbac.yaml
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: free5gc-ueransim-gnb-$mcc-$mnc-$default_gnb_id-rbac
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: free5gc-ueransim-gnb-$mcc-$mnc-$default_gnb_id-sa
EOF

cat <<EOF > $mcc-$mnc/UERANSIM-gnb/base/ueransim-gnb-service.yaml
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: free5gc-ueransim-gnb-$mcc-$mnc-$default_gnb_id
  name: free5gc-ueransim-gnb-$mcc-$mnc-$default_gnb_id
spec:
  type: ClusterIP
  ports:
  - name: free5gc-gnb-n3
    port: 2152
    protocol: UDP
    targetPort: 2152
  selector:
    app: free5gc-ueransim-gnb-$mcc-$mnc-$default_gnb_id
EOF

cat <<EOF > $mcc-$mnc/UERANSIM-gnb/base/ueransim-gnb-deployment.yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: free5gc-ueransim-gnb-$mcc-$mnc-$default_gnb_id
  labels:
    app: free5gc-ueransim-gnb-$mcc-$mnc-$default_gnb_id
    nsi: "$nsi"
    mcc: "$mcc"
    mnc: "$mnc"
    nci: "$default_gnb_id"
    telecom: $abb
spec:
  replicas: 1
  selector:
    matchLabels:
      app: free5gc-ueransim-gnb-$mcc-$mnc-$default_gnb_id
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: free5gc-ueransim-gnb-$mcc-$mnc-$default_gnb_id
        nsi: "$nsi"
        mcc: "$mcc"
        mnc: "$mnc"
        nci: "$default_gnb_id"
        telecom: $abb
      annotations:
        k8s.v1.cni.cncf.io/networks: free5gc-macvlan, free5gc-n3-$mcc-$mnc-$default_gnb_id
        free5gc-macvlan.free5gc.kubernetes.io/ip_address: $gnb_ip
        free5gc-n3-$mcc-$mnc-$default_gnb_id.free5gc.ovn.kubernetes.io/logical_switch: free5gc-n3-$mcc-$mnc-$default_gnb_id
        free5gc-n3-$mcc-$mnc-$default_gnb_id.free5gc.ovn.kubernetes.io/ip_address: 10.$gnb_n3_ip_b.100.3
    spec:
      securityContext:
        runAsUser: 0
        runAsGroup: 0
      containers:
        - name: free5gc-ueransim-gnb
          image: black842679513/free5gc-ueransim:v3.1.5
          imagePullPolicy: IfNotPresent
          # imagePullPolicy: Always
          command:
            - /bin/bash
            - -c
            - build/nr-gnb -c config/free5gc-gnb.yaml
          tty: true
          securityContext:
            # allow container to access the host's resources
            privileged: true
            capabilities:
              add: ["NET_ADMIN", "SYS_TIME"]
          volumeMounts:
            - name: free5gc-ueransim-gnb-$mcc-$mnc-$default_gnb_id-config
              mountPath: /UERANSIM/config
              # read host linux tun/tap packets
          #  - name: tun-dev-dir  
          #    mountPath: /dev/net/tun
          ports:
            - containerPort: 4997
              name: if-n1n2
              protocol: UDP
            - containerPort: 2152
              name: free5gc-gnb-n3
              protocol: UDP
        - name: tcpdump
          image: corfr/tcpdump
          command:
            - /bin/sleep
            - infinity
      dnsPolicy: ClusterFirst
      restartPolicy: Always
      schedulerName: default-scheduler
      serviceAccountName: free5gc-ueransim-gnb-$mcc-$mnc-$default_gnb_id-sa
      terminationGracePeriodSeconds: 30
      volumes:
        - name: free5gc-ueransim-gnb-$mcc-$mnc-$default_gnb_id-config
          configMap:
            name: free5gc-ueransim-gnb-$mcc-$mnc-$default_gnb_id-config
        #- name: tun-dev-dir
        #  hostPath:
        #    path: /dev/net/tun
EOF