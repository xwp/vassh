#!/usr/bin/env bash
# vassh: Vagrant Host-Guest SSH Command Wrapper/Proxy/Forwarder
# Author: Weston Ruter <weston@x-team.com> (@westonruter), X-Team
# Wrap commands to execute via SSH in host's working directory's corresponding synced_folder in Vagrant VM (guest)
# Version: 0.2
#
# USAGE:
# (Installation: First source vassh.sh into your .bashrc)
# $ cd /home/thunderboy/vagrantproject/some/subdir
# $ vassh pwd
# /vagrant/some/subdir
# $ vassh make
# $ vassh wp core update
# Success: WordPress is at the latest version.
# $ alias wp="_vassh_try wp"
# $ wp exp<TAB> # if host has Bash completion added for WP-CLI, here i can haz tab-completions from Vagrant!
# $ vasshin # drops you in Bash prompt inside the corresponding synced_folder
# $ vaashin some-interactive-script # yay colors! yay tty!

# TODO: Is this more suitable as a Vagrant plugin? http://docs.vagrantup.com/v2/plugins/
# TODO: Can we keep the SSH connection open to speed up commands?
function usage {
    echo "vassh: Vagrant Host-Guest SSH Command Wrapper/Proxy/Forwarder"
    echo " "
    echo "vassh command"
    echo "    command will be executed in the vagrant vm"
    echo " "
    echo "vasshin command"
    echo "    vasshin drops you in Bash promt inside the corresponding synced_folder"
    exit 1
}

# Walk up the directory tree to find a Vagrantfile
function _vagrant_locate_vagrantfile {
    dir="${PWD}"
    while [ -n "$dir" ]; do
        if [ -e "$dir/Vagrantfile" ]; then
            break
        fi
        dir=${dir%/*}
    done
    if [ -z "$dir" ]; then
        echo "Error: Unable to find Vagrantfile" 1>&2
        return 1
    else
        echo $dir/Vagrantfile
        return 0
    fi
}


# With the location of the Vagrantfile and the host's current working directory,
# look at the Vagrant synced_folders and determine the synced_folder path inside
# of the guest that corresponds to the
function _vagrant_locate_cwd_in_synced_folder {
    config_file=$(_vagrant_locate_vagrantfile)
    if [ -z "$config_file" ]; then
        return 2
    fi

    # TODO: This parsing of the Vagrantfile is HACKY. We should be reading it with Ruby.
    # TODO: This does not work with multi-machine!
    perl - "$config_file" "${PWD}" <<'__HERE__'
        use File::Basename;
        use Cwd 'abs_path';
        my $root = dirname $ARGV[0];
        my $cwd = $ARGV[1];
        chdir $root;
        my $located_cwd;
        while(<>) {
            if (/^\s*\w+\.vm\.synced_folder\s+['"]([^"']+?)['"],\s*['"]([^"']+?)['"]/) {
                my $host_dir = abs_path $1;
                my $guest_dir = $2;
                $guest_dir =~ s{/$}{};
                if ( $cwd =~ /(\Q$host_dir\E)(\/.*)?/ ) {
                    $located_cwd = $guest_dir . $2;
                }
            }
        }

        if ($located_cwd) {
            print $located_cwd;
            exit 0;
        }
        else {
            print STDERR "vassh: Unable to locate cwd in synced folder\n";
            exit 3;
        }
__HERE__
}


# Wrapper command which passes arguments into vagrant-ssh as a command to execute in the
# synced_folder (sub)directory corresponding to the host's current working directory
function vassh {
    while getopts "h" o; do
      case "${o}" in
        h)
          usage
        ;;
      esac
    done

    if [ -z "$1" ]; then
        echo "vassh: Missing command to run on other system" 1>&2
        return 4
    fi
    dir=$(_vagrant_locate_cwd_in_synced_folder)
    cmd="cd $dir; $@"
    vagrant ssh -c "$cmd" -- -t -A
}


# Wrapper command which copies command to vagrant and then logs in interactively to then
# run the command upon login; if no command is supplied, then it drops you into the
# synced_folder (sub)directory corresponding to the host's current working directory.
function vasshin {
    dir=$(_vagrant_locate_cwd_in_synced_folder)
    if [ -z "$dir" ]; then
        return 4
    fi

    if [ -z "$1" ]; then
        cmd="cd $dir"
    else
        cmd="cd $dir; $@; exit \$?"
    fi

    # First we copy the $cmd to the Vagrant machine, and make sure it gets sourced in the .bashrc
    # TODO: better if we did this with a synced_folder)
    # Note: We do ssh-config instead of vagrant-ssh because stdin for vagrant-ssh for some reason is 'exit'
    vagrant ssh-config > /tmp/vassh_ssh_config
    ssh -q -F /tmp/vassh_ssh_config default '
        cat - > /tmp/vassh_start_cmd;
        if ! grep -q vassh_start_cmd ~/.bashrc; then
            echo "
                if [ -e /tmp/vassh_start_cmd ]; then
                    mv /tmp/vassh_start_cmd{,~};
                    source /tmp/vassh_start_cmd~;
                fi
            " >> ~/.bashrc;
        fi
    ' <<< $cmd

    # Then open ssh and the command will get executed as part of the login
    vagrant ssh
}

# Bash alias helper. Run the command via Vagraht SSH if we're in a Vagrant project,
# otherwide just run it on the host
function _vassh_try {
    if _vagrant_locate_vagrantfile >/dev/null 2>&1; then
        vassh $@
    else
        $@
    fi
}

# Bash alias helper. Run the command via Vagraht SSH if we're in a Vagrant project,
# otherwide just run it on the host
function _vasshin_try {
    if _vagrant_locate_vagrantfile >/dev/null 2>&1; then
        vasshin $@
    else
        $@
    fi
}

# TODO: Bash completion for all commands across Vagrant SSH; the following is not working
#function _vagrant_shell_escape {
#    perl -p -e 'chomp; s/(?=\W)/\\/'
#}
#function _vagssh {
#    local cur opts command exported_vars
#
#    cur=${COMP_WORDS[COMP_CWORD]}
#
#    i=0
#    exported_vars="vagssh_cmd=$2; COMP_CWORD=$COMP_CWORD; COMP_WORDS=()"
#    for compword in "$@"; do
#        echo $compword
#        exported_vars="$exported_vars; COMP_WORDS[$i]="$(_vagrant_shell_escape <<< "$compword")
#        i=$(expr $i + 1)
#    done
#
#    echo $exported_vars
#    cmd="$exported_vars;"'
#        source /etc/bash_completion;
#        completion_command=$(bash -i -c "complete -p" 2>/dev/null | grep -e ${vagssh_cmd}$ | perl -n -e "@a = split; pop @a; print pop @a;");
#        echo $completion_command;
#        $completion_command;
#        echo $COMPREPLY
#    '
#    opts=$(vagrant ssh -c "$cmd" -- -t)
#    COMPREPLY=( $(compgen -W "$opts" -- $curr) )
#}
#complete -F _vagssh vassh
