#!/bin/bash
# generate the *.spk file (without the help of the toolkit)

# non-UTF-8 files with international characters and Windows-CR-LF may cause problems. Detect such files ...
# recursive calls for sub directories
checkCoding() {
  for f in "${1}"*; do
    if [[ -d "$f" ]]; then
      checkCoding "${f}/" # recursive do sub directory
    else
      res=$(file -b "$f")
      ret=$?
      # echo "  File coding check '$f' result $ret: $res"
      if [[ $res == *"CRLF line terminators"* ]]; then
        echo "  File coding check '$f' result $ret: $res"
        echo "  ######## Windows line terminator need to be converted to Unix! #########"
        ((errCnt=errCnt+1))
      elif [[ "$res" == *"ISO-8859 text"* ]]; then
        echo "  File coding check '$f' result $ret: $res"
        echo "  ######## Please convert to UTF-8! ##########"
        ((errCnt=errCnt+1))
      elif [[ "$res" == *"PNG image"* ]]; then
        echo "  File coding check PNG image '$f' result $ret: $res"
        # are there some PNG formats which need to be converted?
      fi
    fi
  done
}


######################### start ###########################

# shellcheck disable=SC2164
SCRIPTPATHbuild="$( cd -- "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 ; /bin/pwd -P )"
PKG_DIR="$SCRIPTPATHbuild"
# shellcheck disable=SC2164
cd "$PKG_DIR"
echo "'${BASH_SOURCE[0]}' started ..."


# non-UTF-8 files with international characters and Windows-CR-LF may cause problems.
# Detect such files by checking all source files ...
echo "File coding check ..."
# checkCoding needs the 'file' command, which is e.g. in "SynoCli File Tools":
res=$(which "file")
if [[ -n "$res" ]]; then
  checkCoding "$SCRIPTPATHbuild/"
else
  echo "=================================================================================================================="
  echo "Linux command 'file' is not available. Checking source files for correct line terminator and UTF-8-coding skipped!"
  echo "The 'file' command is part of the package 'SynoCli File Tools'! You may install that from https://packages.synocommunity.com/"
  echo "=================================================================================================================="
fi
echo "... finished file coding check"
ret=0
# "$(./translate.sh)" # Update tranlations via DeepL if necessary
# /bin/bash ./translate.sh
# ret=$?
if [[ "$ret" -gt 0 ]]; then
  exit $ret
fi

if [[ -f "INFO.sh" ]]; then
  infoFile="INFO.sh"
elif [[ -f "INFO" ]]; then
  infoFile="INFO"
else
  echo "=================================================================================================================="
  echo "Error: Neither the file INFO.sh nor INFO foun in folder '$PKG_DIR'"
  echo "=================================================================================================================="
  exit 2
fi
### get the version and the package name from INFO.sh or INFO:
line=$(grep -i "VERSION=" "$infoFile")
echo "line with version: '$line'" # e.g. version="0.0.0-0009"
line="${line^^}" # toUpper
eval "$line"
line="$(grep -i "package=" "$infoFile")" # e.g. package="callmonitor"
line="${line#*package=\"}"
pck="${line%%\"*}"
# pck=$(grep -i "package=" "$infoFile" | /bin/sed -e 's/package=//i' -e 's/"//g')
echo "pck='$pck'"
dsmuidir=""
line="$(grep "dsmuidir=" "$infoFile")" # most often dsmuidir="ui"
eval "$line"
echo "dsmuidir='$dsmuidir'"

# Check for well formed JSON:
errCnt=0
for f1 in "package/$dsmuidir/config" "package/$dsmuidir/index.conf" "package/$dsmuidir/helptoc.conf" conf/* WIZARD_UIFILES/*.json WIZARD_UIFILES/uninstall_uifile_*
# for f1 in package/$dsmuidir/config package/$dsmuidir/index.conf conf/* WIZARD_UIFILES/uninstall_uifile* WIZARD_UIFILES/wizard_*.json
do
  f2="$SCRIPTPATHbuild/$1$f1"
  if [[ -f "$f2" ]]; then
    # res=$(cat "$f2" | python3 -mjson.tool)
    res=$(python3 -mjson.tool < "$f2")
    ret=$?
    echo "JSON syntax check '$f2': $ret"
    if [[ "$ret" != 0 ]]; then
      echo "#### !!!!!! JSON syntax error in '$f2'!!!!! #####"
      ((errCnt=errCnt+1))
    fi
    if [[ "$f1" == "package/$dsmuidir/helptoc.conf" ]]; then
      line="$(grep "helptoc.conf" "conf/resource")"
      if [[ $line == "" ]]; then
        echo "$f1 is available, but not used in conf/resource!!!"
        ((errCnt=errCnt+1))      
      fi       
    else
      if [[ -f "conf/resource.own" ]];then
        diff -q "conf/resource.own" "conf/resource.own"
        res=$?
        if [[ "$res" -ne "0" ]]; then
          echo "The file conf/resource.own is different from conf/resource. They should be identically"
          ((errCnt=errCnt+1))      
        fi  
      else
        # https://www.synology-forum.de/wiki/Integration_einer_Hilfe_in_DSM_5.1-
        echo "There was no file conf/resource.own. Without that the Help may not be inserted in DSM help. Created now as copy from conf/resource!"
        cp "conf/resource" "conf/resource.own"
      fi
    fi
  else
    echo "$f2 ($f1) not found!"
    if [[ "$f1" == "package/$dsmuidir/helptoc.conf" ]]; then
      line="$(grep "helptoc.conf" "conf/resource")"
      if [[ $line != "" ]]; then
        echo "  but used in conf/resource"
        ((errCnt=errCnt+1))
      else
        echo "  (optional)"
      fi       
    elif [[ $(basename "$f1") == "@eaDir" ]]; then
      echo "  (ignored)"
    elif [[ "$f1" =~ "WIZARD_UIFILES/"* ]]; then
      echo " not used? (ignored!)"
    else  
      echo " ==> Error!"
      ((errCnt=errCnt+1))
    fi
  fi
done

if [[ "$errCnt" -gt "0" ]]; then
  echo "Stopped due to errCnt=$errCnt"
  exit 2
fi

# Workaround für falsches $SYNOPKG_PKGVER (altes!) während der Ausführung von pgrade_uifile.sh
sed -i "s/VERSION_NOW=.*\$/VERSION_NOW=\"${VERSION}\"/" WIZARD_UIFILES/uifile.sh

# shellcheck disable=2153
echo "building V$VERSION of $pck ..."
# echo "Actual working directory is $PKG_DIR"
rm -f "package.tgz"
rm -f "${pck}-$VERSION.spk"
echo "changing permissions (not permitted for .../@eaDir folders is supressed) ..."
chmod -R 777 package 2>&1 | grep -v "/@eaDir'"
echo -e "...done\nbuilding package.tgz ..."
# shellcheck disable=SC2164
(
  cd package
# tar --exclude="@eaDir" --owner=0 --group=0 -czvvf ../package.tgz *
tar --exclude="@eaDir" --exclude="Thumbs.db" --owner=0 --group=0 -czvvf ../package.tgz ./*
) # cd ..
# chmod 777 package.tgz
path="package/$dsmuidir/images"
cp -av "$path/icon_64.png" "PACKAGE_ICON.PNG"
p256=""
if [[ -f "$path/icon_256.png" ]]; then
  p256="PACKAGE_ICON_256.PNG"
  cp -av "$path/icon_256.png" "PACKAGE_ICON_256.PNG"
  # during package installation the icons will be inserted to the INFO file
fi
chmod 755 INFO.sh
if [[ -f INFO.sh ]]; then
  rm -f "INFO"
  echo "Executing now INFO.sh to build INFO file ..."
  source INFO.sh NoToolkitScripts
  chmod 755 INFO
  echo "create_time=\"$(date '+%Y-%m-%d %T')\"" >> INFO
  echo "... INFO.sh done."
fi
echo "... package.tgz done"

echo "building ${pck}-$VERSION.spk ..."
chmod 700 package.tgz
# --exclude="Thumbs.db" --exclude="Browse.plb"
license=""
if [[ -f "LICENSE*" ]]; then
  license="LICENSE*"
fi
# tar --exclude="*/@eaDir" --owner=0 --group=0 -cvvf "${pck}-$VERSION.spk" INFO CHANGELOG $license PACKAGE_ICON.PNG "$p256" WIZARD_UIFILES conf scripts package.tgz
# shellcheck disable=2086
tar --exclude="*/@eaDir" --owner=0 --group=0 -cvvf "${pck}-$VERSION.spk" INFO $license PACKAGE_ICON.PNG "$p256" WIZARD_UIFILES conf scripts package.tgz
rm "package.tgz"
rm "INFO"
rm "PACKAGE_ICON.PNG"
rm "PACKAGE_ICON_256.PNG"
# chmod 777 ${pck}-$VERSION.spk
echo "... ${BASH_SOURCE[0]} done, file $SCRIPTPATHbuild/${pck}-$VERSION.spk generated!"

