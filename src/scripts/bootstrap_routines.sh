PIP_VER=20.0.2
VENVS=/opt/venvs
CONAN_VER=1.29.2


CONAN_ENV_DIR=$VENVS/conan


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
    sudo python3 /tmp/get-pip.py pip==$PIP_VER wheel==0.34.2 setuptools\>=34.0.0
    sudo python3 -m pip install pip==$PIP_VER --upgrade
    sudo python3 -m pip install virtualenv

    sudo mkdir -p $VENVS 

}

bootstrap_install_extra_tools()
{
    sudo apt-get install build-essential cmake python3-dev  -y --force-yes
}

boostrap_install_linux_amd64_tools()
{
    sudo apt-get install yasm g++ gdb
}

bootstrap_install_conan()
{
    sudo python3 -m virtualenv $CONAN_ENV_DIR
    sudo $CONAN_ENV_DIR/bin/pip3 install conan==$CONAN_VER

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
    PKG_INFO_PATH=$SCRIPTS_DIR/../../../edge_build_base
    [ -f $PKG_INFO_PATH ] || \
        { >&2 echo "Error. File with edge_build_base package info not found. Skipping installation."; return 1; }
    EDGE_BUILD_BASE_CONAN_PKG=$(cat $PKG_INFO_PATH)
    echo "Trying to install conan package $EDGE_BUILD_BASE_CONAN_PKG"
    echo "Please, enter psl-conan (artifactory-cpp) credentials to download deps package when prompted"

    EDGE_BUILD_BASE_DIR=$SCRIPTS_DIR/../../edge_build_base
    mkdir -p $EDGE_BUILD_BASE_DIR
    pushd $EDGE_BUILD_BASE_DIR
      conan install $EDGE_BUILD_BASE_CONAN_PKG
    popd

    .  $EDGE_BUILD_BASE_DIR/src/scripts/setup_routines.sh
    setup_env_for_target $PKG_PLATFORM
}

bootstrap_configure_toolchain ()
{
    PKG_PLATFORM="${PKG_PLATFORM:-Linux-amd64}"
    if [ "$PKG_PLATFORM" = "Linux-x86_64"] ; then
       PKG_PLATFORM="Linux-amd64"
    fi

    export PKG_PLATFORM="${PKG_PLATFORM}"
    if [ "$PKG_PLATFORM" = "Linux-amd64"]; then 
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
