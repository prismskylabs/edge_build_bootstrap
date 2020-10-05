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

bootstrap_install_conan()
{
    sudo python3 -m virtualenv $CONAN_ENV_DIR
    sudo $CONAN_ENV_DIR/bin/pip3 install conan==$CONAN_VER

    sudo mkdir -p /usr/local/bin
    [ -L /usr/local/bin/conan ] ||  sudo ln -s  $CONAN_ENV_DIR/bin/conan /usr/local/bin/conan 
}

bootstrap_configure_conan()
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
