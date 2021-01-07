PIP_VER=20.0.2
VENVS=/opt/venvs
CONAN_VER=1.29.2


CONAN_ENV_DIR=$VENVS/conan


apt-get-ni ()
{
    sudo apt-get --allow-downgrades --allow-remove-essential --allow-change-held-packages "$@"
}

refresh-fs ()
{
    # Workaround MacOSX Sierra NSF mount issue with Vagrant
    # https://github.com/mitchellh/vagrant/issues/8061#issuecomment-291954060
    if [ $# -ne 1 ]; 
        then DSTPATH=.
    else 
        DSTPATH="$1"
    fi

    find "$DSTPATH" -type d \
        -exec touch '{}'/.touch ';' \
        -exec rm -f '{}'/.touch ';' \
        2>/dev/null
}


wgetbig ()
{   # This makes big downloads look much better in vagrant output
    # It expected to be used with --postgres=dot:giga 
    # See actual usages for examples
    stdbuf -eL wget "$@" 2>&1 1>/dev/null  |  stdbuf -oL sed -e 's!\.!\.!g'
    # We use stdbuf and piping here to flush output by lines, instead of by symbol, thus producing less noise and length
}

boostrap_install_git()
{
    sudo apt-get update -y --force-yes
    sudo apt-get install git -y --force-yes
    PSL_USER=${PSL_USER:-$USER}

    # Cache credentials entered once for some time.
    sudo -H -u ${PSL_USER} git config --global credential.helper 'cache --timeout 28800'
}

boostrap_install_vim()
{
    sudo apt-get install vim vim-scripts vim-doc -y --force-yes
    sudo update-alternatives --set editor /usr/bin/vim.basic

}

bootstrap_install_youcompleteme()
{
    # https://github.com/ycm-core/YouCompleteMe#linux-64-bit
    PSL_USER=${PSL_USER:-$USER}
    BUNDLE_DIR=$(sudo -H -u ${PSL_USER} bash -c 'echo "$HOME/.vim/bundle"')
    sudo -H -u ${PSL_USER} mkdir -p $BUNDLE_DIR
    sudo -H -u ${PSL_USER} git clone https://github.com/VundleVim/Vundle.vim.git $BUNDLE_DIR/Vundle.vim
    sudo -H -u ${PSL_USER} vim +PluginInstall +qall
    sudo -H -u ${PSL_USER} bash -c 'pushd  ~/.vim/bundle/YouCompleteMe;  python3 install.py --clangd-completer; popd'

}

bootstrap_install_python()
{
    sudo apt-get install build-essential python3 python3-distutils vim -y --force-yes

    # We do not use system pip (from ubuntu) as it is not upgradable. So, install it from scratch
    wget  https://bootstrap.pypa.io/get-pip.py -O /tmp/get-pip.py --progress=dot:giga
    sudo -H python3 /tmp/get-pip.py pip==$PIP_VER wheel==0.34.2 setuptools\>=34.0.0
    sudo -H python3 -m pip install pip==$PIP_VER --upgrade
    sudo -H python3 -m pip install virtualenv

    sudo mkdir -p $VENVS 

}

bootstrap_install_extra_tools()
{
    sudo apt-get install build-essential cmake python3-dev  -y --force-yes
}

boostrap_install_linux_amd64_tools()
{
    sudo apt-get install nasm yasm g++ gdb pkg-config  -y --force-yes
}

bootstrap_install_conan()
{
    sudo -H python3 -m virtualenv $CONAN_ENV_DIR
    sudo -H $CONAN_ENV_DIR/bin/pip3 install conan==$CONAN_VER

    sudo mkdir -p /usr/local/bin
    [ -L /usr/local/bin/conan ] ||  sudo ln -s  $CONAN_ENV_DIR/bin/conan /usr/local/bin/conan 
}

bootstrap_configure_conan_revisions()
{
    PSL_USER=${PSL_USER:-$USER}
    sudo -H -u $PSL_USER conan
    CONAN_CONF=$(eval echo "~$PSL_USER/.conan/conan.conf")
    # Enable revisions
   if ! grep "revisions_enabled = True           # environment CONAN_REVISIONS_ENABLED"  $CONAN_CONF; then
       CONF_TMP=$(mktemp  $CONAN_CONF.prv.XXX)
       cp $CONAN_CONF $CONF_TMP
       cat $CONF_TMP | \
           sed -e '/^\[general\]$/arevisions_enabled = True           # environment CONAN_REVISIONS_ENABLED' \
             >$CONAN_CONF
   fi
}

bootstrap_configure_conan()
{
    bootstrap_configure_conan_revisions

    PSL_USER=${PSL_USER:-$USER} # Configure conan under this user
    sudo -H -u $PSL_USER conan remote remove conan-center # Remove global public default. We will use only our own conan.
    sudo -H -u $PSL_USER conan remote add psl-conan  https://artifactory-cpp.dev.prismsl.net/api/conan/conan False
    sudo -H -u $PSL_USER conan remote list
}

bootstrap_install_closed_source_related_tools () 
{
    # This is for stuff beyond Linux-x86_64. It is accessible inside our org only.
    # You can not invoke it if you are not a member of prismskylabs. 
    # It will fail, as you need credentials.
    # It basically deploys private 3-d party toolchains, conan profiles and cmake toolchain configs.
    # If you  need to integrate custom toolchain, this is where you can replace
    # code with yours to configure your toolchain, build profiles for it and so on.
    # If you need to go that way, you do customization for your particular case 
    # in your fork or copy of the code. 
    # This is where our open source ends.
    # We believe it is still useful. However, we do not guarantee it or anything about this code.
    local SCRIPTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

    conan remote list

    CONAN_USER_INFO=$(conan user -r psl-conan)
    if [ "$CONAN_USER_INFO" == "Current user of remote 'psl-conan' set to: 'None' (anonymous)" ]; then 
        echo "Logging into psl-conan server."
        echo "Please, enter your psl-conan (artifactory-cpp) credentials when prompted"
        for i in $(seq 1 5); do
            conan user -r psl-conan  -p      && break
            sleep 5 && false
        done
        if [ $? -ne 0 ]; then
            echo "Logging to conan artifactory server failed. Can not continue. Stopping."
            return 1
        fi
    fi

    PKG_INFO_PATH=$SCRIPTS_DIR/../../../edge_build_base
    [ -f $PKG_INFO_PATH ] || \
        { >&2 echo "Error. File with edge_build_base package info not found. Skipping installation."; return 1; }
    EDGE_BUILD_BASE_CONAN_PKG=$(cat $PKG_INFO_PATH)
    echo "Trying to install conan package $EDGE_BUILD_BASE_CONAN_PKG"

    EDGE_BUILD_BASE_DIR=$SCRIPTS_DIR/../../../../../edge_build_base
    mkdir -p $EDGE_BUILD_BASE_DIR
    pushd $EDGE_BUILD_BASE_DIR && rm -Rf *
      for i in $(seq 1 5); do
          conan install -r psl-conan  $EDGE_BUILD_BASE_CONAN_PKG && break
          sleep 15 && false
      done
    popd

    .  $EDGE_BUILD_BASE_DIR/src/scripts/setup_routines.sh
    setup_env_for_platform $PKG_PLATFORM
}

bootstrap_configure_toolchain ()
{
    PKG_PLATFORM="${PKG_PLATFORM:-Linux-amd64}"
    if [ "$PKG_PLATFORM" = "Linux-x86_64" ] || [ "$PKG_PLATFORM" = "Linux-amd64" ]; then
       PKG_PLATFORM="linux-amd64"
    fi

    export PKG_PLATFORM="${PKG_PLATFORM}"
    if [ "$PKG_PLATFORM" = "linux-amd64" ] && [ -z "${EDGE_TARGET:-}" ]; then 
      boostrap_install_linux_amd64_tools
    else
      bootstrap_install_closed_source_related_tools
    fi
}

bootstrap_setup()
{
    boostrap_install_git
    bootstrap_install_extra_tools
    boostrap_install_vim
    #bootstrap_install_youcompleteme
    bootstrap_install_python
    bootstrap_install_conan
    bootstrap_configure_conan
    echo "Bootstrap tools setup is done."
}
