#!/bin/bash

if [[ -z "${SCHUTZBOT_LOGIN}" ]]; then
  echo "Required variable not found"
  exit 1
fi

# if a user is logged in to the runner, wait until they're done
while (( $(who -u | grep -c -v '?' || true) > 0 )); do
    echo "Waiting for user(s) to log off"
    sleep 30
done

if [[ $1 == "start" ]]; then
  GITHUB_NEW_STATE="pending"
  GITHUB_NEW_DESC="I'm currently testing this commit, be patient."
elif [[ $1 == "finish" ]]; then
  GITHUB_NEW_STATE="success"
  GITHUB_NEW_DESC="I like this commit!"
elif [[ $1 == "spot" ]]; then
  GITHUB_NEW_STATE="failure"
  GITHUB_NEW_DESC="Bad luck, AWS EC2 spot instance was terminated."
elif [[ $1 == "update" ]]; then
  if [[ $CI_JOB_STATUS == "canceled" ]]; then
    GITHUB_NEW_STATE="failure"
    GITHUB_NEW_DESC="Someone told me to cancel this test run."
  elif [[ $CI_JOB_STATUS == "failed" ]]; then
    GITHUB_NEW_STATE="failure"
    GITHUB_NEW_DESC="I'm sorry, something is odd about this commit."
  else
    exit 0
  fi
else
  echo "Unknown command: $1"
  exit 1
fi

CONTEXT="Schutzbot on GitLab"
if [[ -n "$2" ]]; then
    CONTEXT="$CONTEXT: $2"
fi

curl \
    -u "${SCHUTZBOT_LOGIN}" \
    -X POST \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/osbuild/bootc-foundry/statuses/${CI_COMMIT_SHA}" \
    -d '{"state":"'"${GITHUB_NEW_STATE}"'", "description": "'"${GITHUB_NEW_DESC}"'", "context": "'"${CONTEXT}"'", "target_url": "'"${CI_PIPELINE_URL}"'"}'

# ff release branch on github if this ran on main
if [ "$CI_COMMIT_BRANCH" = "main" ] && [ "$GITHUB_NEW_STATE" = "success" ]; then
    if [ ! -d "release-ff-clone" ]; then
        git clone --bare "https://${SCHUTZBOT_LOGIN#*:}@github.com/osbuild/bootc-foundry.git" release-ff-clone
    fi
    git -C release-ff-clone fetch origin
    # || true to ignore non fast-forwards
    git -C release-ff-clone push origin "${CI_COMMIT_SHA}:refs/heads/release" || true
fi
