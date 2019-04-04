#!/usr/bin/env bash
# alternative solution https://stackoverflow.com/a/38474137

# usage
HELP='github.sh [-f /path/to/setts] [-t token] [-hp]
Creates git repo in current directory and corresponding repo on github.
Then generates ssh key pair for it and adds public key as a deploy key for
resulting github repo. Git remote github is added.
Use `git push -u github master` after adding some commits
Ssh keys are added to your ~/.ssh/ directory and a github subdomain record is
added into ssh config for this repository.
You should have settings file github-init.ini in your home directory or
provide path to it if it resides elsewhere. This file should contain user and
API token for your github account in the shell format like this:

USER="Fess-AKA-DeadMonk"
TOKEN="asdasd234234"

API key should have permissions:
  admin:public_key, read:user, repo
Requires git (obviously), ssh-keygen and curl in order to work

-f path/to/settings file described above
-t use to provide token directly
-h print this help
-p create public repo. repo is created private by default
'

GITHUB_SETTS=~/.github-init.ini
. "$GITHUB_SETTS"
PRIVATE=true

while getopts f:t:hp option; do
  case "${option}"
  in
    t) TOKEN=${OPTARG};;
    p) PRIVATE=false;;
    f)
      GITHUB_SETTS=${OPTARG}
      . "$GITHUB_SETTS"
    ;;
    h)
      echo "$HELP"
      exit
    ;;
  esac
done

# TODO: add some checks!!!

cur_dir=$(pwd)
repo_name=${cur_dir##*/}


key_name="$(whoami)@$(hostname) $(date '+%Y-%M-%d')"

# generate ssh key for github authorization
# 1026  ssh-keygen
ssh_key="gh_$repo_name"
ssh-keygen -qf "$ssh_key" -N '' -C "$key_name"
if [[ ! -d ~/.ssh ]]; then
  mkdir ~/.ssh
  chmod 0400 ~/.ssh
fi

# create repo and add key into it
# create repo
# https://developer.github.com/v3/repos/#create
post_file=`mktemp`
cat << POST > $post_file
{
  "name": "$repo_name",
  "description": "This is repository",
  "private": $PRIVATE
}
POST

curl -X POST --data-binary "@$post_file" --include \
  -H "Accept: application/json" -H "Content-Type: application/json; charset=UTF-8" \
  -H "Authorization: token $TOKEN" \
     "https://api.github.com/user/repos"

# deploy key
# https://developer.github.com/v3/repos/keys/#add-a-new-deploy-key
pub_key_contents="$(cat "$ssh_key.pub")"
cat << POST > $post_file
{
  "title": "$key_name",
  "key": "$pub_key_contents"
}
POST

curl -X POST --data-binary "@$post_file" --include \
  -H "Accept: application/json" -H "Content-Type: application/json; charset=UTF-8" \
  -H "Authorization: token $TOKEN" \
     "https://api.github.com/repos/$USER/$repo_name/keys"

rm $post_file

# ssh_key:             ${ssh_key}.pub
mv "$ssh_key"* ~/.ssh/

# add origin
# 1029  git remote add github git@python3_pg.github.com:Fess-AKA-DeadMonk/python3_pg.git
git init
git remote add github git@${repo_name}.github.com:${USER}/${repo_name}.git

# add subdomain section to the ssh config
# 1032  mcedit ~/.ssh/config
cat << EOF >> ~/.ssh/config

# `date`
host ${repo_name}.github.com
 HostName github.com
 IdentityFile ~/.ssh/${ssh_key}
 User git
EOF
