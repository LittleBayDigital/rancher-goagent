#!/usr/bin/env bash

set -e

function log {
    echo `date` $ME - $@
}

RANCHER_METADATA=rancher-metadata.rancher.internal

function checkrancher {
    log "checking rancher network..."

    a="`ip a s dev eth0 &> /dev/null; echo $?`" 
    while  [ $a -eq 1 ];
    do
        a="`ip a s dev eth0 &> /dev/null; echo $?`" 
        sleep 1
    done

    b="`ping -c 1 ${RANCHER_METADATA} &> /dev/null; echo $?`"
    while [ $b -eq 1 ]; 
    do
        b="`ping -c 1 ${RANCHER_METADATA} &> /dev/null; echo $?`"
        sleep 1 
    done
}

function installDocker {
    DOCKER_SERVER_VERSION=$(curl http://${RANCHER_METADATA}/2015-12-19/self/host/labels/io.rancher.host.docker_version)

    DOCKER_BIN=${DOCKER_BIN:-"/usr/bin/docker"}
    log "[ Checking Docker client ${DOCKER_VERSION} ... ]"

    if [ ! -e ${DOCKER_BIN} ]; then
        log "[ Installing Docker client ${DOCKER_VERSION} ... ]"

        case "$DOCKER_SERVER_VERSION" in
            "1.9")
                DOCKER_VERSION="1.9.1"
                DOCKER_EXTRACT_FILE="usr/local/bin/docker"
            ;;
            "1.10")
                DOCKER_VERSION="1.10.3"
                DOCKER_EXTRACT_FILE="usr/local/bin/docker"
            ;;
            "1.11")
                DOCKER_VERSION="1.11.2"
            ;;
            "1.12") 
                DOCKER_VERSION="1.12.0"
            ;;
        esac
        
        DOCKER_EXTRACT_FILE=${DOCKER_EXTRACT_FILE:-"docker/docker"}

        cd /tmp
        curl -Ss https://get.docker.com/builds/Linux/x86_64/docker-${DOCKER_VERSION}.tgz  | tar zxvf - ${DOCKER_EXTRACT_FILE} 
        if [ $? -eq 0 ]; then 
            chmod 755 /tmp/${DOCKER_EXTRACT_FILE}
            mv /tmp/${DOCKER_EXTRACT_FILE} ${DOCKER_BIN}
        else
            log "[ ERROR ]"
            exit 1
        fi
    fi
}

function savesshkey {
    log "saving SSH key"

    if [ ! -e "${USER_HOME}/.ssh" ]; then
        mkdir ${USER_HOME}/.ssh
    fi

    printf "$SSH_KEY" > ${USER_HOME}/.ssh/id_rsa
    chmod 600 ${USER_HOME}/.ssh/id_rsa
}

function disableAuthorizedKey {
    log "disabling Authorized Key"
    sed -ie "s/#PubkeyAuthentication yes/PubkeyAuthentication no/" /etc/ssh/sshd_config
}

checkrancher
installDocker
savesshkey
disableAuthorizedKey

echo `hostname` > /opt/go-agent/config/guid.txt

log "[ Starting gocd agent... ]"
exec /opt/go-agent/agent.sh

exec "$@"
