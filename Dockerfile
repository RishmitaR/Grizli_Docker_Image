# Use Ubuntu as the base image
FROM ubuntu:20.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV HOME="/home/user"
ENV SPS_HOME="$HOME/fsps$SPS_HOME"
ENV PATH="$HOME/SAOImageDS9/bin:$HOME/Bin/bin:$HOME/.local/bin:$SPS_HOME/src:$PATH"
ENV LD_LIBRARY_PATH="$HOME/Bin/lib:$LD_LIBRARY_PATH"
ENV GRIZLI="$HOME/grizli"
ENV iref="$GRIZLI/iref/"
ENV jref="$GRIZLI/jref/"

# Create the user with a home directory and grant sudo access
RUN useradd -m -s /bin/bash user && \
    echo "user ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    echo "user:password" | chpasswd

# Add repo to install Python 3.9
RUN apt-get update && \
    apt-get install -y --no-install-recommends software-properties-common && \
    add-apt-repository ppa:deadsnakes/ppa

# Install Python 3.9 and related tools
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    python3.9 \
    python3.9-venv \
    python3.9-dev \
    python3.9-distutils \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Update alternatives to set Python 3.9 as default python3
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.9 1 

RUN python3 -m ensurepip --upgrade

# Install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    libssl-dev \
    libffi-dev \
    python3 \ 
    python3-dev \ 
    python3-pip \
    gcc \
    make \
    git \
    libhdf5-dev \ 
    libx11-dev \
    libxft-dev \
    libxt-dev \ 
    libcfitsio-dev \
    libreadline-dev \
    libgsl-dev \
    libfftw3-dev \
    gfortran \
    wget \
    autoconf \ 
    automake \ 
    libxml2-dev \ 
    libxslt1-dev \ 
    tcl \
    tk \ 
    zip \ 
    zlib1g-dev \ 
    python3-tk \
    libatlas-base-dev \
    liblapack-dev \
    libblas-dev \
    libopenblas-dev \
    liblapacke-dev \
    curl \ 
    && rm -rf /var/lib/apt/lists/*

# Create directories and set permissions
RUN mkdir -p $HOME/Bin $HOME/grizli/CONF $HOME/grizli/templates $HOME/grizli/iref $HOME/grizli/jref && \
    chown -R user:user $HOME && \
    chmod -R u+rwx $HOME

# Switch to the new user
USER user
WORKDIR $HOME

# Copy and install Python dependencies
COPY requirements.txt $HOME/requirements.txt
RUN pip3 install --no-cache-dir -r $HOME/requirements.txt
RUN pip3 install git+https://github.com/karllark/dust_attenuation.git
RUN pip3 install "grizli[jwst]"

# Clone repositories and build
RUN  git clone https://github.com/SAOImageDS9/SAOImageDS9.git && \
    cd SAOImageDS9 && \
    unix/configure && \
    make && \
    cd $HOME && \
    git clone https://github.com/ericmandel/xpa.git  && \
    cd xpa && \
    ./configure --prefix=$HOME/Bin && \
    make && \
    make install && \
    make clean && \
    cd $HOME && \ 
    git clone https://github.com/ericmandel/pyds9.git 

COPY pyds9_setup.py $HOME/pyds9/pyds9_setup.py

RUN cd $HOME && \
    cd pyds9 && \
    mv setup.py setup.py_orig && \
    python3 pyds9_setup.py install --user && \
    cd $HOME && \
    git clone https://github.com/cconroy20/fsps.git && \
    git clone https://github.com/Luloisshen/grizli_visual_tool


# Run the grizli installation script
COPY grizli_setup.py $HOME/grizli_setup.py
RUN python3 $HOME/grizli_setup.py

# Clean up build dependencies
USER root
RUN apt-get purge -y build-essential libssl-dev libffi-dev \
    python3-dev make git libx11-dev libxt-dev libcfitsio-dev \
    libreadline-dev libgsl-dev libfftw3-dev gfortran \
    && apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

# Expose the Jupyter Notebook port
EXPOSE 8888

# Default command to start Jupyter Notebook
#CMD ["jupyter-notebook", "--ip=0.0.0.0", "--allow-root","--NotebookApp.token=''"]
