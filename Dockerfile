FROM java:7
MAINTAINER mdouchement

ENV DEBIAN_FRONTEND noninteractive

# Refresh package lists
RUN apt-get update
RUN apt-get -qy dist-upgrade

RUN apt-get install -qy rsync curl openssh-server openssh-client vim

RUN mkdir -p /opt
WORKDIR /opt

# Install Hadoop
RUN curl -L http://apache.crihan.fr/dist/hadoop/common/hadoop-2.7.2/hadoop-2.7.2.tar.gz -s -o - | tar -xzf -
RUN mv hadoop-2.7.2 hadoop

# Setup
WORKDIR /opt/hadoop
ENV PATH /opt/hadoop/bin:/opt/hadoop/sbin:$PATH
ENV JAVA_HOME /usr/lib/jvm/java-7-openjdk-amd64
RUN sed --in-place='.ori' -e "s/\${JAVA_HOME}/\/usr\/lib\/jvm\/java-7-openjdk-amd64/" etc/hadoop/hadoop-env.sh

# Configure ssh client
RUN ssh-keygen -t dsa -P '' -f ~/.ssh/id_dsa && \
    cat ~/.ssh/id_dsa.pub >> ~/.ssh/authorized_keys && \
    chmod 0600 ~/.ssh/authorized_keys

RUN echo "\nHost *\n" >> ~/.ssh/config && \
    echo "   StrictHostKeyChecking no\n" >> ~/.ssh/config && \
    echo "   UserKnownHostsFile=/dev/null\n" >> ~/.ssh/config

# Disable sshd authentication
RUN echo "root:root" | chpasswd
RUN sed -i 's/PermitRootLogin without-password/PermitRootLogin yes/' /etc/ssh/sshd_config
# SSH login fix. Otherwise user is kicked off after login
RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd
# => Quick fix for enabling datanode connections
#    ssh -L 50010:localhost:50010 root@192.168.99.100 -p 22022 -o PreferredAuthentications=password 

# Pseudo-Distributed Operation
COPY etc/hadoop/core-site.xml etc/hadoop/core-site.xml
COPY etc/hadoop/hdfs-site.xml etc/hadoop/hdfs-site.xml
RUN hdfs namenode -format

# SSH
EXPOSE 22
# hdfs://localhost:9000
EXPOSE 9000
# HDFS namenode
EXPOSE 50020
# HDFS Web browser
EXPOSE 50070
# HDFS datanodes
EXPOSE 50075
# HDFS secondary namenode
EXPOSE 50090

CMD service ssh start && start-dfs.sh && bash
