#!/bin/bash

CURRENT_BRANCH=$1
CURRENT_SPRINT=$(echo "${CURRENT_BRANCH}" | grep -oP '(S20.{2}-.{2})')

#echo "BRANCH=${CURRENT_BRANCH}, SPRINT=${CURRENT_SPRINT}"
#git fetch --all > /dev/null 2>&1

git switch "deploy/${CURRENT_SPRINT}" > /dev/null
MERGED_BRANCHES=$(git log --merges --oneline | grep "Merge branch 'S2021-06/" | grep -oP "(S2021-06[^']+)")

#CURRENT_SPRINT_BRANCHES=$(git branch -r | grep "${CURRENT_SPRINT}/" | cut -c '10-')

for i in ${MERGED_BRANCHES}; do
	MERGE_RESULT=$(git merge --no-commit ${i});
	if [[ "${MERGE_ERROR}" == *"fatal: merge program failed"* ]]; then
		echo ${i};
		git merge --abort > /dev/null
	fi
done
