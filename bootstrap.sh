#!/bin/bash

PROJECT_NAME='rb-jenkins'

function log {
  printf "\n\n*** $1\n\n"
}

function build_jenkins_image {
  docker build -t quay.io/elostech/rb-jenkins:latest jenkins/
}

function push_jenkins_image {
  docker push quay.io/elostech/rb-jenkins:latest
}

function create_project {
  log "Creating project $PROJECT_NAME"

  oc new-project $PROJECT_NAME
}

function deploy_jenkins {
  log "Deploying jenkins"

  #oc new-app \
  #  -e OPENSHIFT_ENABLE_OAUTH=false \
  #  -e VOLUME_CAPACITY=10Gi \
  #  jenkins-ephemeral

  oc new-app \
    --name jenkins \
    --template jenkins-persistent
    #-f jenkins/jenkins-template-persistent.yaml
    #-f jenkins/jenkins-template.yaml
    #--docker-image=openshift/jenkins-2-centos7

  #oc expose svc jenkins

  # INFO: Completed initialization

  for i in $(seq 1 100); do
    oc get pod --no-headers=true | grep -v deploy | grep '1/1' && break
    echo "Waiting till jenkins pod is ready.."
    sleep 10
  done
}

function install_plugins {
  POD_NAME=$(oc get pod --no-headers=true | grep -v deploy | awk '{ print $1 }')

  oc exec $POD_NAME -- curl -L https://raw.githubusercontent.com/hgomez/devops-incubator/master/forge-tricks/batch-install-jenkins-plugins.sh -o /tmp/batch-install-jenkins-plugins.sh

  oc exec $POD_NAME -- chmod +x /tmp/batch-install-jenkins-plugins.sh

  oc exec $POD_NAME -- sed -i 's@updates.jenkins-ci.org/stable@updates.jenkins.io@' /tmp/batch-install-jenkins-plugins.sh

  oc exec $POD_NAME -- /tmp/batch-install-jenkins-plugins.sh --plugins /tmp/plugins.txt --plugindir /var/lib/jenkins/plugins/

}

function deploy_redis {
  log "Deploying redis"

  helm repo add bitnami https://charts.bitnami.com/bitnami
  helm install rb-redis \
    --namespace $PROJECT_NAME \
    -f redis/values.yaml \
    redis/
}

function cleanup {
  log "Cleanup..."

  helm uninstall rb-redis

  oc delete project $PROJECT_NAME

  for i in $(seq 1 10); do
    oc get project $PROJECT_NAME &>/dev/null || break
    echo "Waiting for project termination.."
    sleep 5
  done
}

#build_jenkins_image
#push_jenkins_image

#sleep 10

#cleanup
#create_project
#deploy_jenkins
#install_plugins

deploy_redis
