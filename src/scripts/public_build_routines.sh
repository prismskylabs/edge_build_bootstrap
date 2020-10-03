PIP_VER=20.0.2
VENVS=/opt/venvs
CONAN_VER=1.29.2


CONAN_ENV_DIR=$VENVS/conan
 
bootstrap_install_python()
{
    sudo apt-get update -y --force-yes
    sudo apt-get install build-essential python3 python3-distutils vim -y --force-yes

    # We do not use system pip (from ubuntu) as it is not upgradable. So, install it from scratch
    wget  https://bootstrap.pypa.io/get-pip.py -O /tmp/get-pip.py --progress=dot:giga
    sudo python3 /tmp/get-pip.py pip==$PIP_VER wheel==0.34.2 setuptools\>=34.0.0
    sudo python3 -m pip install pip==$PIP_VER --upgrade

    sudo mkdir -p $VENVS 

}

bootstrap_install_conan()
{
    sudo python3 -m venv $CONAN_ENV_DIR
    sudo $CONAN_ENV_DIR/bin/pip3 install conan==$CONAN_VER

    sudo mkdir -p /usr/local/bin
    sudo ln -s  $CONAN_ENV_DIR/bin/conan /usr/local/bin/conan 
}

boostrap_configure_conan()
{
    PSL_CONAN_USER=${PSL_CONAN_USER:-$USER}
    sudo -H -u $PSL_CONAN_USER conan
    CONAN_CONF=~$PSL_CONAN_USER/.conan/conan.conf
    # Enable revisions
   if ! grep "revisions_enabled = True           # environment CONAN_REVISIONS_ENABLED"  $CONAN_CONF; then
       CONF_TMP=$(mktemp  ~$CONAN_CONF.XXX.prv)
       cp $CONAN_CONF $CONF_TMP
       cat $CONF_TMP | \
           sed -e 's/# revisions_enabled = False           # environment CONAN_REVISIONS_ENABLED/revisions_enabled = True           # environment CONAN_REVISIONS_ENABLED/' \
             >$CONAN_CONF
   fi
}

bootstrap_setup()
{
    bootstrap_install_python
    bootstrap_install_conan
    boostrap_configure_conan
    echo "Bootstrap tools setup is done."
}
