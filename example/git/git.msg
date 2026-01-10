
* HEADLESS GIT SERVER *

Git repositories are located at: `/var/db/git/` and this directory
should be externally mounted to this jail.  The `git` user's home
direcotry is set to this location as well and it contains a
`.ssh/autohorised_keys` file. This git server supports passwordless
login so users should upload their public key to this server.

NOTE:
    SSH Keys:   ed25519
    SSH Port:   22

For users to get passwordless login, the following steps should be
done.

1. Copy public key up to the server.
        ssh-copy-id -i ~/.ssh/id_ed25519.pub 192.168.0.202

2. Crete an entry in '~/.ssh/config'.
        Host git
                User git
                Hostname 192.168.0.202
                IdentityFile ~/.ssh/id_ed25519

Repositories can be created manually with something like the
following:

On users machine:
1. Create a bare repository.
        cd ~/.git-repositories
        git init --bare temp.git
2. Put it on the server.
        scp -r temp.git git@git.local
3. Getting it off the server
        git clone git@git.local:john/temp.git

Or a simple script (something like below) can be used to list the git repositories.
        #!/bin/sh
        
        # This script will list all the <name>.git--while skipping the 
        # <name>.wiki.git--directories and read the the "description" file.
        printf -- "%-36s %-52s %-30s\n" "NAME" "CLONE" "DESCRIPTION"
        find . -type d -name \*.git -not -name \*.wiki.git -print -prune | sort | while read d; do
                repo=$(echo ${d} | awk -F "." '{print $2}' | cut -d '/' -f 2-)
                desc_file="${d}/description"
                if [ -f "${desc_file}" ]; then
                        desc=$(head -c 40 "${desc_file}")
                else
                        desc="(no description)"
                fi
                printf "%-36s %-52s %-30s\n" ${repo} "git@git.local:${repo}.git" "${desc}"
        done

1. Place the following script on the git server:
        scp gitls git@git:

2. Create a function in a shells configration file to call that script on the server.
   The following example is for ZSH.
        # gitls --
        #   Call the 'gitls' shell script on the git server to
        #   list out the remote repositories.
        function gitls() {
                ssh \
                -p 22 \
                -l git \
                -i ~/.ssh/id_ed25519 \
                192.168.0.202 \
                -t "~/gitls"
        }

In addition, a script can be used for intialization of bare repositories (something like below).

        #!/bin/sh
        
        # This script will accept a option for a repository and a description to create.
        #
        # If no 'group' is included, it will default to 'john'.
        # If no 'description' is included, then this script defaults to: '(no description)'
        #
        # SYNOPSYS
        #       gitinit [group/]<repository> [description]
        name=$1
        desc=$2
        user=ungrouped
        directory="./"
        server="git"

        # aif --
        #   Aniphoric if.
        #	This function will check an `expr` is not NULL before returned,
        #	otherwise an `iffalse` value is returned.
        # EX
        #		var=$(aif $(some_expr) 7)
        aif() {
                local expr=$1
                local iffalse=$2
                if [ -n "$expr" ] && [ "$expr" != "-" ]; then
                        echo "$expr";
                else
                        echo "$iffalse";
                fi
        }
        
        group=$(echo "${name}" | awk -F "/" '{print $1}')
        name=$(aif                                              \
                "$(echo "${name}" | awk -F "/" '{print $2}')"   \
                "${name}")
        
        if [ "${group}" = "${name}" ]; then
                group=${user}
        fi
        
        if [ -z "${desc}" ]; then
                desc="(no description)"
        fi
        
        mkdir -pv "${directory}${group}"                || { echo "Error creating directory"; exit 1; }
        cd "${directory}${group}"                       || { echo "Error changing directory"; exit 1; }
        git init --bare -q ${name}.git                  || { echo "Error creating git directory"; exit 1; }
        echo "${desc}" > "${name}.git/description"      || { echo "Error writing description"; exit 1; }
        
        cat <<_EOF_ >&1
        The project repository for "${name}" was created in the following group: "${group}".
        However, the repository for this project is empty.
        
        Command line instructions:
        
        Create a new repository
            git clone git@${server}:${group}/${name}.git
            cd ${name}
            touch readme.md
            git add readme.md
            git commit -m "add readme.md"
            git push -u origin master
        
        Push an existing folder
            cd existing_folder
            git init
            git remote add origin git@${server}:${group}/${name}.git
            git add .
            git commit -m "Initial commit"
            git push -u origin master
        
        Push an existing Git repository
            cd existing_repo
            git remote rename origin old-origin
            git remote add origin git@${server}:${group}/${name}.git
            git push -u origin --all
            git push -u origin --tags
        _EOF_

1. Place the following script on the git server:
        scp gitinit git@git:

2. Create a function in a shells configration file to call that script on the server.
   The following example is for ZSH.
        # gitinit --
        #   Call the 'gitinit' shell script on the git server to
        #   create a new repository.
        # EX:
        #   gitinit newrepo "Repository description"
        function gitinit() {
                ssh \
                -p 22 \
                -l git \
                -i ~/.ssh/id_ed25519 \
                192.168.0.202 \
                -t "~/gitinit $1 $(printf '%q' "$2")"
        }
