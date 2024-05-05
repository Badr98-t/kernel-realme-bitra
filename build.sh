#!/bin/bash
sudo apt update && sudo -H apt-get install bc python2 ccache binutils-aarch64-linux-gnu cpio

kernel_dir="${PWD}"
CCACHE=$(command -v ccache)
objdir="${kernel_dir}/out"
anykernel=$HOME/anykernel
builddir="${kernel_dir}/build"
ZIMAGE=$kernel_dir/out/arch/arm64/boot/Image
kernel_name="Zorok-bitra"
zip_name="$kernel_name-$(date +"%d%m%Y-%H%M").zip"
TC_DIR=$HOME/tc
CLANG_DIR=$HOME/tc/clang-r498229b
export CONFIG_FILE="vendor/sm8250_defconfig"
export ARCH="arm64"
export KBUILD_BUILD_HOST=badr
export KBUILD_BUILD_USER=home

export PATH="$CLANG_DIR/bin:$PATH"

# Kernel defconfig
DEFCONFIG=vendor/sm8250_defconfig

# AnyKernel3 directory
ANYKERNEL3_DIR=$KERNEL_DIR/anykernel

# Compiler cleanup
COMPILER_CLEANUP=true

# Cleanup
CLEANUP=true

# Release Repo
RELEASE_REMOTE=$(git remote)
RELEASE_REPO=$(git ls-remote --get-url $RELEASE_REMOTE)

# Files
IMAGE=$KERNEL_DIR/out/arch/arm64/boot/Image
DTBO=$KERNEL_DIR/out/arch/arm64/boot/dtbo.img
DTB=$KERNEL_DIR/out/arch/arm64/boot/dtb

# Verbose Build
VERBOSE=0

# Kernel Version
KERVER=$(make kernelversion)

# Specify Final Zip Name
ZIPNAME=Zorok

# Zip version
VERSION=$(cat $KERNEL_DIR/Version)

# Specify compiler
COMPILER=neutron

# Sigint detection
SIGINT_DETECT=0

# Start build
BUILD_START=$(date +"%s")
nocol='\033[0m'
red='\033[0;31m'
green='\033[0;32m'
orange='\033[0;33m'
blue='\033[0;34m'
magenta='\033[0;35m'
cyan='\033[0;36m'

# Startup
echo -e "$cyan***********************************************"
echo    "              STARTING THE ENGINE              "
echo -e "***********************************************$nocol"

##----------------------------------------------------------##
# Clone ToolChain
function cloneTC() {
    case $COMPILER in
        proton)
            if [ $COMPILER_CLEANUP = true ]; then
                rm -rf ~/Zorok/neutron-clang
            fi
            if [ $(ls $HOME/Zorok/proton-clang 2>/dev/null | wc -l) -ne 0 ]; then
                PATH="$HOME/Zorok/proton-clang/bin:$PATH"
            else
                git clone --depth=1  https://github.com/kdrag0n/proton-clang.git ~/Zorok/proton-clang
                PATH="$HOME/Zorok/proton-clang/bin:$PATH"
            fi
            ;;
        neutron)
            if [ $COMPILER_CLEANUP = true ]; then
                rm -rf ~/Zorok/proton-clang
            fi
            if [ $(ls $HOME/Zorok/neutron-clang/bin 2>/dev/null | wc -l ) -ne 0 ] && 
               [ $(find $HOME/Zorok/neutron-clang -name *.tar.zst | wc -l) -eq 0 ]; then
                PATH="$HOME/Zorok/neutron-clang/bin:$PATH"
            else
                rm -rf ~/Zorok/neutron-clang
                mkdir -p ~/Zorok/neutron-clang
                cd ~/Zorok/neutron-clang || exit
                curl -LO "https://raw.githubusercontent.com/Neutron-Toolchains/antman/main/antman"
                chmod a+x antman
                ./antman -S
                cd - || exit
                PATH="$HOME/Zorok/neutron-clang/bin:$PATH"
            fi
            ;;
    esac
}
	
##------------------------------------------------------##
# Export Variables
function exports() {
    # Export KBUILD_COMPILER_STRING
    export KBUILD_COMPILER_STRING=$($HOME/Zorok/$COMPILER-clang/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')

    # Export ARCH and SUBARCH
    export ARCH=arm64
    export SUBARCH=arm64

    # Export KBUILD HOST and USER
    export KBUILD_BUILD_HOST=Badr98-t
    export KBUILD_BUILD_USER=badr98-t

    # Export PROCS and DISTRO
    export PROCS=$(nproc --all)
    export DISTRO=$(source /etc/os-release && echo "$NAME")
}

##----------------------------------------------------------##
# Sigint handler
function sigint() {
    SIGINT_DETECT=1
}

##----------------------------------------------------------##
# Compilation choices
function choices() {
    echo -e "$green***********************************************"
    echo    "                BUILDING KERNEL                "
    echo -e "***********************************************$nocol"

    # KernelSU
    read -p "Include KernelSU? If unsure, say N. (Y/N) " KSU_RESP 
    case $KSU_RESP in
        [yY] )
            if [ $(ls $KERNEL_DIR/KernelSU 2>/dev/null | wc -l) -eq 0 ]; then
                rm -rf $KERNEL_DIR/KernelSU
                git submodule update --init --recursive KernelSU
            elif [ $(ls $KERNEL_DIR/KernelSU 2>/dev/null | wc -l) -ne 0 ]; then
            	ZIPNAME=Zorok-KernelSU
            	KSU_CONFIG=ksu.config
            	if [ $(grep -c "KSU" arch/arm64/configs/$DEFCONFIG) -eq 0 ]; then
                    sed -i "s/-Zorok/-Zorok-$VERSION-KSU/" arch/arm64/configs/$DEFCONFIG
            	fi
            fi
            ;;
         *)
            if [ $(grep -c $VERSION arch/arm64/configs/$DEFCONFIG) -eq 0 ]; then
                sed -i "s/-Zorok/-Zorok-$VERSION/" arch/arm64/configs/$DEFCONFIG
            fi
            ;;
    esac

    # Clean build
    read -p "Do you want to do a clean build? If unsure, say N. (Y/N) " CLEAN_RESP 
    case $CLEAN_RESP in
        [yY] )
            make O=out clean && make O=out mrproper
            ;;
    esac
    
    # Interrupt detected
    if [ $SIGINT_DETECT -eq 1 ]; then
        if [ $(grep -c "KSU" arch/arm64/configs/$DEFCONFIG) -ne 0 ]; then
            sed -i "s/-Zorok-$VERSION-KSU/-Zorok/" arch/arm64/configs/$DEFCONFIG
        fi
        if [ $(grep -c $VERSION arch/arm64/configs/$DEFCONFIG) -ne 0 ]; then
            sed -i "s/-Zorok-$VERSION/-Zorok/" arch/arm64/configs/$DEFCONFIG
        fi
        exit
    fi
}

##----------------------------------------------------------##
# Compilation process
function compile() {
    # Make kernel	
    make O=out CC=clang ARCH=arm64 $DEFCONFIG $KSU_CONFIG savedefconfig
    make -kj$(nproc --all) O=out \
    ARCH=arm64 \
    LLVM=1 \
    LLVM_IAS=1 \
    CLANG_TRIPLE=aarch64-linux-gnu- \
    CROSS_COMPILE=aarch64-linux-android- \
    CROSS_COMPILE_COMPAT=arm-linux-androideabi- \
    AR=llvm-ar \
    NM=llvm-nm \
    OBJCOPY=llvm-objcopy \
    OBJDUMP=llvm-objdump \
    STRIP=llvm-strip \
    V=$VERBOSE 2>&1 | tee out/error.log

    # KernelSU
    if [ $ZIPNAME = Zorok-KernelSU ]; then
        sed -i 's/CONFIG_KSU=y/# CONFIG_KSU is not set/g' out/.config
        sed -i '/CONFIG_KSU=y/d' out/defconfig
        sed -i "s/-Zorok-$VERSION-KSU/-Zorok/" out/defconfig out/.config arch/arm64/configs/$DEFCONFIG
        
        if [ $(grep -c "# KernelSU" arch/arm64/configs/$DEFCONFIG) -eq 1 ]; then
            sed -i 's/CONFIG_KSU=y/# CONFIG_KSU is not set/g' arch/arm64/configs/$DEFCONFIG
        else   
            sed -i '/CONFIG_KSU=y/d' arch/arm64/configs/$DEFCONFIG
        fi
    else
        sed -i "s/-Zorok-$VERSION/-Zorok/" out/defconfig out/.config arch/arm64/configs/$DEFCONFIG
    fi

    # Verify build
    if [ $(grep -c "Error 2" out/error.log) -ne 0 ] || [ $SIGINT_DETECT -eq 1 ]; then 
        echo ""
        echo -e "$red***********************************************"
        echo    "           KERNEL COMPILATION FAILED           "
        echo -e "***********************************************$nocol"
        exit 1
    else
        echo -e "$green***********************************************"
        echo    "          KERNEL COMPILATION FINISHED          "
        echo -e "***********************************************$nocol"  
    fi
}
##----------------------------------------------------------##

function zipping() {
    # Copying kernel essentials
    cp $IMAGE $DTBO $DTB $ANYKERNEL3_DIR

    echo -e "$magenta***********************************************"
    echo    "                Time to zip up!                "
    echo -e "***********************************************$nocol"

    # Cleanup
    if [ $CLEANUP = true ]; then
        rm -rf out/*.zip
    fi

    # Make zip and transfer it to out directory
    cd $ANYKERNEL3_DIR/
    FINAL_ZIP=$ZIPNAME-$VERSION-$(date +%y%m%d-%H%M).zip
    zip -r9 "../out/$FINAL_ZIP" * -x README $FINAL_ZIP

    # Clean AnyKernel3 directory
    cd ..
    rm -rf $ANYKERNEL3_DIR/Image $ANYKERNEL3_DIR/Image.* $ANYKERNEL3_DIR/dtbo.img $ANYKERNEL3_DIR/dtb

    if [ $(find out/ -name $FINAL_ZIP | wc -l) -ne 0 ]; then
        echo -e "$orange***********************************************"
        echo    "            Done, here is your sha1            "
        echo -e "***********************************************$nocol"
        sha1sum out/$FINAL_ZIP

        # Github release
        read -p "Do you want to do a github release? If unsure, say N. (Y/N) " GIT_RESP 
        case $GIT_RESP in
            [yY] )
                gh release create $VERSION out/$FINAL_ZIP --repo $RELEASE_REPO --title Zorok-$VERSION
                ;;
            *)
                read -p "Do you want to upload files to the current github release? If unsure, say N. (Y/N) " UPLOAD_RESP 
                case $UPLOAD_RESP in
                    [yY] )
                        gh release upload $VERSION out/$FINAL_ZIP --repo $RELEASE_REPO
                        ;;
                esac
                ;;
        esac

        echo -e "$cyan***********************************************"
        echo    "                  All done !!                  "
        echo -e "***********************************************$nocol"
    else
        echo ""
        echo -e "$red***********************************************"
        echo    "                ZIPPING FAILED!                "
        echo -e "***********************************************$nocol"
        exit 1
    fi
fi

# Colors
NC='\033[0m'
RED='\033[0;31m'
LRD='\033[1;31m'
LGR='\033[1;32m'

make_defconfig()
{
    START=$(date +"%s")
    echo -e ${LGR} "########### Generating Defconfig ############${NC}"
    make -s ARCH=${ARCH} O=${objdir} ${CONFIG_FILE} -j$(nproc --all)
}
compile()
{
    cd ${kernel_dir}
    echo -e ${LGR} "######### Compiling kernel #########${NC}"
    make -j$(nproc --all) \
    O=out \
    ARCH=${ARCH}\
    CC="ccache clang" \
    CLANG_TRIPLE="aarch64-linux-gnu-" \
    CROSS_COMPILE="aarch64-linux-gnu-" \
    CROSS_COMPILE_ARM32="arm-linux-gnueabi-" \
    LLVM=1 \
    LLVM_IAS=1
}

completion()
{
    cd ${objdir}
    COMPILED_IMAGE=arch/arm64/boot/Image
    COMPILED_DTBO=arch/arm64/boot/dtbo.img
    if [[ -f ${COMPILED_IMAGE} && ${COMPILED_DTBO} ]]; then

        git clone -q https://github.com/Badr98-t/AnyKernel3.git -b master $anykernel

        mv -f $ZIMAGE ${COMPILED_DTBO} $anykernel

        cd $anykernel
        find . -name "*.zip" -type f
        find . -name "*.zip" -type f -delete
        zip -r AnyKernel.zip *
        mv AnyKernel.zip $zip_name
        mv $anykernel/$zip_name $HOME/$zip_name
        rm -rf $anykernel
        END=$(date +"%s")
        DIFF=$(($END - $START))
        #curl --upload-file $HOME/$zip_name https://free.keep.sh; echo
        #rm $HOME/$zip_name
        echo -e ${LGR} "############################################"
        echo -e ${LGR} "############# OkThisIsEpic!  ##############"
        echo -e ${LGR} "############################################${NC}"
        exit 0
    else
        echo -e ${RED} "############################################"
        echo -e ${RED} "##         This Is Not Epic :'(           ##"
        echo -e ${RED} "############################################${NC}"
        exit 1
    fi
}
make_defconfig
compile
completion
cd ${kernel_dir}