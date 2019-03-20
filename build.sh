#!/bin/bash
# 
# REDHAWK-Ubuntu
# 
# This project borrows from the Docker-REDHAWK-Ubuntu build scripts to faciliate
# compiling REDHAWK SDR from source in the Ubuntu OS.
# 
# © 2019 Geon Technologies, LLC. All rights reserved. Dissemination of this 
# information or reproduction of this material is strictly prohibited unless 
# prior written permission is obtained from Geon Technologies, LLC.

set -e

# The REDHAWK Version
export RH_VERSION=2.2.1

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
    libexpat1-dev \
    libfftw3-dev \
    liblog4cxx-dev \
    libtool \
    libusb-1.0.0-dev \
    libxerces-c-dev \
    python-dev \
    python-docutils \
    python-jinja2 \
    python-mako \
    python-numpy \
    python-pip \
    pyqt4-dev-tools \
    unzip \
    uuid-dev \
    wget \
    xsdcxx \
    sqlite3 \
    libsqlite3-dev \
    libcppunit-dev"

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

function patch_cf () {
    # Patch Resource_impl.h
    cat<<EOF | tee ./Resource_impl-h.patch
diff --git a/redhawk/src/base/include/ossie/Resource_impl.h b/redhawk/src/base/include/ossie/Resource_impl.h
index 3a62e6f..dca67bc 100644
--- a/redhawk/src/base/include/ossie/Resource_impl.h
+++ b/redhawk/src/base/include/ossie/Resource_impl.h
@@ -24,6 +24,7 @@

 #include <string>
 #include <map>
+#include <boost/scoped_ptr.hpp>
 #include "Logging_impl.h"
 #include "Port_impl.h"
 #include "LifeCycle_impl.h"
EOF
    patch ./redhawk/src/base/include/ossie/Resource_impl.h Resource_impl-h.patch

    # Patch shm/Allocator.cpp
    cat<<EOF | tee ./Allocator-cpp.patch
diff --git a/redhawk/src/base/framework/shm/Allocator.cpp b/redhawk/src/base/framework/shm/Allocator.cpp
index f467de0..0c83edb 100644
--- a/redhawk/src/base/framework/shm/Allocator.cpp
+++ b/redhawk/src/base/framework/shm/Allocator.cpp
@@ -26,6 +26,7 @@
 #include <ossie/BufferManager.h>

 #include <boost/thread.hpp>
+#include <boost/scoped_ptr.hpp>

 #include "Block.h"

EOF
    patch ./redhawk/src/base/framework/shm/Allocator.cpp Allocator-cpp.patch

    # Patch ComponentHost/Makefile.am
    cat<<EOF | tee ./CH-Makefile-am.patch
diff --git a/redhawk/src/control/sdr/ComponentHost/Makefile.am b/redhawk/src/control/sdr/ComponentHost/Makefile.am
index 91bd9a6..b5bc24b 100644
--- a/redhawk/src/control/sdr/ComponentHost/Makefile.am
+++ b/redhawk/src/control/sdr/ComponentHost/Makefile.am
@@ -27,7 +27,7 @@ dist_xml_DATA = ComponentHost.scd.xml ComponentHost.prf.xml ComponentHost.spd.xm
 ComponentHost_SOURCES = ComponentHost.cpp ModuleLoader.cpp main.cpp

 ComponentHost_LDADD = \$(top_builddir)/base/framework/libossiecf.la \$(top_builddir)/base/framework/idl/libossieidl.la
-ComponentHost_LDADD += \$(BOOST_LDFLAGS) \$(BOOST_THREAD_LIB) \$(BOOST_REGEX_LIB) \$(BOOST_SYSTEM_LIB)
+ComponentHost_LDADD += \$(BOOST_LDFLAGS) \$(BOOST_THREAD_LIB) \$(BOOST_REGEX_LIB) \$(BOOST_SYSTEM_LIB) \$(BOOST_FILESYSTEM_LIB) -lomniORB4 -lomnithread -ldl
 ComponentHost_CPPFLAGS = -I\$(top_srcdir)/base/include \$(BOOST_CPPFLAGS)
 ComponentHost_CXXFLAGS = -Wall

EOF
    patch ./redhawk/src/control/sdr/ComponentHost/Makefile.am CH-Makefile-am.patch

    # Patch svc_fn_error_cpp Makefile.am
    cat<<EOF | tee ./svc_fn_error_cpp-Makefile-am.patch
diff --git a/redhawk/src/testing/sdr/dom/components/svc_fn_error_cpp/cpp/Makefile.am b/redhawk/src/testing/sdr/dom/components/svc_fn_error_cpp/cpp/Makefile.am
index 50213e7..c1845b7 100644
--- a/redhawk/src/testing/sdr/dom/components/svc_fn_error_cpp/cpp/Makefile.am
+++ b/redhawk/src/testing/sdr/dom/components/svc_fn_error_cpp/cpp/Makefile.am
@@ -28,7 +28,7 @@ noinst_PROGRAMS = svc_fn_error_cpp
 # you wish to manually control these options.
 include \$(srcdir)/Makefile.am.ide
 svc_fn_error_cpp_SOURCES = \$(redhawk_SOURCES_auto)
-svc_fn_error_cpp_LDADD = \$(CFDIR)/framework/libossiecf.la \$(CFDIR)/framework/idl/libossieidl.la \$(SOFTPKG_LIBS) \$(PROJECTDEPS_LIBS) \$(BOOST_LDFLAGS) \$(BOOST_THREAD_LIB) \$(BOOST_REGEX_LIB) \$(BOOST_SYSTEM_LIB) \$(INTERFACEDEPS_LIBS) \$(redhawk_LDADD_auto)
+svc_fn_error_cpp_LDADD = \$(CFDIR)/framework/libossiecf.la \$(CFDIR)/framework/idl/libossieidl.la \$(SOFTPKG_LIBS) \$(PROJECTDEPS_LIBS) \$(BOOST_LDFLAGS) \$(BOOST_THREAD_LIB) \$(BOOST_REGEX_LIB) \$(BOOST_SYSTEM_LIB) \$(INTERFACEDEPS_LIBS) \$(redhawk_LDADD_auto) -lomniORB4 -lomnithread
 svc_fn_error_cpp_CXXFLAGS = -Wall \$(SOFTPKG_CFLAGS) \$(PROJECTDEPS_CFLAGS) \$(BOOST_CPPFLAGS) \$(INTERFACEDEPS_CFLAGS) \$(redhawk_INCLUDES_auto)
 svc_fn_error_cpp_LDFLAGS = -Wall \$(redhawk_LDFLAGS_auto)

EOF
    patch ./redhawk/src/testing/sdr/dom/components/svc_fn_error_cpp/cpp/Makefile.am svc_fn_error_cpp-Makefile-am.patch
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
# omniORB
function install_omniORB () {
    # Get omniORB
    [ -d omniORB ] || mkdir omniORB
    pushd omniORB
    
    if ! [ -f Makefile ]; then
        wget http://downloads.sourceforge.net/omniorb/omniORB-4.2.3.tar.bz2
	tar xf omniORB-4.2.3.tar.bz2 --strip 1 && rm -f omniORB-4.2.3.tar.bz2
    fi

    # Compile and install omniORB into where packaged version would normally be.
    ./configure --prefix=/usr && \
    make && \
    make install

    popd
}
# END omniORB 
# ######################

# ######################
# omniORBpy
function install_omniORBpy () {
    # Get omniORBpy
    [ -d omniORBpy ] || mkdir omniORBpy
    pushd omniORBpy
    
    if ! [ -f Makefile ]; then
        wget http://downloads.sourceforge.net/omniorb/omniORBpy-4.2.3.tar.bz2
	tar xf omniORBpy-4.2.3.tar.bz2 --strip 1 && rm -f omniORBpy-4.2.3.tar.bz2
    fi

    # Compile and install omniORBpy into where packaged version would normally be.
    ./configure --prefix=/usr && \
    make && \
    make install

    popd
}
# END omniORBpy 
# ######################

# ######################
# OmniEvents
function install_omniEvents () {
    export_java_home
    # Get omniEvents
    [ -d omniEvents ] || mkdir omniEvents
    pushd omniEvents

    if ! [ -f Makefile ]; then
        wget https://github.com/RedhawkSDR/omniEvents/archive/2.8.1.tar.gz
        tar xf 2.8.1.tar.gz --strip 1 && rm -f 2.8.1.tar.gz
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
    pushd ${CF}
    patch_cf
    std_process redhawk/src
    cp -r /usr/local/redhawk/core/etc/* /etc
    . /etc/profile

    # bulkioInterfaces
    std_process bulkioInterfaces

    # burstioInterfaces
    std_process burstioInterfaces

    # frontendInterfaces
    std_process frontendInterfaces

    # redhawk-codegen
    pushd redhawk-codegen
    python setup.py install --home=${OSSIEHOME}
    popd

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
#install_build_deps
#patch_xsd
install_omniORB
install_omniORBpy
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
