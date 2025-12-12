#!/bin/bash

# Clone through a deploy key if possible...
# cf. https://stackoverflow.com/a/4565746/4958081

# Set your variables
LOCAL_REPO_PATH=$(cd -- "$( dirname -- "${BASH_SOURCE}" )/.." &> /dev/null && pwd)
REPO_URL=$(git -C "$LOCAL_REPO_PATH" remote get-url origin)
BRANCH="release"
LOG_FILE="$LOCAL_REPO_PATH/auto-pull.log"

function jumpto
{
    label=$1
    cmd=$(sed -n "/$label:/{:a;n;p;ba};" $0 | grep -v ':$')
    eval "$cmd"
    exit
}

echo "$(date) : Starting check..." | tee -a "$LOG_FILE"

if [ ! -d "$LOCAL_REPO_PATH" ]; then
    echo "$(date) : Repo directory does NOT exist : $LOCAL_REPO_PATH" | tee -a "$LOG_FILE"
    jumpto end
fi

ONGOING_PULL_FILE_PATH="$LOCAL_REPO_PATH/.ongoing-pull"
if [ -f "$ONGOING_PULL_FILE_PATH" ]; then
    echo "$(date) : Ongoing pull by another process. Stopping." | tee -a "$LOG_FILE"
    jumpto end
fi
touch "$ONGOING_PULL_FILE_PATH"

# Check if the local repository exists
if [ ! -d "$LOCAL_REPO_PATH" ]; then
    git clone "$REPO_URL" "$LOCAL_REPO_PATH"
    echo "$(date) : Local repository created" | tee -a "$LOG_FILE"
fi

# Change to the local repository directory
cd "$LOCAL_REPO_PATH" || (echo "$(date) : Could not locate $LOCAL_REPO_PATH" | tee -a "$LOG_FILE" && jumpto end)

# Fetch updates from the remote repository
git fetch origin $BRANCH > /dev/null 2>&1

# Compare the local and remote branches
if git diff --quiet HEAD origin/$BRANCH; then
    echo "$(date) : No changes detected" | tee -a "$LOG_FILE"
else
    echo "$(date) : Changes detected..." | tee -a "$LOG_FILE"

    # Conflict detection
    INCOMING=$(git log HEAD..origin/$BRANCH 2>/dev/null)
    UNCOMMITTED=$(git status --porcelain 2>/dev/null)
    CONFLICTS=''
    if [ -n "$INCOMING" ] && [ -n "$UNCOMMITTED" ]; then
        BASE=$(git merge-base HEAD origin/$BRANCH)
        REMOTE=$(git rev-parse origin/$BRANCH)
        LOCAL=$(git rev-parse HEAD)
        TEMPDIR=$(mktemp -d)
        FILES=$(git diff --name-only $BASE $LOCAL $REMOTE)
        for FILE in $FILES; do
            git merge-file --print -p $BASE $LOCAL $REMOTE -- "$FILE" > "$TEMPDIR/$FILE" || CONFLICTS="$CONFLICTS $FILE"
        done
        rm -rf "$TEMPDIR"
    fi
    if [ -n "$CONFLICTS" ]; then
        echo "$(date) : Merge conflicts detected in the following files:" | tee -a "$LOG_FILE"
        echo "$(date) : $CONFLICTS" | tee -a "$LOG_FILE"
        jumpto end
    fi

    git pull origin $BRANCH
    echo "$(date) : Pull complete." | tee -a "$LOG_FILE"

    # Rebuild containers if necessary
    echo "$(date) : Re-building and starting containers..." | tee -a "$LOG_FILE"
    make prod | tee -a "$LOG_FILE"
    echo "$(date) : Rebuilt containers." | tee -a "$LOG_FILE"
fi


: end:
rm "$ONGOING_PULL_FILE_PATH"
echo "$(date) : End of script." | tee -a "$LOG_FILE"
