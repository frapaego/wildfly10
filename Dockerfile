FROM centos:7
MAINTAINER Francisco José Páez Gordillo <frapaego@gmail.com>

# Install packages necessary to run EAP
RUN yum update -y && yum -y install xmlstarlet saxon augeas bsdtar unzip && yum clean all

ENV TZ=Europe/Madrid
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Create a user and group used to launch processes
# The user ID 1000 is the default for the first "regular" user on Fedora/RHEL,
# so there is a high chance that this ID will be equal to the current user
# making it easier to use volumes (no permission issues)
RUN groupadd -r jboss -g 1000 && useradd -u 1000 -r -g jboss -m -d /opt/jboss -s /sbin/nologin -c "JBoss user" jboss && \
    chmod 755 /opt/jboss

# Set the working directory to jboss' user home directory
WORKDIR /opt/jboss

# User root user to install software
USER root

ADD assets /assets
RUN chmod +rwx /assets

# Install necessary packages
RUN cd /assets && yum -y localinstall jdk-8u191-linux-x64.rpm && yum clean all

# Switch back to jboss user
USER jboss

# Set the JAVA_HOME variable to make it clear where Java is located
ENV JAVA_HOME /usr/java/jdk1.8.0_191-amd64

# Set the WILDFLY_VERSION env variable
ENV WILDFLY_VERSION 10.1.0.Final
ENV WILDFLY_SHA1 a387f2ebf1b902fc09d9526d28b47027bc9efed9
ENV JBOSS_HOME /opt/jboss/wildfly
ENV JBOSS_IP 0.0.0.0

USER root

# Add the WildFly distribution to /opt, and make wildfly the owner of the extracted tar content
# Make sure the distribution is available from a well-known place
RUN cd $HOME \
    && curl -O https://download.jboss.org/wildfly/$WILDFLY_VERSION/wildfly-$WILDFLY_VERSION.tar.gz \
    && tar xf wildfly-$WILDFLY_VERSION.tar.gz \
    && mv $HOME/wildfly-$WILDFLY_VERSION $JBOSS_HOME \
    && rm wildfly-$WILDFLY_VERSION.tar.gz \
    && chown -R jboss:0 ${JBOSS_HOME} \
    && chmod -R g+rw ${JBOSS_HOME} \
    && cp -rf /assets/configuration/standalone.xml ${JBOSS_HOME}/standalone/configuration \
    && chmod +x ${JBOSS_HOME}/standalone/configuration/standalone.xml \
    && cp -rf /assets/configuration/keystore.jks ${JBOSS_HOME}/standalone/configuration \
    && chmod +rx ${JBOSS_HOME}/standalone/configuration/keystore.jks \
    && cp -rf /assets/configuration/standalone.conf ${JBOSS_HOME}/bin \
    && chmod +x ${JBOSS_HOME}/bin/standalone.conf \
    && cd ${JBOSS_HOME}/modules/system/layers/base/com && unzip -o /assets/modules/oracle.zip \
    && chmod -R 755 ${JBOSS_HOME}/modules/system/layers/base/com

RUN rm -rf /assets

RUN ${JBOSS_HOME}/bin/add-user.sh --silent=true admin admin ManagementRealm

# Ensure signals are forwarded to the JVM process correctly for graceful shutdown
ENV LAUNCH_JBOSS_IN_BACKGROUND true

USER jboss

# Expose the ports we're interested in
EXPOSE 8080
EXPOSE 8443
EXPOSE 8787
EXPOSE 9990

# Set the default command to run on boot
# This will boot WildFly in the standalone mode and bind to all interface
CMD /opt/jboss/wildfly/bin/standalone.sh -b=$JBOSS_IP -bmanagement=$JBOSS_IP --debug 8787