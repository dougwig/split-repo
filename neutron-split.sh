#!/bin/bash
#
# Use this script to split advanced services out of Neutron.
# Derived from oslo graduation script.
#
# To use:
#
#  1. Clone a copy of the neutron repository to be manipulated.
#  2. cd into the neutron repo to be changed.
#  3. Run positron-split.sh with the directory names of a neutron repo and
#     the new split repo
#
#       ~/bin/positron-split.sh ./neutron ./positron
#
#  4. Clean up the results a bit by hand to make the tests work
#     (update dependencies, etc.).
#

# Stop if there are any command failures
set -e

tmpdir=$(mktemp -d -t neutron-split.XXXX)
mkdir -p $tmpdir
logfile=$tmpdir/output.log
# echo "Logging to $logfile"

src_repo="$1"
dst_repo="$2"

if [ ! -d "$src_repo" ]; then
    echo "usage: `basename $0` <source-repo-dir> <dest-repo-dir>"
    exit 1
elif [ -d "$dst_repo" ]; then
    echo "ERROR: $dst_repo already exists"
    exit 1
fi

# Redirect stdout/stderr to tee to write the log file
# (borrowed from verbose mode handling in devstack)
# exec 1> >( awk '
#                 {
#                     cmd ="date +\"%Y-%m-%d %H:%M:%S \""
#                     cmd | getline now
#                     close("date +\"%Y-%m-%d %H:%M:%S \"")
#                     sub(/^/, now)
#                     print
#                     fflush()
#                 }' | tee "$logfile" ) 2>&1

function count_commits {
    echo
    echo "Have $(git log --oneline | wc -l) commits"
}

set -x

# The list of files we want to start with.

basedir=`dirname "$0"`
files_to_exclude=$(cat $basedir/*aas-keep.txt)

# Get ourselves a play area.
rsync -a "$src_repo"/ "$dst_repo"
cd "$dst_repo"

# Pull in feature branches
# git pull origin master
# git checkout feature/lbaasv2
# git checkout master
# git merge feature/lbaasv2


# Build the grep pattern for ignoring files that we want to keep
exclude_pattern="\($(echo $files_to_exclude | sed -e 's/ /\\|/g')\)"
# Prune all other files in every commit
pruner="git ls-files | grep \"$exclude_pattern\" | git update-index --force-remove --stdin; git ls-files > /dev/stderr"


# Find all first commits with listed files and find a subset of them that
# predates all others

roots=""
files=$(git ls-files | grep -v "$exclude_pattern")
for file in $files; do
    sfile_root="$(git rev-list --reverse HEAD -- $file | head -n1)"
    fail=0
    for root in $roots; do
        if git merge-base --is-ancestor $root $file_root; then
            fail=1
            break
        elif !git merge-base --is-ancestor $file_root $root; then
            new_roots="$new_roots $root"
        fi
    done
    if [ $fail -ne 1 ]; then
        roots="$new_roots $file_root"
    fi
done

# Purge all parents for those commits

set_roots="
if [ '' $(for root in $roots; do echo " -o \"\$GIT_COMMIT\" == '$root' "; done) ]; then
    echo ''
else
    cat
fi"


# Enhance git_commit_non_empty_tree to skip merges with:
# a) either two equal parents (commit that was about to land got purged as well
# as all commits on mainline);
# b) or with second parent being an ancestor to the first one (just as with a)
# but when there are some commits on mainline).
# In both cases drop second parent and let git_commit_non_empty_tree to decide
# if commit worth doing (most likely not).

skip_empty=$(cat << \EOF
if [ $# = 5 ] && git merge-base --is-ancestor $5 $3; then
    git_commit_non_empty_tree $1 -p $3
else
    git_commit_non_empty_tree "$@"
fi
EOF
)

# Filter out commits for unrelated files
echo "Pruning commits for unrelated files..."
git filter-branch --index-filter "$pruner" --parent-filter "$set_roots" --commit-filter "$skip_empty" HEAD

# Commit the work we have done so far. Changes to make
# it work will be applied on top.
#git add .
#git commit -m "exported from oslo-incubator by graduate.sh"

echo "The scratch files and logs from the export are in: $tmpdir"
echo "The next step is to make the tests work."
