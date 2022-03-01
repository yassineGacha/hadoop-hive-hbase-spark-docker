# Alpine 3.11 contains Python 3.8, pyspark only supports Python up to 3.7
FROM alpine:3.10.4

# curl and unzip: download and extract Hive, Hadoop, Spark etc.
# bash: Hadoop is not compatible with Alpine's `ash` shell
# openjdk8: Java
# coreutils: Spark launcher script relies on GNU implementation of `nice`
# procps: Hadoop needs GNU `ps` utility
# findutils: Spark needs GNU `find` to run jobs (weird but true)
# ncurses: so that you can run `yarn top`

# 修改alpine源，为国内清华镜像源
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.tuna.tsinghua.edu.cn/g' /etc/apk/repositories

RUN apk add \
    'curl=~7.66' \
    'unzip=~6.0' \
    'openjdk8=~8' \
    'bash=~5.0' \
    'coreutils=~8.31' \
    'procps=~3.3' \
    'findutils=~4.6' \
    'ncurses=~6.1' \
    'g++=~8.3' \
    'libc6-compat=~1.1' \
	tcl tk expect \
    && ln -s /lib64/ld-linux-x86-64.so.2 /lib/ld-linux-x86-64.so.2


# https://github.com/hadolint/hadolint/wiki/DL4006
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# for openrc 避免openrc 报文件只读错误，创建匿名数据卷
VOLUME [ "/sys/fs/cgroup" ]

# 设置alpine默认root密码
ENV ROOT_PWD=123456
# add ssh https://blog.csdn.net/Gekkoou/article/details/90430603
RUN apk update && \
    apk add openssh-server openssh-client openrc tzdata && \
    cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    rc-update add sshd && \
    mkdir -p /run/openrc && touch /run/openrc/softlevel && \
    openrc && \
    rc-status && \
    sed -i "s/#Port 22/Port 22/g" /etc/ssh/sshd_config && \
    sed -i "s/#PermitRootLogin.*/PermitRootLogin yes/g" /etc/ssh/sshd_config && \
    mkdir -p /root/.ssh && chmod 700 /root/.ssh/ && \
    ssh-keygen -t rsa -N '' -f /root/.ssh/id_rsa && \
    # /etc/init.d/sshd start && \
    service sshd restart && \
    echo "root:${ROOT_PWD}" | chpasswd && \
    # apk del tzdata && \
    rm -rf /var/cache/apk/* 

ENV USR_BIN_DIR=/usr/source_dir
RUN mkdir -p "${USR_BIN_DIR}"
# 使用本地的源文件，加快rebuild速度，方便调试
COPY tar-source-files/* "${USR_BIN_DIR}/"
WORKDIR "${USR_BIN_DIR}"
# 清华源镜像apache 地址： https://mirrors.tuna.tsinghua.edu.cn/apache/


# Hadoop
ENV HADOOP_VERSION=3.2.0
ENV HADOOP_HOME /usr/hadoop
ENV HADOOP_NNAMENADE_HOSTNAME=master
ENV HADOOP_PACKAGE="hadoop-${HADOOP_VERSION}.tar.gz"
# 国内加速地址，注意版本不全
# http://mirrors.aliyun.com/apache/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz
# 如果本地${USR_BIN_DIR}文件夹没有，则下载。
RUN if [ ! -f ${HADOOP_PACKAGE} ] ; then curl --progress-bar -L --retry 3 \
  "http://archive.apache.org/dist/hadoop/common/hadoop-${HADOOP_VERSION}/${HADOOP_PACKAGE}" -o "${USR_BIN_DIR}/${HADOOP_PACKAGE}" ; fi \
  && tar -xf "${USR_BIN_DIR}/${HADOOP_PACKAGE}" -C /usr/ \
  && mv "/usr/hadoop-${HADOOP_VERSION}" "${HADOOP_HOME}" \
  && rm -rf "${HADOOP_HOME}/share/doc" \
  && chown -R root:root "${HADOOP_HOME}"

# Hive
ENV HIVE_VERSION=3.1.2
ENV HIVE_HOME=/usr/hive
ENV HIVE_CONF_DIR="${HIVE_HOME}/conf"
ENV HIVE_LOG_DIR="${HIVE_HOME}/logs"
ENV HIVE_PACKAGE="apache-hive-${HIVE_VERSION}-bin.tar"
# 国内加速地址，注意版本不全
# http://mirrors.aliyun.com/apache/hive/hive-${HIVE_VERSION}/apache-hive-${HIVE_VERSION}-bin.tar.gz
# 如果本地${USR_BIN_DIR}文件夹没有，则下载。
RUN if [ ! -f "${HIVE_PACKAGE}" ]; then curl --progress-bar -L \
   "https://archive.apache.org/dist/hive/hive-${HIVE_VERSION}/${HIVE_PACKAGE}" -o "${USR_BIN_DIR}/${HIVE_PACKAGE}" ; fi \ 
   && tar -xf "${USR_BIN_DIR}/${HIVE_PACKAGE}" -C /usr/ \
   && mv "/usr/apache-hive-${HIVE_VERSION}-bin" "${HIVE_HOME}" \
   && chown -R root:root "${HIVE_HOME}" \
   && mkdir -p "${HIVE_HOME}/hcatalog/var/log" \
   && mkdir -p "${HIVE_HOME}/var/log" \
   && mkdir -p "${HIVE_HOME}/var/log" \
   && mkdir -p "${HIVE_LOG_DIR}" \
   && chmod 777 "${HIVE_HOME}/hcatalog/var/log" \
   && chmod 777 "${HIVE_HOME}/var/log" \
   && chmod 777 "${HIVE_LOG_DIR}"


ENV HBASE_VERSION=2.3.6
ENV HBASE_HOME=/usr/hbase
ENV HBASE_CONF_DIR="${HBASE_HOME}/conf/"
ENV PATH "${PATH}:${HBASE_HOME}/bin"
ENV HBASE_PACKAGE="hbase-${HBASE_VERSION}-bin.tar.gz"
# 如果需要网络下载，请删除RUN tar -xf "hbase-${HBASE_VERSION}-bin.tar.gz" -C /usr/ \行，并取消注释如下几行
# 国内加速地址，注意版本不全
# http://mirrors.aliyun.com/apache/hbase/${HBASE_VERSION}/hbase-${HBASE_VERSION}-bin.tar.gz
# 如果本地${USR_BIN_DIR}文件夹没有，则下载。
RUN if [ ! -f "${HBASE_PACKAGE}" ]; then curl --progress-bar -L \
  "http://archive.apache.org/dist/hbase/${HBASE_VERSION}/${HBASE_PACKAGE}" -o "${USR_BIN_DIR}/${HBASE_PACKAGE}" ; fi \
  && tar -xf "${USR_BIN_DIR}/${HBASE_PACKAGE}" -C /usr/ \
  && mv "/usr/hbase-${HBASE_VERSION}" "${HBASE_HOME}" \
  && chown -R root:root "${HBASE_HOME}"

  
# Spark
ENV SPARK_VERSION=2.4.5
ENV SPARK_HOME=/usr/spark
ENV SPARK_PACKAGE="spark-${SPARK_VERSION}-bin-without-hadoop.tgz"
# 国内加速地址，注意版本不全
# http://mirrors.aliyun.com/apache/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-without-hadoop.tgz
# 如果本地${USR_BIN_DIR}文件夹没有，则下载。
RUN if [ ! -f "${SPARK_PACKAGE}" ] ; then curl --progress-bar -L --retry 3 \
  "https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/${SPARK_PACKAGE}" -o "${USR_BIN_DIR}/${SPARK_PACKAGE}" ; fi \
  && tar -xf "${USR_BIN_DIR}/${SPARK_PACKAGE}" -C /usr/ \
  && mv "/usr/spark-${SPARK_VERSION}-bin-without-hadoop" "${SPARK_HOME}" \
  && chown -R root:root "${SPARK_HOME}"

# For inscrutable reasons, Spark distribution doesn't include spark-hive.jar
# Livy attempts to load it though, and will throw
# java.lang.ClassNotFoundException: org.apache.spark.sql.hive.HiveContext

ARG SCALA_VERSION=2.11
# 下载spark-hive jar包并复制到spark/jar目录下
# 如果本地${USR_BIN_DIR}文件夹没有，则下载。
ENV SPARK_HIVE_PACKAGE="spark-hive_${SCALA_VERSION}-${SPARK_VERSION}.jar"
RUN if [ ! -f "${SPARK_HIVE_PACKAGE}" ]; then curl --progress-bar -L \
    "https://repo1.maven.org/maven2/org/apache/spark/spark-hive_${SCALA_VERSION}/${SPARK_VERSION}/${SPARK_HIVE_PACKAGE}" \
    -o "${SPARK_HOME}/jars/${SPARK_HIVE_PACKAGE}" ; \
    else cp "${USR_BIN_DIR}/${SPARK_HIVE_PACKAGE}" "${SPARK_HOME}/jars/" ; fi

# PySpark - comment out if you don't want it in order to save image space
RUN apk add  \
    'python3=~3.7' \
    'python3-dev=~3.7' \
 && ln -s /usr/bin/python3 /usr/bin/python

 
# 原始的国内R语言源是：http://cran.us.r-project.org
# SparkR - comment out if you don't want it in order to save image space
RUN apk add  \
    'R=~3.6' \
    'R-dev=~3.6' \
    'libc-dev=~0.7' \
 && R -e 'install.packages("knitr", repos = "http://mirrors.tuna.tsinghua.edu.cn/CRAN")'

 
# Sqoop
ENV SQOOP_VERSION=1.4.7
ENV HADOOP_SQOOP_VERSION=2.6.0
ENV SQOOP_HOME=/usr/sqoop
ENV SQOOP_PACKAGE="sqoop-${SQOOP_VERSION}.bin__hadoop-${HADOOP_SQOOP_VERSION}.tar.gz"
# 国内加速地址，没有找到
# 如果本地${USR_BIN_DIR}文件夹没有，则下载。
RUN if [ ! -f "${SQOOP_PACKAGE}" ]; then curl --progress-bar -L --retry 3 \
  "http://archive.apache.org/dist/sqoop/${SQOOP_VERSION}/${SQOOP_PACKAGE}" -o "${USR_BIN_DIR}/${SQOOP_PACKAGE}" ; fi \
  && tar -xf "${USR_BIN_DIR}/${SQOOP_PACKAGE}" -C /usr/ \
  && mv "/usr/sqoop-${SQOOP_VERSION}.bin__hadoop-${HADOOP_SQOOP_VERSION}" "${SQOOP_HOME}" \
  && chown -R root:root "${SQOOP_HOME}" \
  && mkdir -p "${SQOOP_HOME}/logs"

# ZooKeeper此处只借用zk的Client，并不安装zk服务
ENV ZK_VERSION=3.6.3
ENV ZK_HOME=/usr/zookeeper
ENV ZK_CONF_DIR=${ZK_HOME}/conf
ENV ZK_PACKAGE="apache-zookeeper-${ZK_VERSION}-bin.tar.gz"
# 国内加速地址，注意版本不全
# http://mirrors.aliyun.com/apache/zookeeper/zookeeper-${ZK_VERSION}/apache-zookeeper-${ZK_VERSION}-bin.tar.gz
# 如果本地${USR_BIN_DIR}文件夹没有，则下载。
RUN if [ ! -f "${ZK_PACKAGE}" ]; then curl --progress-bar -L --retry 3 \
  "https://archive.apache.org/dist/zookeeper/zookeeper-${ZK_VERSION}/${ZK_PACKAGE}"  -o "${USR_BIN_DIR}/${ZK_PACKAGE}" ; fi \
  && tar -xf "${USR_BIN_DIR}/${ZK_PACKAGE}" -C /usr/ \
  && mv "/usr/apache-zookeeper-${ZK_VERSION}-bin" "${ZK_HOME}" \
  && chown -R root:root "${ZK_HOME}"

# Common settings
ENV JAVA_HOME "/usr/lib/jvm/java-1.8-openjdk"
ENV PATH="${PATH}:${JAVA_HOME}/bin"
# http://blog.stuart.axelbrooke.com/python-3-on-spark-return-of-the-pythonhashseed
ENV PYTHONHASHSEED 0
ENV PYTHONIOENCODING UTF-8
ENV PIP_DISABLE_PIP_VERSION_CHECK 1

# Hadoop setup
ENV PATH="${PATH}:${HADOOP_HOME}/bin"
ENV PATH="${PATH}:${HADOOP_HOME}/sbin"
ENV HDFS_NAMENODE_USER="root"
ENV HDFS_DATANODE_USER="root"
ENV HDFS_SECONDARYNAMENODE_USER="root"
ENV YARN_RESOURCEMANAGER_USER="root"
ENV YARN_NODEMANAGER_USER="root"
ENV LD_LIBRARY_PATH="${HADOOP_HOME}/lib/native:${LD_LIBRARY_PATH}"
ENV HADOOP_CONF_DIR="${HADOOP_HOME}/etc/hadoop"
ENV HADOOP_LOG_DIR="${HADOOP_HOME}/logs"
COPY conf/hadoop/core-site.xml "${HADOOP_CONF_DIR}"
COPY conf/hadoop/hadoop-env.sh "${HADOOP_CONF_DIR}"
COPY conf/hadoop/hdfs-site.xml "${HADOOP_CONF_DIR}"
COPY conf/hadoop/mapred-site.xml "${HADOOP_CONF_DIR}"
COPY conf/hadoop/workers "${HADOOP_CONF_DIR}"
COPY conf/hadoop/yarn-site.xml "${HADOOP_CONF_DIR}"


# For S3 to work. Without this line you'll get "Class org.apache.hadoop.fs.s3a.S3AFileSystem not found" exception when accessing S3 from Hadoop
ENV HADOOP_CLASSPATH="${HADOOP_HOME}/share/hadoop/tools/lib/*"

# Hadoop JVM crashes on Alpine when it tries to load native libraries.
# Solution? Delete those altogether.
# Alternatively, you can try and compile them
# https://hadoop.apache.org/docs/stable/hadoop-project-dist/hadoop-common/NativeLibraries.html
RUN mkdir "${HADOOP_LOG_DIR}"  \
 && rm -rf "${HADOOP_HOME}/lib/native"

# Hive setup
ENV PATH="${PATH}:${HIVE_HOME}/bin"
ENV HADOOP_CLASSPATH="${HADOOP_CLASSPATH}:${HIVE_HOME}/lib/*"
COPY conf/hive/hive-site.xml "${HIVE_CONF_DIR}/"
COPY conf/hive/hive-log4j2.properties "${HIVE_LOG_DIR}/"
COPY jdbc_drivers/* "${HIVE_HOME}/lib/"

# Spark setup
ENV PATH="${PATH}:${SPARK_HOME}/bin"
ENV SPARK_CONF_DIR="${SPARK_HOME}/conf"
ENV SPARK_LOG_DIR="${SPARK_HOME}/logs"
ENV SPARK_DIST_CLASSPATH="${HADOOP_CONF_DIR}:${HADOOP_HOME}/share/hadoop/tools/lib/*:${HADOOP_HOME}/share/hadoop/common/lib/*:${HADOOP_HOME}/share/hadoop/common/*:${HADOOP_HOME}/share/hadoop/hdfs:${HADOOP_HOME}/share/hadoop/hdfs/lib/*:${HADOOP_HOME}/share/hadoop/hdfs/*:${HADOOP_HOME}/share/hadoop/mapreduce/lib/*:${HADOOP_HOME}/share/hadoop/mapreduce/*:${HADOOP_HOME}/share/hadoop/yarn:${HADOOP_HOME}/share/hadoop/yarn/lib/*:${HADOOP_HOME}/share/hadoop/yarn/*"
COPY conf/hadoop/core-site.xml "${SPARK_CONF_DIR}"/
COPY conf/hadoop/hdfs-site.xml "${SPARK_CONF_DIR}"/
COPY conf/spark/spark-defaults.conf "${SPARK_CONF_DIR}"/


# HBase setup
ENV PATH="${PATH}:${HBASE_HOME}/bin"
ENV HBASE_LOG_DIR="${HBASE_HOME}/logs"
RUN echo "${HBASE_CONF_DIR}"
# RUN test -d "${HBASE_CONF_DIR}" 
# RUN echo "HBASE_CONF_DIR exist: $?"
COPY conf/hbase/hbase-env.sh "${HBASE_CONF_DIR}"/
COPY conf/hbase/hbase-site.xml "${HBASE_CONF_DIR}"/
COPY conf/hadoop/core-site.xml "${HBASE_CONF_DIR}"/
COPY conf/hadoop/hdfs-site.xml "${HBASE_CONF_DIR}"/
RUN echo "export JAVA_HOME=${JAVA_HOME}" >>  "${HBASE_CONF_DIR}/hbase-env.sh"

# Sqoop setup
ENV PATH="${PATH}:${SQOOP_HOME}/bin"
ENV HADOOP_COMMON_HOME="${HADOOP_HOME}"
ENV HADOOP_MAPRED_HOME="${HADOOP_HOME}"
ENV SQOOP_CONF_DIR="${SQOOP_HOME}/conf"
ENV SQOOP_LOG_DIR="${SQOOP_HOME}/logs"
COPY jdbc_drivers/* "${SQOOP_HOME}/lib/"
COPY conf/sqoop/* "${SQOOP_CONF_DIR}/"

# Spark with Hive
# TODO enable in Spark 3.0
#ENV SPARK_DIST_CLASSPATH=$SPARK_DIST_CLASSPATH:$HIVE_HOME/lib/*
#COPY conf/hive/hive-site.xml $SPARK_CONF_DIR/
#RUN ln -s $SPARK_HOME/jars/scala-library-*.jar $HIVE_HOME/lib \
#    && ln -s $SPARK_HOME/jars/spark-core_*.jar $HIVE_HOME/lib \
#    && ln -s $SPARK_HOME/jars/spark-network-common_*.jar $HIVE_HOME/lib

# Clean up
RUN rm -rf "${USR_BIN_DIR}"/* \
    && rm -rf "${HIVE_HOME}/examples" \
    && rm -rf "${SPARK_HOME}/examples/src"

# If both YARN Web UI and Spark UI is up, then returns 0, 1 otherwise.
HEALTHCHECK CMD curl -f http://host.docker.internal:8080/ \
    && curl -f http://host.docker.internal:8088/ || exit 1

# Multi tail for logging 多重日志合并服务
WORKDIR /
COPY scripts/ /scripts
RUN apk add  'linux-headers=~4.19' \
 && gcc /scripts/watchdir.c -o /scripts/watchdir \
 && chmod +x /scripts/*

# Entry point: start all services and applications.
COPY entrypoint.sh /
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]