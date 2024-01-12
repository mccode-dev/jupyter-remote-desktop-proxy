FROM quay.io/jupyter/base-notebook:latest

USER root

# Add a non-snap Firefox through pinning + other useful desktop utils
RUN apt-get -y -qq update \
 && apt-get -y -qq install -y software-properties-common && add-apt-repository ppa:mozillateam/ppa \
 && echo 'Package: *' > /etc/apt/preferences.d/mozilla-firefox \
 && echo Pin: release o=LP-PPA-mozillateam >> /etc/apt/preferences.d/mozilla-firefox \
 && echo Pin-Priority: 1001 >> /etc/apt/preferences.d/mozilla-firefox \
 && apt-get install -y dbus-x11 \
        xfce4 \
        xfce4-panel \
        xfce4-session \
        xfce4-settings \
        xorg \
        xubuntu-icon-theme \
        tilix fonts-ubuntu xfonts-base xfonts-scalable \
        tigervnc-standalone-server \
        tigervnc-xorg-extension \
        view3dscene \
        xdg-utils \
        gedit \
        gedit-plugins \
        evince \
        gnuplot \
        octave \
        git \
        firefox \
    # Remove screenlock
 && apt-get remove -y -qq light-locker xfce4-screensaver \
    # chown $HOME to workaround that the xorg installation creates a
    # /home/jovyan/.cache directory owned by root
    # Create /opt/install to ensure it's writable by pip
 && mkdir -p /opt/install \
 && chown -R $NB_UID:$NB_GID $HOME /opt/install \
 && rm -rf /var/lib/apt/lists/* 

USER $NB_USER

COPY --chown=$NB_UID:$NB_GID jupyter_remote_desktop_proxy /opt/install/jupyter_remote_desktop_proxy
COPY --chown=$NB_UID:$NB_GID environment.yml setup.py MANIFEST.in README.md LICENSE /opt/install/
COPY --chown=$NB_UID:$NB_GID McStasScript /opt/install/McStasScript

RUN cd /opt/install && \
    . /opt/conda/bin/activate && \
    mamba env update --quiet --file environment.yml && \
    # Include scipp in base env
    wget https://scipp.github.io/_downloads/e85d8706af3fe2e161bf9b5ed34bd8ae/scipp.yml && \
    mamba env update --quiet --file scipp.yml && \
    # Build NeXus using conda
    git clone https://github.com/nexusformat/code nexus-code && \
    cd nexus-code && \
    mkdir build && cd build && \
    cmake -DCMAKE_INSTALL_PREFIX=${CONDA_PREFIX} .. && make && make install && \
    cd /opt/install && \
    # Configure McStasScript for use with installed McStas
    export MCSTAS_BINDIR=`mcrun --showcfg=bindir` && \
    export MCSTAS_COMPDIR=`mcrun --showcfg=resourcedir` && \
    sed -i 's+MCSTAS_BINDIR+'"${MCSTAS_BINDIR}"'+g' McStasScript/configuration.yaml && \
    sed -i 's+MCSTAS_COMPDIR+'"${MCSTAS_COMPDIR}"'+g' McStasScript/configuration.yaml && \
    find /opt/conda/lib -type d -name mcstasscript -exec cp McStasScript/configuration.yaml \{\} \; && \
    # Run mcdoc, installed via conda
    /opt/conda/bin/mcdoc -i
    