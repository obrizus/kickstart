
# This "toolbox.sh" is a collection of common tools
# used to build and test an entire bootable Linux system.


#TODO kernel
#make allnoconfig
#General setup ---> Initial RAM filesystem and RAM disk (initramfs/initrd) support
#Executable file formats / Emulations ---> Kernel support for ELF binaries

#TODO busybox
#build ${BUSYBOX_FILE}-${BUSYBOX_VERSION} allnoconfig xconfig
#Busybox Settings ---> Build Options ---> Build BusyBox as a static binary (no shared libs)
#Add needed tools...


# Environment setup
WORK_DIR="${PWD}"
OUTPUT_DIR="${WORK_DIR}/output"
DOWNLOAD_DIR="${WORK_DIR}/download"
BUILD_DIR="${OUTPUT_DIR}/build"
STAGING_DIR="${OUTPUT_DIR}/staging"
TARGET_DIR="${OUTPUT_DIR}/target"
IMAGES_DIR="${OUTPUT_DIR}/images"
LOGFILE="${WORK_DIR}/minux.log"


function message {
  echo "${1}"
}

declare -a on_exit_items

function on_exit()
{
    for i in "${on_exit_items[@]}"
    do
        echo "on_exit: $i"
        eval $i
    done
}

function add_on_exit()
{
    local n=${#on_exit_items[*]}
    on_exit_items[$n]="$*"
    if [[ $n -eq 0 ]]; then
        echo "Setting trap"
        trap on_exit EXIT
    fi
}

function finish {
  clean
  message "Have a nice day!"
}
trap finish EXIT

function quit {
  message "${1}"
  exit "${2}"
}

#TODO: Read and understand die()
die() { echo >&2 -e "\nERROR: $@\n"; exit 1; }

function fail {
  local COMMAND="${1}"
  local ERROR_CODE="${2}"
  quit "ERROR: Command [${COMMAND}] failed with error code ${ERROR_CODE}" "${ERROR_CODE}"
}

function try {
  local RUN_COMMAND="${*}"
  eval "${RUN_COMMAND}" &>> "${LOGFILE}"
  local STATUS="${?}"
  [ "${STATUS}" -eq 0 ] || fail "${RUN_COMMAND}" "${STATUS}"
#  return "${STATUS}"
#  
}

#TODO: Fix exist() function
function exist {
  if [ -e "$1" ]
  then
    return true
  else
    return false
  fi
}

function folder {
  for NEW_FOLDER in "${*}"
  do
    try mkdir -p "${NEW_FOLDER}"
  done
}

function copy {
  local SOURCE="${1}"
  local DEST="${2}"
  local DEST_DIR="$(dirname ${DEST})"
#  cd -
  [ -d "${DEST_DIR}" ] || folder "${DEST_DIR}"
  try cp -ar "${SOURCE}" "${DEST}"
#  cd -
}

function remove {
  for ITEM in "${*}"
  do
    if [ -e "${ITEM}" ]
    then
      local CURRENT_DIR="$(dirname ${ITEM})"
      local ITEM_NAME="$(basename ${ITEM})"
      local TEMP_ITEM="${CURRENT_DIR}/.${ITEM_NAME}-${RANDOM}"
      try mv "${ITEM}" "${TEMP_ITEM}"
      try rm -rf "${TEMP_ITEM}" &
    fi
  done
}

function fetch {
  local FILE_URL="$1"
  local FILE_NAME="$(basename ${FILE_URL})"
  local DIR_NAME="${FILE_NAME%.*.*}"

  folder "${BUILD_DIR}"

  # Look for source files
  if [ -d "${BUILD_DIR}/${DIR_NAME}" ]; then
    message "Using existing ${DIR_NAME}!"
  else

    # Look for source package
    if [ -e "${BUILD_DIR}/${FILE_NAME}" ]; then
      message "Using existing ${FILE_NAME}!"
    else
      # Download package
      message "Downloading ${FILE_NAME}"
      try wget -t3 "${FILE_URL}" -O "${BUILD_DIR}/${FILE_NAME}.part"
      try mv "${BUILD_DIR}/${FILE_NAME}.part" "${BUILD_DIR}/${FILE_NAME}"
    fi

    # Extract package
    message "Exracting ${FILE_NAME}"
    tar xf "${BUILD_DIR}/${FILE_NAME}" -C "${BUILD_DIR}" || fail "tar xf ${BUILD_DIR}/${FILE_NAME} -C ${BUILD_DIR}" 1
  fi
}

function config {
  local DIR_NAME="$1"
  local BUILD_CONFIG="$2"
  local CONFIG_MENU="$3"

  try cd "${BUILD_DIR}/${DIR_NAME}"
  message "Configuring ${DIR_NAME} (${BUILD_CONFIG})"
  try make "${BUILD_CONFIG}"
  if [ "${CONFIG_MENU}" ]; then
    try make "${CONFIG_MENU}"
  fi
  try cd "${WORK_DIR}"
}

function build {
  local DIR_NAME="${1}"
  local BUILD_OPTION="${2}"
  local COMPILE_PROCESSES="$(($(nproc)+1))"

  try cd "${BUILD_DIR}/${DIR_NAME}"
  message "Building ${DIR_NAME} (${LDFLAGS})"
  try make "-j${COMPILE_PROCESSES}"
  if [ "${BUILD_OPTION}" ]; then
    try make "${BUILD_OPTION}"
  fi
  try cd "${WORK_DIR}"
}

function clean {
  read -p "Clean up (y/N)?" CHOISE
  case $CHOISE in
    y|Y|yes|YES|Yes )
      # Clean up
      remove ${BUILD_DIR}
      remove ${STAGING_DIR}
      remove ${TARGET_DIR}
      remove ${LOGFILE}
    ;;
    * ) message "Cleanup skipped";;
  esac
}

function run {
  read -p "Test image files (Y/n)?" CHOISE
  case $CHOISE in
    n|N|no|NO|No ) message "Test skipped";;
    * ) 
      # Test images
      local KERNEL="${1}"
      local ROOTFS="${2}"
      try qemu -kernel "${KERNEL}" -initrd "${ROOTFS}" -append "panic=10"
    ;;
  esac
}

# Clear old files
remove ${LOGFILE}
try touch ${LOGFILE}
remove ${TARGET_DIR}

