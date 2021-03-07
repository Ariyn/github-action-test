#!/bin/bash

# this script returns -1 when error occurred,
# returns -2 when merge conflict occurred

function create_branch() {
	local branch_name=$1
	local base_branch=$2

	if [[ -z "${base_branch}" ]]; then
		base_branch="master";
	fi

	switch_error=$(git switch ${base_branch} 2>&1 >/dev/null);
	if [[ ! -z "${switch_error}" ]]; then
		echo "ERR;can't switch to base branch ${base_branch} due to ${switch_error}";
	fi

	create_branch_error=$(git branch ${branch_name} 2>&1 >/dev/null);
	if [[ ! -z "${create_branch_error}" ]]; then
		echo "ERR;can't create branch ${branch_name} due to ${create_branch_error}";
	fi
}


function find_suspicious_branches() {
	local current_sprint=$1
	local conflict_branch=$2

	local branches=$(git branch | grep "${current_sprint}" | grep -v "*" | grep -v "deploy/")
	
	git switch "${conflict_branch}" >/dev/null 2>&1

	for i in $branches; do
		if [ $i != $conflict_branch ]; then
			local merge_error=$(git merge --no-commit --no-ff $i 2>/dev/null);

			if [ ! -z "$merge_error" ] && [[ "$merge_error" == *"CONFLICT"* ]]; then
				echo "merge conflict between $conflict_branch and $i";
				git merge --abort
			fi
		fi
	done
}

#find_suspicious_branches "S2021-06" "S2021-06/conflict_b"
#exit 0

NEW_BRANCH=$1

if [ "$NEW_BRANCH" == "master" ]; then
	exit 0;
fi

if [ -z "$NEW_BRANCH" ]; then
	NEW_BRANCH="S2021-05/test";
fi

git fetch --all
git checkout -b "${NEW_BRANCH}" "origin/${NEW_BRANCH}"
git switch master

LATEST_SPRINT=$(git branch -r | grep S20 | cut -c '10-' | grep -v 'deploy' | sort | tail -1 | grep -oP '(S20.{2}-.{2})')

echo "LATEST_SPRINT IS ${LATEST_SPRINT}"

LATEST_SPRINT_TAG=$(git tag | grep S20 | sort | tail -1)

echo "LATEST_REPEASE IS ${LATEST_SPRINT_TAG}"

GIT_STATUS=$(git status)
if [[ "${GIT_STATUS}" == *"You have unmerged paths."* ]]; then
	echo "repository is DURING MERGE"
	echo "stop build"
	exit -2
elif [[ "${GIT_STATUS}" != *"nothing to commit, working tree clean"* ]]; then
	echo "repository is NOT CLEAN"
	echo "stop build"
	exit -3
fi

if [[ $LATEST_SPRINT_TAG -ne $LATEST_SPRINT ]]; then
	DEPLOY_BRANCH_KEY="deploy/${LATEST_SPRINT}"
	EXISTS_DEPLOY_BRANCH=$(git branch -l | grep $DEPLOY_BRANCH_KEY | cut -c '3-')
	REMOTE_EXISTS_DEPLOY_BRANCH=$(git branch -r | grep $DEPLOY_BRANCH_KEY | cut -c '10-')

	echo $(git branch -l)

	echo $DEPLOY_BRANCH_KEY;
	echo $EXISTS_DEPLOY_BRANCH;
	echo $REMOTE_EXISTS_DEPLOY_BRANCH;
	
	if [ -z "$EXISTS_DEPLOY_BRANCH" ] && [ -z "$REMOTE_EXISTS_DEPLOY_BRANCH" ]; then
		echo "deploy branch ${DEPLOY_BRANCH_KEY} not exists"
		echo "create new branch"
		
		RESULT=$(create_branch "${DEPLOY_BRANCH_KEY}" "master")
		if [ "${RESULT}" == "ERR;"* ]; then
			echo "occurred error during create branch"
			echo "${RESULT}"
			exit -1
		fi
	elif [ -z "$EXISTS_DEPLOY_BRANCH" ] && [ ! -z "$REMOTE_EXISTS_DEPLOY_BRANCH" ]; then
		git checkout -b "$DEPLOY_BRANCH_KEY" "origin/${DEPLOY_BRANCH_KEY}"
	fi

	
	git switch "${DEPLOY_BRANCH_KEY}" >/dev/null 2>&1
	MERGE_ERROR=$(git merge $NEW_BRANCH 2>&1);
	
	if [ ! -z "${MERGE_ERROR}" ] && ([ "$MERGE_ERROR" != "Already up to date." ] && [[ "${MERGE_ERROR}" != *"file changed,"*"insertion(+),"*"deletion(-)"* ]]); then
		if [[ "${MERGE_ERROR}" == *"Automatic merge failed; fix conflicts and then commit the result."* ]]; then
			echo "occurred CONFLICT during merge branch ${NEW_BRANCH} into deploy branch"
			echo "aborting merge";
			git merge --abort 2>&1 >/dev/null;
			exit -2
		else
			echo "occurred ERROR during merge branch ${NEW_BRANCH} into deploy branch"
			echo "${MERGE_ERROR}"
			exit -1
		fi
	fi

	echo "merge from ${NEW_BRANCH} to ${DEPLOY_BRANCH_KEY} complete"

	git push --set-upstream origin "${DEPLOY_BRANCH_KEY}"
fi
