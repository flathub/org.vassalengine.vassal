#!/bin/bash

api=https://api.github.com
repo=vassalengine/vassal
release=
token=

# --- Help message ---------------------------------------------------
usage() {
    cat <<-EOF
	Usage: $0 --release RELEASE --token TOKEN

	where RELEASE is the release number, and TOKEN is either a
	GitHub personal access token, or a file containinig such a
	token.
	EOF
}

# --- Process command line -------------------------------------------
while test $# -gt 0 ; do
    arg=$(echo $1 | tr '[A-Z]' '[a-z]')
    case x$arg in
        x-h|x--help)
            usage
            exit 0
            ;;
        x-r|x--release)
            release=$2
            shift
            ;;
        x-t|x--token)
            token=$2
            shift
            if test -f $token ; then
                token=`cat $token`
            fi
            ;;
        x*)
            echo "$0: Unknown argument: $1"
            exit 1
            ;;
    esac
    shift
done

# --- Check the arguments --------------------------------------------
if [ "x$release" = "x" ] ; then
    echo "No release specified"
    exit 1
fi
if [ "x$token" = "x" ] ; then
    echo "No personal access token specified"
    exit 1
fi

# --- Get an artifact ------------------------------------------------
get_artefact() {
    release="$1" ; shift
    token="$1" ; shift
    name="$1" ; shift

    echo -n "Getting artefact: ${name} ..."
    action_id=$(curl -s -L ${api}/repos/${repo}/actions/workflows/release.yml/runs | jq  ".workflow_runs[] | select(.head_branch==\"${release}\") | .id")
    if [ "x$action_id" = "x" ] ; then
        echo "Failed to get GitHub action id for ${release}"
        exit 1
    fi

    url=$(curl -s -L ${api}/repos/${repo}/actions/runs/${action_id}/artifacts | jq -r ".artifacts[] | select(.name==\"${name}\") | .archive_download_url")
    curl -s -L -H "Authorization: token ${token}" "${url}" -o ${name}.zip

    if [ ! -f ${name}.zip ] ; then
        echo "Failed to download the ${name} artefact"
        exit 1
    fi
    
    echo " done"
}


# --- Do the download and update -------------------------------------
get_artefact "$release" "$token" "flatpak-recipe"
echo -n "Unpacking flatpak-recipe.zip ..."
unzip -qq -o flatpak-recipe.zip
rm -f flatpak-recipe.zip
echo " done"

cat <<EOF
Now make a branch

  git checkout -b update-to-${release}

Add the changed files

  git add org.vassalengine.vassal.yml maven-dependencies.yml

Commit

  git commit -m "Update for ${release}"

Push

  git push

and make a Pull-request
EOF

#
# EOF
#

