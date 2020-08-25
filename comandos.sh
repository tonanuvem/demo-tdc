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

# Criar um cluster de cinco nós:
pe "gcloud container clusters create ${CLUSTER} --cluster-version=latest --machine-type=n1-standard-2 --num-nodes=5 --zone ${ZONE}"
gcloud container clusters get-credentials $CLUSTER --zone $ZONE

# Istio service mesh
#curl -L https://istio.io/downloadIstio | sh - 
#cd istio-1.7.0 && export PATH=$PWD/bin:$PATH
p " ### vamos instalar ISTIO service mesh"
../istio-1.7.0/bin/istioctl install --set profile=demo
kubectl label namespace default istio-injection=enabled
kubectl label namespace kube-node-lease istio-injection=enabled
../istio-1.7.0/bin/istioctl analyze
kubectl apply -f ../istio-1.7.0/samples/addons
while ! kubectl wait --for=condition=available --timeout=600s deployment/kiali -n istio-system; do sleep 1; done

# Istio Ingress gateway (istio-ingressgateway
external_ip=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo $external_ip
while [ -z $external_ip ]; do
    printf "."
    sleep 1
    external_ip=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
done
export INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
export INGRESS_DOMAIN=${INGRESS_HOST}.nip.io
echo $INGRESS_DOMAIN
sed -i 's|DOMINIO|'$INGRESS_DOMAIN'|' istio/ingress_observabilidade.yaml

#p " ### vamos habilitar a observabilidade do nosso service mesh"
kubectl apply -f istio/ingress_observabilidade.yaml
kubectl get pod -n istio-system

# Executar a aplicação Sock Shop : A Microservice Demo Application
p " ### vamos Executar a aplicação Sock Shop (Microservice Demo Application):"
kubectl create ns sock-shop
kubectl label namespace sock-shop istio-injection=enabled
pe "kubectl create -f svc/demo-weaveworks-socks.yaml"
sed -i 's|DOMINIO|'$INGRESS_DOMAIN'|' istio/ingress_shop.yaml
kubectl apply -f istio/ingress_shop.yaml
kubectl get all -n sock-shop

p " ### vamos verificar o IP Externo (API Gateway/Ingress):"
kubectl get svc istio-ingressgateway -n istio-system

# Kiali
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
