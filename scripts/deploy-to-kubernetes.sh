#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DEPLOYMENT_TEMPLATES="$DIR/../templates/deployments"
SERVICE_TEMPLATES="$DIR/../templates/services"
POLICY_TEMPLATES="$DIR/../templates/policies"
package="deploy-to-kubernetes.sh"
DEBUG=0
NAMESPACE=default
KUBECTL="kubectl"

usage() {
    echo "$package - build the project"
    echo " "
    echo "$package [options]"
    echo " "
    echo "options:"
    echo "-h, --help                      show brief help"
    echo "-n, --namespace=namespace       namespace to deploy to with kubectl - defaults to default"
    echo "-c, --environment=env           the config file to use.  When ommitted will use config.env, otherwise config.env.[environment]"
    echo "-d, --dry-run                     if set, dont apply config to kubernetes - just output what it would do"
    echo
}

ENVIRONMENT=
NAMESPACE=default

while test $# -gt 0; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        -n)
            shift
            if test $# -gt 0; then
                NAMESPACE=$1
            fi
            shift
            ;;
        --namespace*)
            NAMESPACE=$(echo $1 | sed -e 's/^[^=]*=//g')
            shift
            ;;
        -e)
            shift
            if test $# -gt 0; then
                ENVIRONMENT=$1
            fi
            shift
            ;;
        --environment*)
            ENVIRONMENT=$(echo $1 | sed -e 's/^[^=]*=//g')
            shift
            ;;
        -d)
            shift
            DEBUG=1
            ;;
        --dry-run)
            shift
            DEBUG=1
            ;;
        *)
            echo "Your making up option!"
            echo
            usage
            exit 1
            break
            ;;
    esac
done

KUBECTL="$KUBECTL --namespace=$NAMESPACE"

if [ -z $ENVIRONMENT ]; then
    CONFIG_FILE=$DIR/../config.env
else
    CONFIG_FILE=$DIR/../config.env.$ENVIRONMENT
fi

if [ ! -f "$CONFIG_FILE" ]; then
    echo "No config file has been set.  Try copying $CONFIG_FILE.example to $CONFIG_FILE, edit setting and try again"
    exit 1
else
    echo "Sourcing the $CONFIG_FILE"
    . $CONFIG_FILE
fi

echo "Running deployment of an elasticsearch cluster with CLUSTER_NAME=$CLUSTER_NAME"

build_deploy_masters() {
    TPL=$DEPLOYMENT_TEMPLATES/es-master.yaml
    SED_PATTERN="s%{MASTER_CPU_COUNT}%${MASTER_CPU_COUNT}%g;s%{MASTER_MEMORY_COUNT}%${MASTER_MEMORY_COUNT}%g;s%{ELASTICSEARCH_DISCOVERY_SERVICE}%${ELASTICSEARCH_DISCOVERY_SERVICE}%g;s%{ES_MASTER_HEAP}%$ES_MASTER_HEAP%g;s%{TRANSPORT_TCP_PORT}%$TRANSPORT_TCP_PORT%g;s%{MASTER_NODE_COUNT}%$MASTER_NODE_COUNT%g;s%{ES_MASTER_IMAGE}%$ES_MASTER_IMAGE%g;s%{CLUSTER_NAME}%$CLUSTER_NAME%g;s%{MASTER_MIN_COUNT}%$MASTER_MIN_COUNT%g;"

    echo "Deploying es-master image..."
    if [ $DEBUG -eq 1 ]; then
        sed $SED_PATTERN $TPL
    else
        sed $SED_PATTERN $TPL | $KUBECTL apply -f -
    fi
}

build_deploy_data() {
    if [ "$DATA_STATEFUL" == true ]; then
        echo "Deploying es-data stateful image"
        TPL=$DEPLOYMENT_TEMPLATES/es-data-statefulset.yaml
    else
        echo "Deploying es-data image"
        TPL=$DEPLOYMENT_TEMPLATES/es-data.yaml
    fi

    SED_PATTERN="s%{DATA_NODE_COUNT}%$DATA_NODE_COUNT%g;s%{ES_DATA_IMAGE}%$ES_DATA_IMAGE%g;s%{CLUSTER_NAME}%$CLUSTER_NAME%g;s%{MASTER_MIN_COUNT}%$MASTER_MIN_COUNT%g;s%{ELASTICSEARCH_DISCOVERY_SERVICE}%$ELASTICSEARCH_DISCOVERY_SERVICE%g;s%{ES_DATA_HEAP}%$ES_DATA_HEAP%g;s%{DATA_MEMORY}%$DATA_MEMORY%g;s%{DATA_CPU_COUNT}%$DATA_CPU_COUNT%g;s%{TRANSPORT_TCP_PORT}%$TRANSPORT_TCP_PORT%g;s%{DATA_NODE_PATH}%$DATA_NODE_PATH%g;s%{DATA_STORAGE_SIZE}%$DATA_STORAGE_SIZE%g;"

    if [ $DEBUG -eq 1 ]; then
        sed $SED_PATTERN $TPL
    else
        sed $SED_PATTERN $TPL | $KUBECTL apply -f -
    fi
}

build_deploy_kibana() {
    echo "Building deployment for kibana"
    TPL=$DEPLOYMENT_TEMPLATES/kibana.yaml
}

build_deploy_proxy() {
    echo "Building the deployment for the external proxy..."
}

build_deploy_masters
build_deploy_data
