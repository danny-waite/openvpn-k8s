#!/bin/bash

if [ "$DEBUG" == "1" ]; then
  set -x
fi

set -e

# TODO check if we're running on google cloud before sourcing gce.sh
source gce.sh

MORE_OPTS="${MORE_OPTS:-}"
OVPN_NETWORK="${OVPN_NETWORK:-10.140.0.0}"
OVPN_SUBNET="${OVPN_SUBNET:-255.255.0.0}"
OVPN_PROTO="${OVPN_PROTO:-udp}"
OVPN_NATDEVICE="${OVPN_NATDEVICE:-eth0}"

OVPN_K8S_SERVICE_NETWORK=${SERVICE_NETWORK:-$OVPN_K8S_SERVICE_NETWORK}
OVPN_K8S_SERVICE_SUBNET=${SERVICE_SUBNET:-$OVPN_K8S_SERVICE_SUBNET}
OVPN_K8S_POD_NETWORK=${CLUSTER_NETWORK:-$OVPN_K8S_POD_NETWORK}
OVPN_K8S_POD_SUBNET=${CLUSTER_SUBNET:-$OVPN_K8S_POD_SUBNET}

OVPN_K8S_DOMAIN="${DNS_DOMAIN:-$OVPN_KUBE_DOMAIN}"
OVPN_K8S_DNS=${DNS_SERVER_IP:-$OVPN_K8S_DNS}

OVPN_DH="${OVPN_DH:-/etc/openvpn/pki/dh.pem}"
OVPN_CERTS="${OVPN_CERTS:-/etc/openvpn/pki/certs.p12}"

if [ -z "${OVPN_K8S_SERVICE_NETWORK}" ]; then
    echo "Service network not specified"
    exit 1
fi

if [ -z "${OVPN_K8S_SERVICE_SUBNET}" ]; then
    echo "Service subnet not specified"
    exit 1
fi

if [ -z "${OVPN_K8S_DNS}" ]; then
    echo "DNS server not specified"
    exit 1
fi

if [ ! -z "${OVPN_K8S_POD_NETWORK}" -a  ! -z "${OVPN_K8S_POD_SUBNET}" ]; then
    POD_CONF="push \"route ${OVPN_K8S_POD_NETWORK} ${OVPN_K8S_POD_SUBNET}\""
else
    POD_CONF=""
fi

sed 's|{{OVPN_NETWORK}}|'"${OVPN_NETWORK}"'|' -i "${OVPN_CONFIG}"
sed 's|{{OVPN_SUBNET}}|'"${OVPN_SUBNET}"'|' -i "${OVPN_CONFIG}"
sed 's|{{OVPN_PROTO}}|'"${OVPN_PROTO}"'|' -i "${OVPN_CONFIG}"
sed 's|{{OVPN_DH}}|'"${OVPN_DH}"'|' -i "${OVPN_CONFIG}"
sed 's|{{OVPN_CERTS}}|'"${OVPN_CERTS}"'|' -i "${OVPN_CONFIG}"
sed 's|{{OVPN_K8S_SERVICE_NETWORK}}|'"${OVPN_K8S_SERVICE_NETWORK}"'|' -i "${OVPN_CONFIG}"
sed 's|{{OVPN_K8S_SERVICE_SUBNET}}|'"${OVPN_K8S_SERVICE_SUBNET}"'|' -i "${OVPN_CONFIG}"
sed 's|{{OVPN_K8S_DOMAIN}}|'"${OVPN_K8S_DOMAIN}"'|' -i "${OVPN_CONFIG}"
sed 's|{{OVPN_K8S_DNS}}|'"${OVPN_K8S_DNS}"'|' -i "${OVPN_CONFIG}"

sed 's|{{POD_CONF}}|'"${POD_CONF}"'|' -i "${OVPN_CONFIG}"
sed 's|{{MORE_OPTS}}|'"${MORE_OPTS}"'|' -i "${OVPN_CONFIG}"

iptables -t nat -A POSTROUTING -s ${OVPN_NETWORK}/${OVPN_SUBNET} -o ${OVPN_NATDEVICE} -j MASQUERADE

mkdir -p /dev/net
if [ ! -c /dev/net/tun ]; then
    mknod /dev/net/tun c 10 200
fi

if [ "$DEBUG" == "1" ]; then
    echo ========== ${OVPN_CONFIG} ==========
    cat "${OVPN_CONFIG}"
    echo ====================================
fi

exec openvpn --config ${OVPN_CONFIG}
