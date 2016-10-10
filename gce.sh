#!/bin/sh

KUBE_ENV=$(curl --fail --silent http://metadata.google.internal/computeMetadata/v1/instance/attributes/kube-env -H "Metadata-Flavor: Google")

function parse_subnet {
    local full_net=$1
    local cidr=`echo ${full_net} | cut -d'/' -f2`
    cidr=`convert_cidr ${cidr}`
    echo "${cidr}"
    }

function convert_cidr {
    local i netmask=""
    local cidr=$1
    local abs=$(($cidr/8))
    for ((i=0;i<4;i+=1)); do
    if [ $i -lt $abs ]; then
    netmask+="255"
    elif [ $i -eq $abs ]; then
    netmask+=$((256 - 2**(8-$(($cidr%8)))))
    else
    netmask+=0
    fi
    test $i -lt 3 && netmask+="."
    done
    echo $netmask
    }

SERVICE_CLUSTER_IP_RANGE=$(echo "${KUBE_ENV}" | shyaml get-value "SERVICE_CLUSTER_IP_RANGE")
CLUSTER_IP_RANGE=$(echo "${KUBE_ENV}" | shyaml get-value "CLUSTER_IP_RANGE")
DNS_SERVER_IP=$(echo "${KUBE_ENV}" | shyaml get-value "DNS_SERVER_IP")
DNS_DOMAIN=$(echo "${KUBE_ENV}" | shyaml get-value "DNS_DOMAIN")

SERVICE_SUBNET=$(parse_subnet ${SERVICE_CLUSTER_IP_RANGE})
SERVICE_NETWORK=`echo ${SERVICE_CLUSTER_IP_RANGE} | cut -d'/' -f1`

CLUSTER_SUBNET=$(parse_subnet ${CLUSTER_IP_RANGE})
CLUSTER_NETWORK=`echo ${CLUSTER_IP_RANGE} | cut -d'/' -f1`
