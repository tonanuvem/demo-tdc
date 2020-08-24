#!/usr/bin/env bash

########################
# include the magic
########################
. ./demo-magic.sh


########################
# Configure the options
########################

#
# speed at which to simulate typing. bigger num = faster
#
# TYPE_SPEED=20

#
# custom prompt
#
# see http://www.tldp.org/HOWTO/Bash-Prompt-HOWTO/bash-prompt-escape-sequences.html for escape sequences
#
# DEMO_PROMPT="\r${RED}[\H] ${GREEN}(local) ${CYAN}root@192.168.0.18 ${PURPLE}\w ${WHITE}$ "
DEMO_PROMPT="\r${WHITE}$ "

# hide the evidence
clear

#	Definir as variáveis de ambiente:
gcloud config set project temporal-bebop-225715
REGION=us-central1
ZONE=${REGION}-b
PROJECT=$(gcloud config get-value project)
CLUSTER=gke-tdc-sampa
#CLUSTER_VERSION=1.17.8-gke.17

# Criar um cluster de dois nós:
#pe "gcloud container clusters create ${CLUSTER} --num-nodes=3 --zone ${ZONE} --cluster-version=latest"

# Criar um cluster de cinco nós:
pe "gcloud container clusters create ${CLUSTER} --cluster-version=latest --machine-type=n1-standard-2 --num-nodes=5 --zone ${ZONE}"
#gcloud beta container clusters create ${CLUSTER} \
#    --cluster-version=latest \
##    --cluster-version=${CLUSTER_VERSION} \
##    --addons=Istio --istio-config=auth=MTLS_STRICT \
#    --machine-type=n1-standard-2 \
#    --num-nodes=5 --zone ${ZONE}

# Verificar as 2 instâncias e os pods do namespace kube-system:
#p ""
gcloud container clusters get-credentials $CLUSTER --zone $ZONE
#pe "kubectl get pods -n kube-system"
#pe "gcloud container clusters list"
#pe "gcloud compute instances list"


# Istio service mesh
#curl -L https://istio.io/downloadIstio | sh - 
#cd istio-1.7.0 && export PATH=$PWD/bin:$PATH
p " ### vamos instalar ISTIO service mesh"
../istio-1.7.0/bin/istioctl install --set profile=demo
kubectl label namespace default istio-injection=enabled
kubectl label namespace kube-node-lease istio-injection=enabled
../istio-1.7.0/bin/istioctl analyze
#pe "kubectl get deploy -n istio-system"
#pe "kubectl get rs -n istio-system"
#pe "kubectl get pod -n istio-system"
#pe "kubectl get service -n istio-system"
#p "### aumentar resiliencia do ISTIO service mesh"
#pe "kubectl scale -n istio-system --replicas=2 deployment/istiod"
#pe "kubectl get pods -n istio-system | grep istiod"

#p " ### habilitar modulo KIALI do ISTIO service mesh"
kubectl apply -f ../istio-1.7.0/samples/addons | grep created
while ! kubectl wait --for=condition=available --timeout=600s deployment/kiali -n istio-system; do sleep 1; done

# Istio Ingress gateway (istio-ingressgateway
# https://istio.io/docs/tasks/traffic-management/
# https://istio.io/latest/docs/tasks/observability/gateways/
export INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
export INGRESS_DOMAIN=${INGRESS_HOST}.nip.io
echo $INGRESS_DOMAIN
sed -i 's|DOMINIO|'$INGRESS_DOMAIN'|' istio/ingress_observabilidade.yaml

#p " ### vamos habilitar a observabilidade do nosso service mesh"
kubectl apply -f istio/ingress_observabilidade.yaml

# Executar a aplicação Sock Shop : A Microservice Demo Application
p " ### vamos Executar a aplicação Sock Shop (Microservice Demo Application):"
kubectl create ns sock-shop
kubectl label namespace sock-shop istio-injection=enabled
pe "kubectl create -f svc/demo-weaveworks-socks.yaml"
sed -i 's|DOMINIO|'$INGRESS_DOMAIN'|' istio/ingress_shop.yaml
kubectl apply -f istio/ingress_shop.yaml
../istio-1.7.0/bin/istioctl analyze --all-namespaces
#pe "kubectl get svc -n sock-shop"
#kubectl get all -n sock-shop
kubectl get pod -n istio-system

p " ### vamos verificar o IP Externo (API Gateway/Ingress):"
kubectl get svc istio-ingressgateway -n istio-system
#pe "kubectl get svc"
#p ""
#pe "kubectl get svc -n sock-shop | grep front-end"
#p ""

# Kiali
#pe "kubectl patch svc kiali -n istio-system -p '{'spec': {'type': 'LoadBalancer'}}' && kubectl get svc kiali -n istio-system"
p " # Visualizar o Service Mesh: http://kiali.${INGRESS_DOMAIN}"
p ""
p " # Acessar Shop no navegador: http://shop.${INGRESS_DOMAIN}"
p ""

#Kiali: http://kiali.${INGRESS_DOMAIN}
#Prometheus: http://prometheus.${INGRESS_DOMAIN}
#Grafana: http://grafana.${INGRESS_DOMAIN}
#Tracing: http://tracing.${INGRESS_DOMAIN}
#Shop: http://shop.${INGRESS_DOMAIN}

########### Excluir o cluster do GKE

p "### Excluir o cluster do GKE"
p " ### FIM ###"
pe "gcloud container clusters delete $CLUSTER --zone $ZONE"


# ---------#
