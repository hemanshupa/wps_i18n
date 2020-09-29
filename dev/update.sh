#!/bin/bash

SED=sed
LUPDATE=lupdate-qt4

if [ "`uname`" != "Linux" ]; then
	SED=gsed
fi
if ! which lupdate-qt4 &> /dev/null; then
	LUPDATE=lupdate
fi

cur_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

while getopts c:p:l:h flag; do
	case $flag in
		c)
			CODING=$OPTARG
			;;
		p)
			PROJS=$OPTARG
			;;
		l)
			LNG=$OPTARG
			;;
		h)
			echo "Usage:"
			echo "$0 [-c Coding] [-p project] [-l language]"
			exit 0
			;;
		?)
			exit 1
			;;
	esac
done

if [ -z "$CODING" ] ; then
	if [ ! -z "$WPS_CODING" ] ; then
		CODING=$WPS_CODING
	else
		CODING=`readlink -f ../../..`
	fi
fi

LOCALES=`ls $cur_dir/../*/lang.conf | ${SED} 's#.*/\([a-zA-Z0-9_]*\)/lang.conf#\1#' | grep -v en_US`
if [ ! -z "$LNG" -a "$LNG" != "ALL" ]; then
	LOCALES=$LNG
fi

if [ -z "$PROJS" ]; then
	PROJS=`cat $cur_dir/projs | ${SED} -n 's/#.*$//;s/\[.*\]\s*\(\w*\):.*$/\1/p'`
fi

function kui2ts_update()
{
	if ! which kui2ts > /dev/null; then
		echo "Can not found kui2ts in path" >> /dev/stderr
		echo "You can find it in Coding/tools/kui2ts, build it first!" >> /dev/stderr
		exit 1
	fi
	${SED} "s/@prj@/$2/g;s/@locale@/$1/g" > /tmp/kui2ts.ini << EOF
Name=@prj@
Version=2

[Source]
Path=$CODING/shell2/resource/res
Files=

[Destination]
Path=$cur_dir/../@locale@/ts
TargetLang=@locale@

[Options]
Obsolete=false
LocationType=0
DefaultCodec=UTF-8
Silent=1
EOF
	kui2ts /tmp/kui2ts.ini
}

function make_dirs()
{
	local CODING=$1
	local dir=$2

	local dirs=$(echo $dir | tr ";" "\n")
	local result=""
	for d in ${dirs[@]} ; do
		result+="$CODING/$d "
	done

	echo $result
}

for l in $LOCALES
{
	if [ ! -d "$cur_dir/../$l/ts" ]; then
		continue
	fi

	echo -e "Updating $l.."

	for p in $PROJS
	{
		TYPE=`${SED} -n "/\<$p\>:/ s/^\[\(.*\)\].*$/\1/p" $cur_dir/projs`
		DIR=`${SED} -n "/\<$p\>:/ s/^.*:\s*\(.*\)$/\1/p" $cur_dir/projs`
		DIRS=`make_dirs $CODING $DIR`
		if [ "$TYPE" == "qt" ]; then
			${LUPDATE} -silent -locations none -codecfortr UTF-8 -target-language $l -recursive $DIRS -ts $cur_dir/../$l/ts/$p.ts &> /dev/null
		elif [ "$TYPE" == "core" ]; then
			# same as qt, but 
			${LUPDATE} -silent -locations none -codecfortr UTF-8 -target-language $l -recursive $DIRS -ts $cur_dir/../$l/ts/$p.ts 2>&1 | ${SED} '/lacks Q_OBJECT macro/d' >> /dev/stderr
		elif [ "$TYPE" == "kui" ]; then
			kui2ts_update $l $DIR
		elif [ "$TYPE" == "plugins" ]; then
			if [ ! -d "$CODING/$DIR/mui/$l/ts" ]; then
				continue
			fi
			${LUPDATE} -silent -locations none -codecfortr UTF-8 -target-language $l -recursive $CODING/$DIR -ts $CODING/$DIR/mui/$l/ts/$p.ts &> /dev/null
			if [ -e "$CODING/$DIR/tips.h" ]; then
				${LUPDATE} -silent -locations none -codecfortr UTF-8 -target-language $l -recursive $CODING/$DIR/tips.h -ts $CODING/$DIR/mui/$l/ts/tips.ts &> /dev/null
			fi
		elif [ -z "$TYPE" ]; then
			echo "Can not found project named: $p" >> /dev/stderr
			exit 1
		else
			echo "Unknown project type: $TYPE for $p" >> /dev/stderr
			exit 1
		fi
	}
}

#echo "updated locales:" $LOCALES
#echo "updated projects:" $PROJS
