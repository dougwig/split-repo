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

tmpdir=$(mktemp -d -t positron-split.XXXX)
mkdir -p $tmpdir
logfile=$tmpdir/output.log
echo "Logging to $logfile"

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
exec 1> >( awk '
                {
                    cmd ="date +\"%Y-%m-%d %H:%M:%S \""
                    cmd | getline now
                    close("date +\"%Y-%m-%d %H:%M:%S \"")
                    sub(/^/, now)
                    print
                    fflush()
                }' | tee "$logfile" ) 2>&1

function count_commits {
    echo
    echo "Have $(git log --oneline | wc -l) commits"
}

set -x

# The list of files we want to start with.

files_to_keep=$(cat - <<EOF

CONTRIBUTING.rst
HACKING.rst
LICENSE
MANIFEST.in
README.rst
TESTING.rst
babel.cfg
etc/neutron.conf
neutron/common
neutron/__init__.py
neutron/db/common_db_mixin.py
neutron/db/firewall
neutron/db/__init__.py
neutron/db/loadbalancer
neutron/db/model_base.py
neutron/db/models_v2.py
neutron/db/vpn
neutron/db/migration/alembic.ini
neutron/db/migration/alembic_migrations/core_init_ops.py
neutron/db/migration/alembic_migrations/env.py
neutron/db/migration/alembic_migrations/firewall_init_ops.py
neutron/db/migration/alembic_migrations/heal_script.py
neutron/db/migration/alembic_migrations/__init__.py
neutron/db/migration/alembic_migrations/lb_init_ops.py
neutron/db/migration/alembic_migrations/loadbalancer_init_ops.py
neutron/db/migration/alembic_migrations/other_extensions_init_ops.py
neutron/db/migration/alembic_migrations/other_plugins_init_ops.py
neutron/db/migration/alembic_migrations/versions
neutron/db/migration/alembic_migrations/vpn_init_ops.py
neutron/db/migration/cli.py
neutron/db/migration/__init__.py
neutron/db/migration/migrate_to_ml2.py
neutron/db/migration/models
neutron/db/migration/README
neutron/extensions/__init__.py
neutron/extensions/agent.py
neutron/extensions/firewall.py
neutron/extensions/lbaas_agentscheduler.py
neutron/extensions/loadbalancer.py
neutron/extensions/multiprovidernet.py
neutron/extensions/vpnaas.py
neutron/hacking
neutron/services/__init__.py
neutron/services/firewall
neutron/services/loadbalancer
neutron/services/provider_configuration.py
neutron/services/service_base.py
neutron/services/vpn
neutron/tests/unit/__init__.py
neutron/tests/unit/base.py
neutron/tests/unit/tools.py
neutron/tests/unit/db/__init__.py
neutron/tests/unit/db/firewall
neutron/tests/unit/db/loadbalancer
neutron/tests/unit/db/vpn
neutron/tests/unit/services/__init__.py
neutron/tests/unit/services/firewall
neutron/tests/unit/services/loadbalancer
neutron/tests/unit/services/vpn
neutron/tests/unit/test_extension_firewall.py
openstack-common.conf
requirements.txt
run_tests.sh
setup.cfg
setup.py
test-requirements.txt
tools
tox.ini

EOF)

# Get ourselves a play area.
rsync -a "$src_repo"/ "$dst_repo"
cd "$dst_repo"

# Pull in feature branches
# git pull origin master
# git checkout feature/lbaasv2
# git checkout master
# git merge feature/lbaasv2


# Build the grep pattern for ignoring files that we want to keep
keep_pattern="\($(echo $files_to_keep | sed -e 's/ /\\|/g')\)"
# Prune all other files in every commit
pruner="git ls-files | grep -v \"$keep_pattern\" | git update-index --force-remove --stdin; git ls-files > /dev/stderr"


# Find all first commits with listed files and find a subset of them that
# predates all others

roots=""
for file in $files_to_keep; do
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

# Move things around
echo "Moving files into place..."
git mv neutron positron

# Fix imports after moving files
# echo "Fixing imports..."
# if [[ -d oslo/$new_lib ]]; then
#     find . -name '*.py' -exec sed -i "s/openstack.common.${new_lib}/oslo.${new_lib}/" {} \;
# else
#     find . -name '*.py' -exec sed -i "s/openstack.common/oslo.${new_lib}/" {} \;
# fi

# Commit the work we have done so far. Changes to make
# it work will be applied on top.
#git add .
#git commit -m "exported from oslo-incubator by graduate.sh"

echo "The scratch files and logs from the export are in: $tmpdir"
echo "The next step is to make the tests work."