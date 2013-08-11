#!/bin/sh
# You may need to change the next line to an absolute path.
ROOT_DIR=/usr/share/java/bt747
if [ -z "$ROOT_DIR" ] ; then ROOT_DIR="." ; fi

# Select the most appropriate Java
which java >/dev/null 2>&1 && JAVA=java
which javaw >/dev/null 2>&1 && JAVA=javaw

# Start setting the class path.
export CLASSPATH
CLASSPATH="${ROOT_DIR}/lib/jchart2d-3.1.0.jar:$CLASSPATH"
CLASSPATH="${ROOT_DIR}/lib/jopt-simple-2.4.1.jar:$CLASSPATH"
CLASSPATH="${ROOT_DIR}/lib/jcalendar-1.3.2.jar:$CLASSPATH"
CLASSPATH="${ROOT_DIR}/lib/swing-layout-1.0.3.jar:$CLASSPATH"
CLASSPATH="${ROOT_DIR}/lib/swingx.jar:$CLASSPATH"
CLASSPATH="${ROOT_DIR}/lib/swingx-ws.jar:$CLASSPATH"
CLASSPATH="${ROOT_DIR}/dist/libBT747.jar:$CLASSPATH"
CLASSPATH="${ROOT_DIR}/dist/BT747_j2se.jar:$CLASSPATH"

 ########################
 # Finding RXTX library
 RXTXPATH="${ROOT_DIR}/lib/rxtx-2.1-7-bins-r2"
  # ARCH=`arch`  # The old way
 ARCH=`"$JAVA" -jar "${ROOT_DIR}/dist/BT747_j2se.jar" arch`
 if [ $ARCH = 'amd64' ] ; then
   # Substitute for equivalent architecture.
   ARCH=x86_64
   # Use new library if available.
   TSTRXTXPATH="${ROOT_DIR}/lib/rxtx-2.2pre2-bins"
   if [ -d "${TSTRXTXPATH}" ] ; then
     RXTXPATH="${TSTRXTXPATH}"
   fi
 fi
 RXTXLIBPATH="${RXTXPATH}/Linux/i686-unknown-linux-gnu"
 TMPRXTXPATH="${RXTXPATH}/Linux/${ARCH}-unknown-linux-gnu"
 RXTXJAR="${RXTXPATH}/RXTXcomm.jar"
 if [ -r "${TMPRXTXPATH}" ] ; then
   RXTXLIBPATH="${TMPRXTXPATH}"
 else
  # Did not find binary - look on system.
  if [ -e /usr/share/java/rxtx/RXTXcomm.jar ] ; then
    # if librxtx-java seems to be installed locally (e.g., on Ubuntu)
    RXTXPATH=/usr/lib
    RXTXLIBPATH=/usr/lib
    RXTXJAR=/usr/share/java/rxtx/RXTXcomm.jar
  fi
 fi
 # Ended determining RXTX library
 ################################

CLASSPATH="${RXTXJAR}:$CLASSPATH"

# Change the port prefix by adding the following option to the java invocation:
#     (the example is for ports like /dev/ttyUSB0)
#  -Dbt747_prefix="/dev/ttyUSB" 
#
# It is possible to define the path to the configuration file
#       -Dbt747_settings="bt747settings.pdb"


#strace -e trace=file -f -o trace.log
MEM_HEAP_OPTION=-Xmx192m
#CLASSPATH="${RXTXPATH}/RXTXcomm-debug.jar:$CLASSPATH"
#DEBUG_OPTION='-Dgnu.io.log.mode=FILE_MODE'
"$JAVA" $MEM_HEAP_OPTION $DEBUG_OPTION -Djava.library.path="${RXTXLIBPATH}" -Dbt747_settings="$XDG_CONFIG_HOME/bt747/bt747settings.pdb" bt747.j2se_view.BT747Main $*
