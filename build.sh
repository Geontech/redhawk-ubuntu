#!/bin/bash
# 
# REDHAWK-Ubuntu
# 
# This project borrows from the Docker-REDHAWK-Ubuntu build scripts to faciliate
# compiling REDHAWK SDR from source in the Ubuntu OS.
# 
# © 2017 Geon Technologies, LLC. All rights reserved. Dissemination of this 
# information or reproduction of this material is strictly prohibited unless 
# prior written permission is obtained from Geon Technologies, LLC.

set -e

# The REDHAWK Version
export RH_VERSION=2.0.6

# This directory
THIS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

BUILD_DEPS="\
    autoconf \
    automake \
    build-essential \
    ca-certificates \
    cmake \
    default-jdk \
    doxygen \
    git \
    libapr1-dev \
    libaprutil1-dev \
    libboost-all-dev \
    libcos4-dev \
    libexpat1-dev \
    libfftw3-dev \
    liblog4cxx-dev \
    libomniorb4-dev \
    libtool \
    libusb-1.0.0-dev \
    libxerces-c-dev \
    omniorb-nameserver \
    omniidl \
    omniidl-python \
    omniorb-idl \
    python-dev \
    python-docutils \
    python-jinja2 \
    python-mako \
    python-numpy \
    python-omniorb \
    python-pip \
    pyqt4-dev-tools \
    unzip \
    uuid-dev \
    wget \
    xsdcxx"

# Dependency installation plus patch for XSD.
function install_build_deps () {
    apt-get update && apt-get install -qy --no-install-recommends ${BUILD_DEPS}
    pip install --upgrade pip setuptools requests virtualenv
}

function export_java_home () {
    export JAVA_HOME=$(readlink -f "/usr/lib/jvm/default-java")
}

function patch_xsd () {
    # Patch XSD 4.0.0
    cat<<EOF | tee ./xsd-4.0.0-expat.patch
diff --git a/libxsd/xsd/cxx/parser/expat/elements.txx b/libxsd/xsd/cxx/parser/expat/elements.txx
index ef9adb7..8df4d67 100644
--- a/libxsd/xsd/cxx/parser/expat/elements.txx
+++ b/libxsd/xsd/cxx/parser/expat/elements.txx
@@ -279,7 +279,7 @@ namespace xsd
         {
           parser_auto_ptr parser (XML_ParserCreateNS (0, XML_Char (' ')));
 
-          if (parser == 0)
+          if (parser.get () == 0)
             throw std::bad_alloc ();
 
           if (system_id || public_id)
EOF
    patch /usr/include/xsd/cxx/parser/expat/elements.txx xsd-4.0.0-expat.patch
}

# For build.sh -based submodules
function build_sh_process () {
    ldconfig
    pushd $1
    sed -Ei "s/(\.\/configure)/\1 CXXFLAGS=\"-fpermissive\" /g" build.sh
    ./build.sh -j$(nproc) && ./build.sh install
    popd
}

# Standard/typical reconf configure type build
function std_process () {
    ldconfig
    pushd $1
    ./reconf && ./configure CXXFLAGS="-fpermissive"
    make -j$(nproc) && make install
    popd
}

# ######################
# OmniEvents
function install_omniEvents () {
    export_java_home
    # Get omniEvents
    [ -d omniEvents ] || mkdir omniEvents
    pushd omniEvents

    if ! [ -f Makefile ]; then
        wget https://github.com/RedhawkSDR/omniEvents/archive/2.7.1.tar.gz
        tar xf 2.7.1.tar.gz --strip 1 && rm -f 2.7.1.tar.gz
    fi

    # Compile and install into where the packaged version would normally be.
    ./reconf && ./configure --prefix=/usr && \
        make -j$(nproc) && make install && make -C etc install

    popd
}
# END OmniEvents
# ######################

function replace_omniORBcfg () {
    cat<<EOF | tee /etc/omniORB.cfg
InitRef = NameService=corbaname::127.0.0.1:2809
InitRef = EventService=corbaloc::127.0.0.1:11169/omniEvents
supportBootstrapAgent = 1
EOF
}

# ######################
# UHD 3.10.01
function install_uhd () {
    export_java_home
    TARGET=uhd
    TARGET_BUILD=${TARGET}/host/build
    [ -d ${TARGET} ] || git clone -b release_003_010_001_001 git://github.com/EttusResearch/uhd.git ${TARGET}
    [ -d ${TARGET_BUILD} ] || mkdir -p ${TARGET_BUILD}
    pushd ${TARGET_BUILD} && \
        cmake .. && \
        make -j$(nproc) && \
        make test && \
        make install && \
        ldconfig && \
        cpack ../
    popd
}
# END UHD
# ######################

# ######################
# REDHAWK Repository
function install_redhawk () {
    export_java_home
    REDHAWK=redhawk
    [ -d ${REDHAWK} ] || git clone --recursive -b ${RH_VERSION} git://github.com/RedhawkSDR/redhawk.git ${REDHAWK}
    pushd ${REDHAWK}

    # ######################
    # REDHAWK core-framework
    CF=redhawk-core-framework

    # redhawk and install the /etc helpers, refresh the environment
    std_process ${CF}/redhawk/src
    cp -r /usr/local/redhawk/core/etc/* /etc
    . /etc/profile

    # bulkioInterfaces
    std_process ${CF}/bulkioInterfaces

    # burstioInterfaces
    std_process ${CF}/burstioInterfaces

    # frontendInterfaces
    std_process ${CF}/frontendInterfaces

    # redhawk-codegen
    pushd ${CF}/redhawk-codegen
    python setup.py install --home=${OSSIEHOME}
    popd
    # END core-framework
    # ######################

    # ######################
    # Std. SDRROOT
    # Compile redhawk-sharedlibs and redhawk-components
    for DD in redhawk-sharedlibs redhawk-components; do
        pushd ${DD}
        for D in * ; do [ -d "${D}" ] && build_sh_process "${D}"; done
        popd
    done

    # Install redhawk-waveforms
    pushd redhawk-waveforms
    mkdir $SDRROOT/dom/waveforms/rh
    cp -r * $SDRROOT/dom/waveforms/rh
    popd
    # END Std. SDRROOT
    # ######################

    # ######################
    # Core framework's GPP
    build_sh_process ${CF}/GPP
    # END GPP
    # ######################

    # ######################
    # RTL2832U Device
    # Compile librtlsdr
    std_process redhawk-dependencies/librtlsdr

    # ...and RTL2832U
    build_sh_process redhawk-devices/RTL2832U
    # END RTL2832U
    # ######################

    # ######################
    # USRP UHD Device
    find /usr/local -name uhd_images_downloader.py -exec {} \;

    # Compile USRP_UHD
    build_sh_process redhawk-devices/USRP_UHD
    # END USRP UHD Device
    # ######################
    
    popd
}
# END REDHAWK Repo
# ######################

# ######################
# REDHAWK IDE
function install_redhawk_ide () {
    # Download the IDE
    INSTALL_DIR="${OSSIEHOME}/../ide/${RH_VERSION}"
    mkdir -p ${INSTALL_DIR} && pushd ${INSTALL_DIR}
    IDE_ASSET="$(python ${THIS_DIR}/scripts/ide-fetcher.py ${RH_VERSION})"
    if ! [ $? -eq  0 ] || [ "" == "${IDE_ASSET}" ]; then
        echo "Failed to download IDE" 1>&2
        exit 1
    fi

    # Unpack the asset
    echo "Unpacking: ${IDE_ASSET}"
    ls -la ${IDE_ASSET}
    tar xvzf ${IDE_ASSET}
    rm -rf ${IDE_ASSET}
    ln -s $PWD/eclipse/eclipse /usr/bin/rhide
    popd
}
# END REDHAWK IDE
# ######################

# Extras

# ##################
# Geon's BU353S4 w/ libnmea
function install_BU353S4 () {
    [ -f nmealib-0.5.3.zip ] || wget http://downloads.sourceforge.net/project/nmea/NmeaLib/nmea-0.5.x/nmealib-0.5.3.zip
    [ -d nmealib ] || unzip nmealib-0.5.3.zip
    pushd nmealib
    make -j$(nproc) all-before lib/libnmea.a && cp -r lib include /usr/local && \
    popd && rm -rf nmealib nmealib-0.5.3.zip && \
    ldconfig

    TARGET="BU353S4"
    [ -d ${TARGET} ] || git clone -b 1.0.0 git://github.com/GeonTech/BU353S4.git $TARGET
    chmod +x ${TARGET}/nodeconfig.py
    build_sh_process ${TARGET}
    rm -rf ${TARGET}
}
# END BU353S4 and libnmea
# ###################

# ###################
# Geon's REST-Python
function install_rest_python() {
    # Get rest-python, run the setup script
    TARGET="rest-python"
    pushd ${SDRROOT}
    git clone -b master https://github.com/GeonTech/rest-python.git ${TARGET}
    pushd ${TARGET}
    ./setup.sh install && pip install -r requirements.txt
    popd # target
    popd # sdrroot
}
# END REST-Python
# ###################

# Make the REDHAWK user
function add_redhawk_user () {
    useradd -M -r -s /sbin/nologin -c "REDHAWK System Account" redhawk
}

# Re-own SDRROOT to redhawk
function redhawk_owns_sdrroot () {
    chown -R redhawk:redhawk $SDRROOT
    chmod -R g+ws $SDRROOT
}

BUILD_TEMP=temp
[ -d ${BUILD_TEMP} ] || mkdir -p ${BUILD_TEMP}
pushd ${BUILD_TEMP}

# Dependencies
install_build_deps
patch_xsd
install_omniEvents
replace_omniORBcfg
install_uhd

# REDHAWK
install_redhawk
install_redhawk_ide

# Extras
install_BU353S4
install_rest_python

# Make redhawk user and own the SDRROOT
add_redhawk_user
redhawk_owns_sdrroot

# Pop out of temp
popd