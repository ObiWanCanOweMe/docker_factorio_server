#!/bin/sh

# Check for already running instance of same script
if ps ax | grep $0 | grep -v $$ | grep bash | grep -v grep
then
  echo "The script is already running."
  exit 1
fi

# Values for $API_USER, $API_TOKEN, $BUILD_TOKEN
source /home/akener/.jenkins_auth

REPO_HOME="/home/akener/repo/docker_factorio_server/"
DOCKERFILE="$REPO_HOME/Dockerfile"
DOCKER_README="$REPO_HOME/README.md"
CURRENT_VERSION=`curl -s https://raw.githubusercontent.com/ObiWanCanOweMe/docker_factorio_server/0.16/Dockerfile | grep VERSION= | awk '{print $1}' | grep -Eo '(0(.*))'`
CURRENT_SHA1=`curl -s https://raw.githubusercontent.com/ObiWanCanOweMe/docker_factorio_server/0.16/Dockerfile | grep SHA1= | awk '{print $1}' | grep -Eo '(=\s*(.*))' | cut -c 2-`
LATEST_VERSION=`curl -s https://factorio.com/ | grep Experimental | awk '{print $2}'`
LATEST_MAJOR="0"
LATEST_MINOR=`echo $LATEST_VERSION | cut -c 3- | rev | cut -c 4- | rev`
LATEST_PATCH=`echo $LATEST_VERSION | cut -c 6-`

# Make sure we have the latest code before making changes to local copy of repo
cd $REPO_HOME
git pull
git fetch --tags

if [ $LATEST_VERSION != $CURRENT_VERSION ]; then
  echo "The repo version is $CURRENT_VERSION and the latest release is $LATEST_VERSION"
  curl -sSL https://www.factorio.com/get-download/$LATEST_VERSION/headless/linux64 -o /tmp/factorio_headless_x64_$LATEST_VERSION.tar.xz
  LATEST_SHA1=`sha1sum /tmp/factorio_headless_x64_$LATEST_VERSION.tar.xz | awk '{print $1}'`
  rm -f /tmp/factorio_headless_x64_$LATEST_VERSION.tar.xz
  sed -i "s/$CURRENT_VERSION/$LATEST_VERSION/g" $DOCKERFILE
  sed -i "s/$CURRENT_SHA1/$LATEST_SHA1/g" $DOCKERFILE
  sed -i "s/$CURRENT_VERSION/$LATEST_VERSION/g" $DOCKER_README

  # Git manipulation
  cd $REPO_HOME
  git add $DOCKERFILE $DOCKER_README
  git commit -m "update to $LATEST_VERSION"
  git tag -fa $LATEST_VERSION -m "$LATEST_VERSION"
  git push --tags origin master

  # Kick off Jenkins job to build new image and push to Docker Hub
  curl -sSL https://$API_USER:$API_TOKEN@jenkins.kener.org/job/docker_factorio_server_0.16/build?token=$BUILD_TOKEN
fi
